# Prompt To Give Another AI Agent

Copy and paste the text below into the AI agent on the other PC.

```text
You are helping me set up Obsidian MCP for ChatGPT web on this Windows PC.

Goal:
Make web ChatGPT able to use my local Obsidian vault through a custom MCP app. Do not stop at instructions. Please perform the setup, launch the required local services, configure Chrome/ChatGPT if browser control is available, and verify that ChatGPT can actually call an Obsidian MCP tool.

Important repository:
https://github.com/tony816/Obsidina_mcp_chatgpt.git

Start by cloning that repo, then follow AGENT_SETUP_GUIDE.md exactly. The repo contains:
- AGENT_SETUP_GUIDE.md: the full setup playbook
- scripts/install_obsidian_local_rest_api.ps1
- scripts/start_bridge.ps1
- scripts/check_status.ps1
- src/obsidian_chatgpt_bridge/server_sse.py

Expected architecture:
ChatGPT web -> public HTTPS tunnel such as ngrok -> local bridge on 127.0.0.1:8000 -> Obsidian Local REST API on 127.0.0.1:27124 -> my local Obsidian vault.

Use these known-good values unless the local machine requires a different value:
- Obsidian Local REST API port: 27124
- Local bridge port: 8000
- ChatGPT MCP URL path: /mcp
- ChatGPT custom app authentication: None
- Obsidian plugin id: obsidian-local-rest-api

Tasks:
1. Check prerequisites: Python 3.11+, uv, git, ngrok, Obsidian.
2. Locate my Obsidian vault. If needed, inspect:
   Get-Content "$env:APPDATA\obsidian\obsidian.json"
3. Clone the repo:
   git clone https://github.com/tony816/Obsidina_mcp_chatgpt.git
4. Install or verify the Obsidian Local REST API plugin using:
   .\scripts\install_obsidian_local_rest_api.ps1 -VaultPath "<VAULT_PATH>"
5. Restart Obsidian if needed and verify:
   <VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\data.json exists
   Get-NetTCPConnection -LocalPort 27124 shows Listen
   curl.exe -k -s https://127.0.0.1:27124/ returns Obsidian Local REST API JSON
6. Start the bridge:
   .\scripts\start_bridge.ps1 -VaultPath "<VAULT_PATH>"
7. Start ngrok in a separate PowerShell:
   ngrok http 8000
8. Get the HTTPS tunnel URL from:
   http://127.0.0.1:4040/api/tunnels
9. Configure ChatGPT web in Chrome:
   - Open ChatGPT settings
   - Go to Apps
   - Create or edit the private app named Obsidian Local MCP
   - MCP server URL: https://<ngrok-domain>/mcp
   - Authentication: None
   - Accept the custom MCP risk checkbox
   - Connect the app
10. Verify completion in ChatGPT with this prompt:
    Use the Obsidian Local MCP app to list the files and folders at the root of my Obsidian vault.

Completion criteria:
- ChatGPT app detail shows Disconnect / connected state.
- Tool list includes obsidian_list_files_in_vault, obsidian_get_file_contents, obsidian_simple_search, etc.
- ChatGPT successfully calls the tool and displays actual vault root files/folders.
- Local bridge logs show a CallToolRequest.

Do not copy API keys from another PC. The Obsidian Local REST API key must be read from this PC's:
<VAULT_PATH>\.obsidian\plugins\obsidian-local-rest-api\data.json

Important pitfall:
If ChatGPT says the server does not implement OAuth, change app authentication to None. Do not choose OAuth.

Important pitfall:
If Obsidian port 27124 is not listening, the plugin did not load. Make sure obsidian-local-rest-api is in:
<VAULT_PATH>\.obsidian\community-plugins.json
and restart Obsidian. The install script writes this file as UTF-8 without BOM because that fixed a previous load issue.

Important pitfall:
Free ngrok URLs can change. If the URL changes, update the ChatGPT app MCP server URL. For a permanent setup, use a fixed ngrok domain or Cloudflare Tunnel.

Please keep going until the setup is actually verified, not merely documented.
```
