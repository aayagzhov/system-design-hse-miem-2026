# Download etcd + confd for offline docker build (only if normal build fails on GitHub)
# Run: .\download-deps.ps1

$ErrorActionPreference = "Stop"
$vendor = Join-Path $PSScriptRoot "vendor"
New-Item -ItemType Directory -Force -Path $vendor | Out-Null

$etcdUrl = "https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz"
$confdUrl = "https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64"

function Download-File($url, $dest) {
    Write-Host "Downloading $dest ..."
    curl.exe -fL --retry 10 --retry-delay 5 --connect-timeout 60 -o $dest $url
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path $dest) { Remove-Item $dest -Force }
        throw "Download failed: $url (curl exit $LASTEXITCODE). Try VPN, mobile hotspot, or download in browser."
    }
    if (-not (Test-Path $dest)) {
        throw "File not created: $dest"
    }
}

Download-File $etcdUrl "$vendor\etcd.tar.gz"
Download-File $confdUrl "$vendor\confd"

$etcdSize = (Get-Item "$vendor\etcd.tar.gz").Length
$confdSize = (Get-Item "$vendor\confd").Length

if ($etcdSize -lt 1000000) {
    throw "etcd.tar.gz too small ($etcdSize bytes)."
}
if ($confdSize -lt 1000000) {
    throw "confd too small ($confdSize bytes)."
}

Write-Host "OK:"
Write-Host "  vendor\etcd.tar.gz  ($etcdSize bytes)"
Write-Host "  vendor\confd        ($confdSize bytes)"
Write-Host "Next: docker build -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni ."
