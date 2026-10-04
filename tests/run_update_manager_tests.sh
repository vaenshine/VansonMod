#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:?Pass the UDID of an already booted test simulator}"
TEST_DIR="$(mktemp -d /tmp/vm-update-manager.XXXXXX)"
APP="$TEST_DIR/UpdateCheck.app"
mkdir -p "$APP"
cp "$ROOT/tests/LanguageRefresh-Info.plist" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.vanson.local.updatecheck' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName UpdateCheck' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable UpdateCheck' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 3.5' "$APP/Info.plist"
xcrun --sdk iphonesimulator clang++ -target arm64-apple-ios14.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fobjc-arc -std=c++17 -Wno-incomplete-implementation -Wno-deprecated-declarations -I"$ROOT" \
  -framework UIKit -framework Foundation \
  "$ROOT/tests/UpdateManagerTests.mm" "$ROOT/src/utils/managers/VMUpdateManager.mm" \
  -o "$APP/UpdateCheck"
codesign -s - --force "$APP"
xcrun simctl install "$DEVICE" "$APP"
trap 'xcrun simctl uninstall "$DEVICE" com.vanson.local.updatecheck >/dev/null 2>&1 || true' EXIT
xcrun simctl launch --console "$DEVICE" com.vanson.local.updatecheck | tee "$TEST_DIR/results.log"
! rg -q '^FAIL:' "$TEST_DIR/results.log"
rg '^PASS: [0-9]+ update manager checks$' "$TEST_DIR/results.log"
