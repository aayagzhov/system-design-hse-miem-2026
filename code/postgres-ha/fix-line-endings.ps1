# Исправить CRLF -> LF перед docker build (Windows)
# Запуск: .\fix-line-endings.ps1

$files = @(
    "patroni-master\docker\entrypoint.sh"
)

foreach ($rel in $files) {
    $path = Join-Path $PSScriptRoot $rel
    if (-not (Test-Path $path)) {
        Write-Warning "Not found: $path"
        continue
    }
    $text = [IO.File]::ReadAllText($path)
    $fixed = $text -replace "`r`n", "`n" -replace "`r", "`n"
    [IO.File]::WriteAllText($path, $fixed)
    Write-Host "Fixed: $rel"
}

Write-Host "Done. Rebuild: cd patroni-master; docker build --build-arg PG_MAJOR=15 -t patroni ."
