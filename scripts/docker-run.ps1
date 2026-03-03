# Build and run the default Docker image with Railway-like env and volume.
# Use from PowerShell on Windows (Docker Desktop). See docs/WSL-DOCKER-TESTING.md and docs/EPIC-AGENT-DEPLOYMENT.md.

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ImageName = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "clawdbot-railway-template" }
$DataDir = if ($env:DATA_DIR) { $env:DATA_DIR } else { ".tmpdata" }
$Port = if ($env:PORT) { $env:PORT } else { "8080" }
$SetupPassword = if ($env:SETUP_PASSWORD) { $env:SETUP_PASSWORD } else { "test" }

Push-Location $RepoRoot
try {
    $dataPath = Join-Path (Get-Location) $DataDir
    if (-not (Test-Path $dataPath)) { New-Item -ItemType Directory -Path $dataPath | Out-Null }

    Write-Host "[docker-run] Building $ImageName..."
    docker build -t $ImageName .

    docker stop clawdbot-smoke 2>$null
    Write-Host "[docker-run] Running (port $Port, data $DataDir)..."
    docker run --rm -d -p "${Port}:${Port}" `
      -e "PORT=$Port" `
      -e "SETUP_PASSWORD=$SetupPassword" `
      -e "OPENCLAW_STATE_DIR=/data/.openclaw" `
      -e "OPENCLAW_WORKSPACE_DIR=/data/workspace" `
      -v "${dataPath}:/data" `
      --name clawdbot-smoke `
      $ImageName

    Write-Host "[docker-run] Waiting for server to be ready..."
    $maxAttempts = 12
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 5
        $attempt++
        try {
            $health = Invoke-WebRequest -Uri "http://localhost:${Port}/healthz" -UseBasicParsing -TimeoutSec 10
            if ($health.StatusCode -eq 200) { break }
        } catch {
            if ($attempt -eq $maxAttempts) {
                Write-Host "  /healthz not ready after ${maxAttempts} attempts. Container may still be starting; try: curl http://localhost:${Port}/healthz"
                docker logs clawdbot-smoke 2>&1 | Select-Object -Last 30
                exit 1
            }
            Write-Host "  Attempt $attempt/$maxAttempts..."
        }
    }
    Write-Host "  /healthz OK"

    $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$SetupPassword"))
    Write-Host "[docker-run] Checking /setup/healthz..."
    $setupHealth = Invoke-WebRequest -Uri "http://localhost:${Port}/setup/healthz" -Headers @{ Authorization = "Basic $cred" } -UseBasicParsing -TimeoutSec 10
    if ($setupHealth.StatusCode -eq 200) { Write-Host "  /setup/healthz OK" } else { Write-Host "  /setup/healthz FAIL: $($setupHealth.StatusCode)"; exit 1 }

    Write-Host ""
    Write-Host "Smoke checks passed. Container is running (name: clawdbot-smoke)."
    Write-Host "  Setup:  http://localhost:${Port}/setup  (password: $SetupPassword)"
    Write-Host "  Stop:   docker stop clawdbot-smoke"
}
finally {
    Pop-Location
}
