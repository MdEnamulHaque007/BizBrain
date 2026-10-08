#!/bin/bash
set -e

echo "[1/5] Installing Flutter 3.41.6..."
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.6-stable.tar.xz | tar -xJ -C /tmp

git config --global --add safe.directory /tmp/flutter
export PATH=/tmp/flutter/bin:$PATH

echo "[2/5] Disabling analytics..."
flutter config --no-analytics

echo "[3/5] Running pub get..."
flutter pub get

echo "[4/5] Building web with Firebase config..."
flutter build web --release \
  --dart-define=APP_ENV="${APP_ENV:-production}" \
  --dart-define=APP_BUILD="${APP_BUILD:-release}" \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY}" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID}"

echo "[5/5] Build complete!"