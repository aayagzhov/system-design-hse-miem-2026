# Download etcd + confd for offline docker build (only if normal build fails on GitHub)
# Run: .\download-deps.ps1

$ErrorActionPreference = "Stop"
$vendor = Join-Path $PSScriptRoot "vendor"
New-Item -ItemType Directory -Force -Path $vendor | Out-Null

$etcdUrl = "https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz"
$confdUrl = "https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64"

Write-Host "Downloading etcd..."
curl.exe -fL --retry 10 --retry-delay 5 --connect-timeout 30 -o "$vendor\etcd.tar.gz" $etcdUrl

Write-Host "Downloading confd..."
curl.exe -fL --retry 10 --retry-delay 5 --connect-timeout 30 -o "$vendor\confd" $confdUrl

$size = (Get-Item "$vendor\etcd.tar.gz").Length
if ($size -lt 1000000) {
    throw "etcd.tar.gz too small ($size bytes). Download failed. Try VPN or another network."
}

Write-Host "OK: vendor\etcd.tar.gz ($size bytes), vendor\confd"
Write-Host "Next: docker build -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni ."
