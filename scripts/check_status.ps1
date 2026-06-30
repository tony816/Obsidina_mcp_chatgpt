param(
    [int] $ObsidianPort = 27124,
    [int] $BridgePort = 8000
)

$ErrorActionPreference = "Continue"

Write-Host "Obsidian REST port:"
Get-NetTCPConnection -LocalPort $ObsidianPort -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, State, OwningProcess

Write-Host ""
Write-Host "Bridge port:"
Get-NetTCPConnection -LocalPort $BridgePort -ErrorAction SilentlyContinue |
    Select-Object LocalAddress, LocalPort, State, OwningProcess

Write-Host ""
Write-Host "ngrok tunnels:"
try {
    (Invoke-RestMethod -Uri http://127.0.0.1:4040/api/tunnels -TimeoutSec 5).tunnels |
        Select-Object public_url, proto
} catch {
    Write-Host "ngrok API is not available on http://127.0.0.1:4040"
}

