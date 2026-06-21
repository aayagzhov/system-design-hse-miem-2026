# One command (Windows PowerShell):
#   cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha; .\fix-and-rebuild.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot
$patroniDir = Join-Path $PSScriptRoot "patroni-master"
$vendorEtcd = Join-Path $patroniDir "vendor\etcd.tar.gz"
$vendorConfd = Join-Path $patroniDir "vendor\confd"

function Test-VendorDeps {
    if (-not (Test-Path $vendorEtcd)) { return $false }
    if (-not (Test-Path $vendorConfd)) { return $false }
    if ((Get-Item $vendorEtcd).Length -lt 1000000) { return $false }
    if ((Get-Item $vendorConfd).Length -lt 1000000) { return $false }
    return $true
}

Write-Host "0/8 git pull"
git -C $repoRoot pull

Write-Host "1/8 git config core.autocrlf false"
git -C $repoRoot config core.autocrlf false

Write-Host "2/8 fix entrypoint.sh CRLF -> LF"
& (Join-Path $PSScriptRoot "fix-line-endings.ps1")

$ep = Join-Path $patroniDir "docker\entrypoint.sh"
$bytes = [System.IO.File]::ReadAllBytes($ep)
$hex = ($bytes[0..15] | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host "   hex: $hex"
if ($hex -match "0D 0A") {
    throw "entrypoint.sh still has CRLF. Close editor and run again."
}
Write-Host "   OK: LF line endings"

Write-Host "3/8 vendor deps for offline build"
if (-not (Test-VendorDeps)) {
    Write-Host "   downloading etcd + confd on Windows..."
    try {
        & (Join-Path $patroniDir "download-deps.ps1")
    } catch {
        Write-Host "   download failed: $_"
        Write-Host ""
        Write-Host "   Download in browser and save to patroni-master\vendor\ :"
        Write-Host "   etcd:  https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz"
        Write-Host "          -> vendor\etcd.tar.gz"
        Write-Host "   confd: https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64"
        Write-Host "          -> vendor\confd   (no extension!)"
        throw "vendor files missing. Use VPN or browser download, then run again."
    }
}

if (-not (Test-VendorDeps)) {
    throw "vendor\etcd.tar.gz or vendor\confd invalid. Download etcd.tar.gz and confd into patroni-master\vendor\ (see course materials)."
}
Write-Host "   OK: vendor deps ready"

Write-Host "4/8 docker build --no-cache (Dockerfile.offline, no GitHub inside Docker)"
Push-Location $patroniDir
docker build --no-cache -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni .
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
Pop-Location

Write-Host "5/8 docker compose down"
Push-Location $PSScriptRoot
docker compose down

Write-Host "6/8 docker compose up -d"
docker compose up -d
Write-Host "   waiting 90 sec..."
Start-Sleep -Seconds 90

Write-Host "7/8 check cluster"
docker ps --format "table {{.Names}}`t{{.Status}}"
Write-Host ""
docker exec demo-patroni1 patronictl list
Pop-Location

Write-Host ""
Write-Host "Done."
