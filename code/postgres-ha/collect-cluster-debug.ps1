# collect-cluster-debug.ps1
# Run from code\postgres-ha: .\collect-cluster-debug.ps1

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path (Split-Path $PSScriptRoot)
$out = Join-Path $repoRoot "HW\cluster-debug.txt"
$sb = New-Object System.Text.StringBuilder

function Add-Line($text) {
    [void]$sb.AppendLine($text)
}

Add-Line ("=== cluster debug " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " ===")
Add-Line ""
Add-Line "=== docker ps -a ==="
docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | ForEach-Object { Add-Line $_ }

$containers = @(
    "demo-patroni1", "demo-patroni2", "demo-patroni3",
    "demo-etcd1", "demo-etcd2", "demo-etcd3",
    "demo-haproxy"
)

foreach ($c in $containers) {
    Add-Line ""
    Add-Line ("=== docker logs " + $c + " last 50 lines ===")
    docker logs $c 2>&1 | Select-Object -Last 50 | ForEach-Object { Add-Line $_ }
}

Add-Line ""
Add-Line "=== docker inspect demo-patroni1 ==="
docker inspect demo-patroni1 --format "{{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}" 2>&1 | ForEach-Object { Add-Line $_ }

Add-Line ""
Add-Line "=== entrypoint.sh hex - 0d0a means CRLF ==="
$ep = Join-Path $PSScriptRoot "patroni-master\docker\entrypoint.sh"
if (Test-Path $ep) {
    Format-Hex -Path $ep -Count 32 | Out-String | ForEach-Object { Add-Line $_ }
} else {
    Add-Line ("NOT FOUND: " + $ep)
}

Add-Line ""
Add-Line "=== docker images patroni ==="
docker images patroni | ForEach-Object { Add-Line $_ }

Add-Line ""
Add-Line "=== git core.autocrlf ==="
git -C $repoRoot config core.autocrlf 2>&1 | ForEach-Object { Add-Line $_ }

$sb.ToString() | Out-File -FilePath $out -Encoding utf8
Write-Host ("OK: " + $out)
