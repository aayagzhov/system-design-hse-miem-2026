# Fix CRLF -> LF before docker build (Windows)
# Run: .\fix-line-endings.ps1

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$root = Join-Path $PSScriptRoot "patroni-master"

$patterns = @("*.sh", "*.py", "*.yml")
$skipDirs = @("vendor", ".git", "__pycache__", "tests", "docs")

$fixed = 0
foreach ($pattern in $patterns) {
    Get-ChildItem -Path $root -Filter $pattern -Recurse -File | ForEach-Object {
        $skip = $false
        foreach ($d in $skipDirs) {
            if ($_.FullName -match [regex]::Escape([IO.Path]::DirectorySeparatorChar + $d + [IO.Path]::DirectorySeparatorChar)) {
                $skip = $true
                break
            }
        }
        if ($skip) { return }

        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        if ($bytes -notcontains 13) { return }

        $text = [IO.File]::ReadAllText($_.FullName)
        $newText = $text -replace "`r`n", "`n" -replace "`r", "`n"
        [IO.File]::WriteAllText($_.FullName, $newText, $utf8NoBom)
        $rel = $_.FullName.Substring($root.Length + 1)
        Write-Host "Fixed: $rel"
        $script:fixed++
    }
}

if ($fixed -eq 0) {
    Write-Host "No CRLF found."
} else {
    Write-Host "Fixed $fixed file(s). Rebuild: cd patroni-master; docker build -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni ."
}
