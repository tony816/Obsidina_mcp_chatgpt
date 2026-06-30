# AI Agent Setup Guide: Obsidian MCP in ChatGPT Web

Follow this guide exactly on a new Windows PC. It is written so an AI agent can complete the setup without rediscovering the previous pitfalls.

## Goal

Make ChatGPT web able to read and write the user's local Obsidian vault through a custom MCP app.

Completion is proven only when ChatGPT successfully calls an Obsidian MCP tool, for example `obsidian_list_files_in_vault`, and displays the vault root list.

## Known Good Values From The Original Setup

- Obsidian Local REST API HTTPS port: `27124`
- Local bridge port: `8000`
- ChatGPT MCP URL path: `/mcp`
- ChatGPT authentication setting: `None`
- Obsidian Local REST API plugin id: `obsidian-local-rest-api`
- Example vault path format: `<VAULT_PATH>`

Do not copy the original API key to another PC. Each PC's Obsidian plugin generates its own key in `data.json`.

## Prerequisites

Check these first:

```powershell
python --version
uv --version
ngrok version
git --version
```

If `uv` is missing, install it from the official installer. If `ngrok` is missing, install and authenticate it before continuing.

## Step 1: Clone This Repo

```powershell
git clone https://github.com/tony816/Obsidina_mcp_chatgpt.git
cd Obsidina_mcp_chatgpt
```

## Step 2: Locate The Obsidian Vault

If the user does not know the path, inspect:

```powershell
Get-Content "$env:APPDATA\obsidian\obsidian.json"
```

The `vaults.*.path` value is the vault path. On Google Drive for desktop it may look like a path under the user's mounted drive, for example:

```text
G:\...\YourVaultName
```

If PowerShell displays mojibake in `obsidian.json`, list likely folders manually:

```powershell
Get-ChildItem G:\ -Force -Directory
Get-ChildItem "G:\..." -Force -Directory
```

## Step 3: Install Obsidian Local REST API Plugin

Run:

```powershell
.\scripts\install_obsidian_local_rest_api.ps1 -VaultPath "<VAULT_PATH>"
```

This script downloads the latest release from:

```text
https://github.com/coddingtonbear/obsidian-local-rest-api
```

It installs:

```text
<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\main.js
<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\manifest.json
<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\styles.css
```

It also adds `obsidian-local-rest-api` to:

```text
<VAULT_PATH>\.obsidian\community-plugins.json
```

Important pitfall: write `community-plugins.json` as UTF-8 without BOM. The script already does this. A prior failed setup was caused by Obsidian not loading the plugin until this file was rewritten cleanly.

## Step 4: Restart Obsidian

Close and reopen Obsidian. Then verify:

```powershell
Test-Path "<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\data.json"
Get-NetTCPConnection -LocalPort 27124 -ErrorAction SilentlyContinue
```

Expected:

- `data.json` exists.
- Port `127.0.0.1:27124` is listening.

You can also test:

```powershell
curl.exe -k -s https://127.0.0.1:27124/
```

Expected JSON contains:

```json
"service": "Obsidian Local REST API"
```

## Step 5: Start The MCP Bridge

In the repo folder:

```powershell
.\scripts\start_bridge.ps1 -VaultPath "<VAULT_PATH>"
```

Leave that PowerShell window open.

Verify in another PowerShell:

```powershell
Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
curl.exe -i -N --max-time 3 http://127.0.0.1:8000/mcp
```

Expected SSE response starts with:

```text
event: endpoint
data: /messages/?session_id=...
```

The bridge also supports `/sse`, but use `/mcp` for ChatGPT unless the UI specifically expects `/sse`.

## Step 6: Start ngrok

In another PowerShell:

```powershell
ngrok http 8000
```

Fetch the HTTPS URL:

```powershell
(Invoke-RestMethod -Uri http://127.0.0.1:4040/api/tunnels).tunnels |
  Where-Object { $_.proto -eq "https" } |
  Select-Object -ExpandProperty public_url
```

The ChatGPT MCP URL is:

```text
https://<ngrok-domain>/mcp
```

If using a fixed ngrok domain or Cloudflare Tunnel, use that stable domain instead.

## Step 7: Create Or Update The ChatGPT App

Open Chrome using the user's logged-in ChatGPT session.

In ChatGPT web:

1. Open Settings.
2. Go to Apps.
3. Use Developer mode / app creation.
4. Create a new app, or open the existing private app.
5. Name: `Obsidian Local MCP`
6. MCP server URL: `https://<ngrok-domain>/mcp`
7. Authentication: `None`
8. Confirm the custom MCP server risk checkbox.
9. Create the app.
10. Open the app details and click `연결하기` / `Connect`.
11. Confirm the final connection dialog.

Expected app detail evidence:

- The app shows `연결 해제` / `Disconnect`.
- Tool list includes names such as:
  - `obsidian_list_files_in_vault`
  - `obsidian_get_file_contents`
  - `obsidian_simple_search`
  - `obsidian_append_content`

## Step 8: Verify In ChatGPT

Send this prompt in a new ChatGPT chat:

```text
Obsidian Local MCP 앱을 사용해서 내 Obsidian vault 루트의 파일/폴더 목록을 보여줘.
```

Expected:

- ChatGPT opens or reports a tool call.
- Local bridge log shows `CallToolRequest`.
- ChatGPT response includes actual vault root files/folders.

Check logs:

```powershell
Get-Content .\mcp-obsidian-sse.err.log -Tail 120
```

Successful evidence may include:

```text
INFO:mcp.server:Processing request of type CallToolRequest
```

## Troubleshooting

### ChatGPT says the server does not implement OAuth

Set Authentication to:

```text
인증 없음 / None
```

Do not choose OAuth for this bridge.

### Obsidian port 27124 is not listening

Check:

```powershell
Test-Path "<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\data.json"
Get-Content "<VAULT_PATH>\.obsidian\community-plugins.json"
```

Fix:

1. Ensure `obsidian-local-rest-api` is in `community-plugins.json`.
2. Rewrite `community-plugins.json` as UTF-8 without BOM if necessary.
3. Restart Obsidian.

### ChatGPT can list tools but cannot call them

Keep all three processes alive:

```text
Obsidian
PowerShell running .\scripts\start_bridge.ps1
PowerShell running ngrok http 8000
```

Then retry the prompt.

### URL changes after restart

Free ngrok URLs can change. If the URL changed, update the ChatGPT app's MCP URL.

For "same URL forever", use:

- ngrok fixed domain, or
- Cloudflare Tunnel with a fixed domain.

### Security note

The public tunnel exposes an MCP bridge to the user's local Obsidian vault. Keep the tunnel running only when needed unless it is protected by a stable, intentional access strategy.
