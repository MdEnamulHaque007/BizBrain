# BizBrain build + deploy script (production)
# Usage: .\scripts\build-deploy.ps1

$ErrorActionPreference = 'Stop'

$flags = @(
    '--dart-define=APP_ENV=production',
    '--dart-define=APP_BUILD=release',
    '--dart-define=FIREBASE_API_KEY=AIzaSyDSe6HNPLCoG4CoHhU4RiUjjwWUHZKB44o',
    '--dart-define=FIREBASE_AUTH_DOMAIN=bizbrain-e3a61.firebaseapp.com',
    '--dart-define=FIREBASE_PROJECT_ID=bizbrain-e3a61',
    '--dart-define=FIREBASE_STORAGE_BUCKET=bizbrain-e3a61.firebasestorage.app',
    '--dart-define=FIREBASE_MESSAGING_SENDER_ID=862761802417',
    '--dart-define=FIREBASE_APP_ID=1:862761802417:web:b3e2e9732cf45afd666090'
)

Write-Host '[1/5] flutter clean...' -ForegroundColor Cyan
flutter clean

Write-Host '[2/5] flutter pub get...' -ForegroundColor Cyan
flutter pub get

Write-Host '[3/5] flutter build web --release with Firebase flags...' -ForegroundColor Cyan
flutter build web --release @flags
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

Write-Host '[4/5] Verifying Firebase config embedded...' -ForegroundColor Cyan
$found = Select-String -Path 'build\web\main.dart.js' -Pattern 'AIzaSyDSe' -SimpleMatch -Quiet
if (-not $found) {
    throw 'Firebase config NOT embedded in main.dart.js. Aborting deploy.'
}
Write-Host '  OK - Firebase API key found in bundle' -ForegroundColor Green

Write-Host '[5/5] Generate version.txt + firebase deploy...' -ForegroundColor Cyan
.\scripts\generate-version.ps1
firebase deploy --only hosting

Write-Host 'Done. https://bizbrain-e3a61.web.app' -ForegroundColor Green