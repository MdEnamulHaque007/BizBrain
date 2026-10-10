# Generate version.txt for BizBrain local builds
$sha = git rev-parse HEAD 2>$null
if (-not $sha) { $sha = "local-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }

New-Item -ItemType Directory -Path "web" -Force | Out-Null
Set-Content -Path "web\version.txt" -Value $sha -Encoding UTF8 -NoNewline
Write-Host "web/version.txt: $sha"

if (Test-Path "build\web") {
    Set-Content -Path "build\web\version.txt" -Value $sha -Encoding UTF8 -NoNewline
    Write-Host "build/web/version.txt: $sha"
}