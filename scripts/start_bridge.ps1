param(
    [Parameter(Mandatory = $true)]
    [string] $VaultPath,

    [string] $HostName = "127.0.0.1",
    [int] $ObsidianPort = 27124,
    [int] $BridgePort = 8000
)

$ErrorActionPreference = "Stop"

$dataPath = Join-Path $VaultPath ".obsidian\plugins\obsidian-local-rest-api\data.json"
if (-not (Test-Path -LiteralPath $dataPath)) {
    throw "Missing Local REST API data.json. Install/enable the plugin, restart Obsidian, then retry. Expected: $dataPath"
}

$data = Get-Content -LiteralPath $dataPath -Raw | ConvertFrom-Json
if (-not $data.apiKey) {
    throw "Local REST API data.json exists but has no apiKey. Open Obsidian once and check the plugin loaded."
}

$env:OBSIDIAN_API_KEY = $data.apiKey
$env:OBSIDIAN_HOST = $HostName
$env:OBSIDIAN_PORT = [string] $ObsidianPort
$env:MCP_OBSIDIAN_HTTP_HOST = "127.0.0.1"
$env:MCP_OBSIDIAN_HTTP_PORT = [string] $BridgePort

Write-Host "Starting bridge on http://127.0.0.1:$BridgePort/mcp"
Write-Host "Leave this PowerShell window open."
uv run obsidian-chatgpt-bridge

