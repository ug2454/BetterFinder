#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --disable-sandbox
mkdir -p dist/BetterFinder.app/Contents/MacOS
mkdir -p dist/BetterFinder.app/Contents/Resources
cp .build/release/BetterFinder dist/BetterFinder.app/Contents/MacOS/BetterFinder
cp Resources/Info.plist dist/BetterFinder.app/Contents/Info.plist
cp Resources/AppIcon.icns dist/BetterFinder.app/Contents/Resources/AppIcon.icns
codesign --force --sign - --entitlements Resources/BetterFinder.entitlements --identifier dev.betterfinder.app dist/BetterFinder.app
touch dist/BetterFinder.app
printf 'Built: %s/dist/BetterFinder.app\n' "$PWD"
