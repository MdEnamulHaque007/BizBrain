# Generate version.txt for BizBrain local builds

# Ensure Firebase config is present in the build before writing version
if (Test-Path 'build\web\main.dart.js') {
    $hasConfig = Select-String -Path 'build\web\main.dart.js' -Pattern 'AIzaSyDSe' -SimpleMatch -Quiet
    if (-not $hasConfig) {
        Write-Host 'Firebase config NOT embedded. Rebuild with --dart-define flags.' -ForegroundColor Yellow
    }
}

$sha = git rev-parse HEAD 2>$null
if (-not $sha) { $sha = "local-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }

New-Item -ItemType Directory -Path "web" -Force | Out-Null
Set-Content -Path "web\version.txt" -Value $sha -Encoding UTF8 -NoNewline
Write-Host "web/version.txt: $sha"

if (Test-Path "build\web") {
    Set-Content -Path "build\web\version.txt" -Value $sha -Encoding UTF8 -NoNewline
    Write-Host "build/web/version.txt: $sha"
}