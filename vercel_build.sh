#!/bin/bash
set -e

# If flutter is not installed in the Vercel container environment, download Flutter SDK
if ! command -v flutter &> /dev/null; then
  echo "[Vercel Build] Flutter CLI not found in PATH. Downloading Flutter SDK..."
  if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  fi
  export PATH="$PATH:$HOME/flutter/bin"
fi

echo "[Vercel Build] Flutter SDK Info:"
flutter --version

echo "[Vercel Build] Building Flutter Web (Release)..."
flutter config --no-analytics
flutter build web --release

echo "[Vercel Build] Ensuring app-ads.txt and robots.txt are in build/web..."
cp web/app-ads.txt build/web/app-ads.txt || cp app-ads.txt build/web/app-ads.txt || true
cp web/robots.txt build/web/robots.txt || true

echo "[Vercel Build] Copying vercel.json rewrite rules into build/web..."
cp vercel.json build/web/vercel.json || true

echo "[Vercel Build] Build finished successfully!"
