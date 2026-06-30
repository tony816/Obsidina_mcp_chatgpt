param(
    [Parameter(Mandatory = $true)]
    [string] $VaultPath,

    [string] $PluginId = "obsidian-local-rest-api"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VaultPath)) {
    throw "Vault path does not exist: $VaultPath"
}

$obsidianDir = Join-Path $VaultPath ".obsidian"
$pluginsDir = Join-Path $obsidianDir "plugins"
$pluginDir = Join-Path $pluginsDir $PluginId
$communityPluginsFile = Join-Path $obsidianDir "community-plugins.json"

New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null

$release = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/coddingtonbear/obsidian-local-rest-api/releases/latest" `
    -Headers @{ "User-Agent" = "obsidian-mcp-chatgpt-bridge" }

foreach ($assetName in @("main.js", "manifest.json", "styles.css")) {
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        throw "Release $($release.tag_name) does not contain $assetName"
    }
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile (Join-Path $pluginDir $assetName) -UseBasicParsing
}

if (Test-Path -LiteralPath $communityPluginsFile) {
    $plugins = @(Get-Content -LiteralPath $communityPluginsFile -Raw | ConvertFrom-Json)
} else {
    $plugins = @()
}

if ($plugins -notcontains $PluginId) {
    $plugins += $PluginId
}

$json = $plugins | ConvertTo-Json -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($communityPluginsFile, $json, $utf8NoBom)

Write-Host "Installed $PluginId $($release.tag_name) into:"
Write-Host $pluginDir
Write-Host "Restart Obsidian and wait until data.json appears in the plugin folder."

