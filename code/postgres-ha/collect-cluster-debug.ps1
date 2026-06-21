# Сбор логов patroni/etcd/haproxy -> HW/cluster-debug.txt
# Запуск из code\postgres-ha: .\collect-cluster-debug.ps1

$repoRoot = Split-Path (Split-Path $PSScriptRoot)
$out = Join-Path $repoRoot "HW\cluster-debug.txt"
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("=== cluster debug $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===")
$lines.Add("")
$lines.Add("=== docker ps -a ===")
docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | ForEach-Object { $lines.Add($_) }

$containers = @(
    "demo-patroni1", "demo-patroni2", "demo-patroni3",
    "demo-etcd1", "demo-etcd2", "demo-etcd3",
    "demo-haproxy"
)

foreach ($c in $containers) {
    $lines.Add("")
    $lines.Add("=== docker logs $c (last 50 lines) ===")
    docker logs $c 2>&1 | Select-Object -Last 50 | ForEach-Object { $lines.Add("$_) }
}

$lines.Add("")
$lines.Add("=== docker inspect demo-patroni1 ===")
docker inspect demo-patroni1 --format "{{.State.Status}} exit={{.State.ExitCode}} error={{.State.Error}}" 2>&1 | ForEach-Object { $lines.Add($_) }

$lines.Add("")
$lines.Add("=== entrypoint.sh hex (0d 0a = CRLF) ===")
$ep = Join-Path $PSScriptRoot "patroni-master\docker\entrypoint.sh"
if (Test-Path $ep) {
    Format-Hex -Path $ep -Count 32 | ForEach-Object { $lines.Add($_.ToString()) }
} else {
    $lines.Add("NOT FOUND: $ep")
}

$lines.Add("")
$lines.Add("=== docker images patroni ===")
docker images patroni | ForEach-Object { $lines.Add($_) }

$lines.Add("")
$lines.Add("=== git core.autocrlf ===")
git -C $repoRoot config core.autocrlf 2>&1 | ForEach-Object { $lines.Add($_) }

$lines | Out-File -FilePath $out -Encoding utf8
Write-Host "OK: $out"
