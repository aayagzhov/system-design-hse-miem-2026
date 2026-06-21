# Fix CRLF + rebuild patroni + restart cluster (Windows)
# Run from code\postgres-ha: .\fix-and-rebuild.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot

Write-Host "1/6 git config core.autocrlf false"
git -C $repoRoot config core.autocrlf false

Write-Host "2/6 fix entrypoint.sh CRLF -> LF"
& (Join-Path $PSScriptRoot "fix-line-endings.ps1")

$ep = Join-Path $PSScriptRoot "patroni-master\docker\entrypoint.sh"
$bytes = [System.IO.File]::ReadAllBytes($ep)
$hex = ($bytes[0..15] | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host "   hex: $hex"
if ($hex -match "0D 0A") {
    throw "entrypoint.sh still has CRLF. Close editor and run again."
}
Write-Host "   OK: LF line endings"

Write-Host "3/6 docker build --no-cache"
Push-Location (Join-Path $PSScriptRoot "patroni-master")
docker build --no-cache --build-arg PG_MAJOR=15 -t patroni .
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
Pop-Location

Write-Host "4/6 docker compose down"
Push-Location $PSScriptRoot
docker compose down

Write-Host "5/6 docker compose up -d"
docker compose up -d
Write-Host "   waiting 90 sec..."
Start-Sleep -Seconds 90

Write-Host "6/6 check cluster"
docker ps --format "table {{.Names}}`t{{.Status}}"
Write-Host ""
docker exec demo-patroni1 patronictl list
Pop-Location

Write-Host ""
Write-Host "Done. If patroni still Exited - run .\collect-cluster-debug.ps1 and commit HW/cluster-debug.txt"
