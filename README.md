# Obsidian MCP for ChatGPT Web

This repo contains a small SSE bridge plus Windows setup scripts for using an Obsidian vault from ChatGPT web through a custom MCP app.

The working architecture is:

```text
ChatGPT web
  -> public HTTPS tunnel, for example ngrok
  -> local bridge on 127.0.0.1:8000
  -> Obsidian Local REST API on 127.0.0.1:27124
  -> local Obsidian vault
```

Use `AGENT_SETUP_GUIDE.md` when asking another AI agent to repeat the setup on a different PC.

## Quick Start

1. Install prerequisites on the target PC:
   - Obsidian
   - Python 3.11+
   - `uv`
   - `ngrok`

2. Clone this repo:

```powershell
git clone https://github.com/tony816/Obsidina_mcp_chatgpt.git
cd Obsidina_mcp_chatgpt
```

3. Install the Obsidian Local REST API plugin into the vault:

```powershell
.\scripts\install_obsidian_local_rest_api.ps1 -VaultPath "<VAULT_PATH>"
```

4. Restart Obsidian and wait until this file exists:

```text
<vault>\.obsidian\plugins\obsidian-local-rest-api\data.json
```

5. Start the local bridge:

```powershell
.\scripts\start_bridge.ps1 -VaultPath "<VAULT_PATH>"
```

6. In another PowerShell window, expose it:

```powershell
ngrok http 8000
```

7. In ChatGPT web:
   - Settings
   - Apps
   - App creation / Developer mode
   - MCP server URL: `https://<ngrok-domain>/mcp`
   - Authentication: `None`
   - Connect the app
