param(
    [string] $VaultPath = "",
    [string] $ShortcutName = "Start Obsidian MCP ChatGPT Servers"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$launcherPath = Join-Path $repoRoot "scripts\launch_servers.ps1"
if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "Launcher script not found: $launcherPath"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "$ShortcutName.lnk"

$args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$launcherPath`""
)

if ($VaultPath) {
    $args += @("-VaultPath", "`"$VaultPath`"")
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = ($args -join " ")
$shortcut.WorkingDirectory = $repoRoot
$shortcut.Description = "Start Obsidian MCP bridge and ngrok for ChatGPT web"
$shortcut.IconLocation = "powershell.exe,0"
$shortcut.Save()

Write-Host "Created desktop shortcut:"
Write-Host $shortcutPath

