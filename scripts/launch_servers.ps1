param(
    [string] $VaultPath = "",
    [int] $ObsidianPort = 27124,
    [int] $BridgePort = 8000,
    [switch] $NoObsidianLaunch
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string] $Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-ObsidianExe {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe",
        "$env:ProgramFiles\Obsidian\Obsidian.exe",
        "${env:ProgramFiles(x86)}\Obsidian\Obsidian.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }
    return $null
}

function Resolve-VaultPath {
    param([string] $ProvidedVaultPath)

    if ($ProvidedVaultPath) {
        if (Test-Path -LiteralPath $ProvidedVaultPath) {
            return (Resolve-Path -LiteralPath $ProvidedVaultPath).Path
        }
        throw "Provided VaultPath does not exist: $ProvidedVaultPath"
    }

    $obsidianJsonPath = Join-Path $env:APPDATA "obsidian\obsidian.json"
    if (Test-Path -LiteralPath $obsidianJsonPath) {
        try {
            $registry = Get-Content -LiteralPath $obsidianJsonPath -Raw | ConvertFrom-Json
            $vaults = @($registry.vaults.PSObject.Properties | ForEach-Object { $_.Value })
            $selected = $vaults |
                Where-Object { $_.open -eq $true -and $_.path -and (Test-Path -LiteralPath $_.path) } |
                Sort-Object ts -Descending |
                Select-Object -First 1

            if (-not $selected) {
                $selected = $vaults |
                    Where-Object { $_.path -and (Test-Path -LiteralPath $_.path) } |
                    Sort-Object ts -Descending |
                    Select-Object -First 1
            }

            if ($selected) {
                return (Resolve-Path -LiteralPath $selected.path).Path
            }
        } catch {
            Write-Warning "Could not parse Obsidian vault registry: $obsidianJsonPath"
        }
    }

    $candidateRoots = [System.Collections.Generic.List[string]]::new()
    @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\OneDrive\Documents",
        "G:\"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | ForEach-Object {
        $candidateRoots.Add($_)
    }

    if (Test-Path -LiteralPath "G:\") {
        Get-ChildItem -LiteralPath "G:\" -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $candidateRoots.Add($_.FullName)
        }
    }

    foreach ($root in $candidateRoots) {
        $candidate = Get-ChildItem -LiteralPath $root -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                Test-Path -LiteralPath (Join-Path $_.FullName ".obsidian\plugins\obsidian-local-rest-api\data.json")
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "Could not auto-detect an Obsidian vault. Run with -VaultPath `"<path>`"."
}

function Test-PortListening {
    param([int] $Port)
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    return $null -ne $conn
}

function Wait-ForPort {
    param(
        [int] $Port,
        [int] $TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-PortListening -Port $Port) {
            return $true
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Start-ObsidianIfNeeded {
    param([int] $Port)

    if (Test-PortListening -Port $Port) {
        Write-Host "Obsidian Local REST API is already listening on port $Port."
        return
    }

    if ($NoObsidianLaunch) {
        Write-Host "Obsidian launch skipped. Waiting for port $Port..."
        return
    }

    $obsidianExe = Get-ObsidianExe
    if (-not $obsidianExe) {
        Write-Warning "Obsidian.exe was not found. Please start Obsidian manually."
        return
    }

    Write-Host "Starting Obsidian: $obsidianExe"
    Start-Process -FilePath $obsidianExe | Out-Null
}

function Start-BridgeIfNeeded {
    param(
        [string] $RepoRoot,
        [string] $ResolvedVaultPath,
        [int] $Port
    )

    if (Test-PortListening -Port $Port) {
        Write-Host "Bridge is already listening on port $Port."
        return
    }

    $scriptPath = Join-Path $RepoRoot "scripts\start_bridge.ps1"
    $quotedScript = $scriptPath.Replace("'", "''")
    $quotedVault = $ResolvedVaultPath.Replace("'", "''")
    $cmd = "& '$quotedScript' -VaultPath '$quotedVault' -BridgePort $Port"

    Write-Host "Starting bridge window on port $Port..."
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-NoExit",
        "-Command",
        $cmd
    ) -WorkingDirectory $RepoRoot -WindowStyle Minimized | Out-Null

    if (-not (Wait-ForPort -Port $Port -TimeoutSeconds 30)) {
        throw "Bridge did not start listening on port $Port within 30 seconds."
    }
}

function Get-NgrokHttpsUrl {
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 5
        $https = $tunnels.tunnels |
            Where-Object { $_.proto -eq "https" } |
            Select-Object -First 1
        if ($https) {
            return [string] $https.public_url
        }
    } catch {
        return $null
    }
    return $null
}

function Start-NgrokIfNeeded {
    param([int] $Port)

    $existingUrl = Get-NgrokHttpsUrl
    if ($existingUrl) {
        Write-Host "ngrok is already running: $existingUrl"
        return $existingUrl
    }

    $ngrokCommand = Get-Command ngrok -ErrorAction SilentlyContinue
    if (-not $ngrokCommand) {
        throw "ngrok was not found. Install/authenticate ngrok, then run: ngrok http $Port"
    }

    Write-Host "Starting ngrok tunnel to local port $Port..."
    Start-Process -FilePath $ngrokCommand.Source -ArgumentList @("http", [string] $Port) -WindowStyle Minimized | Out-Null

    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $url = Get-NgrokHttpsUrl
        if ($url) {
            return $url
        }
    }

    throw "ngrok started, but no HTTPS tunnel appeared on http://127.0.0.1:4040 within 30 seconds."
}

$repoRoot = Get-RepoRoot
$resolvedVaultPath = Resolve-VaultPath -ProvidedVaultPath $VaultPath
$runtimeDir = Join-Path $repoRoot "runtime"
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null

Write-Host "Obsidian MCP ChatGPT server launcher" -ForegroundColor Green
Write-Host "Repo:  $repoRoot"
Write-Host "Vault: $resolvedVaultPath"

Write-Step "Checking Obsidian Local REST API"
Start-ObsidianIfNeeded -Port $ObsidianPort
if (-not (Wait-ForPort -Port $ObsidianPort -TimeoutSeconds 45)) {
    throw "Obsidian Local REST API is not listening on port $ObsidianPort. Check that the obsidian-local-rest-api plugin is enabled."
}

Write-Step "Starting local MCP bridge"
Start-BridgeIfNeeded -RepoRoot $repoRoot -ResolvedVaultPath $resolvedVaultPath -Port $BridgePort

Write-Step "Starting public HTTPS tunnel"
$publicUrl = Start-NgrokIfNeeded -Port $BridgePort
$mcpUrl = "$publicUrl/mcp"
$sseUrl = "$publicUrl/sse"

$lastUrlPath = Join-Path $runtimeDir "last_chatgpt_mcp_url.txt"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($lastUrlPath, $mcpUrl, $utf8NoBom)

Write-Step "Ready"
Write-Host "ChatGPT MCP URL:" -ForegroundColor Yellow
Write-Host $mcpUrl -ForegroundColor Yellow
Write-Host ""
Write-Host "Alternative SSE URL:"
Write-Host $sseUrl
Write-Host ""
Write-Host "Saved URL to:"
Write-Host $lastUrlPath
Write-Host ""
Write-Host "Keep Obsidian, the bridge window, and ngrok running while using ChatGPT."
Write-Host "Press Enter to close this launcher window. Servers will keep running."
[void] [Console]::ReadLine()
