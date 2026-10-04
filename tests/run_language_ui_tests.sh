#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:?Pass the UDID of an already booted test simulator}"
TEST_DIR="$(mktemp -d /tmp/vm-language-ui.XXXXXX)"
APP="$TEST_DIR/LanguageCheck.app"
mkdir -p "$APP"
cp "$ROOT/tests/LanguageRefresh-Info.plist" "$APP/Info.plist"
xcrun --sdk iphonesimulator clang++ -target arm64-apple-ios14.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fobjc-arc -std=c++17 -DVM_LANGUAGE_TRACE="${VM_LANGUAGE_TRACE:-1}" \
  -Wno-incomplete-implementation -Wno-deprecated-declarations -I"$ROOT" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  "$ROOT/tests/LanguageRefreshHarness.mm" \
  "$ROOT/src/core/VMRootViewController.mm" \
  "$ROOT/src/ui/main/VMSettingsViewController.mm" \
  "$ROOT/src/utils/helpers/VMLanguageRefresh.mm" \
  "$ROOT/src/utils/helpers/VMUIHelper.mm" \
  "$ROOT/src/utils/helpers/VMKeyboardAvoidance.mm" \
  "$ROOT/src/utils/helpers/VMLocalization.mm" \
  "$ROOT/src/utils/helpers/LocalizationCore.cpp" \
  "$ROOT"/src/utils/helpers/lang/Lang_*.cpp -o "$APP/LanguageCheck"
codesign -s - --force "$APP"
xcrun simctl install "$DEVICE" "$APP"
trap 'xcrun simctl uninstall "$DEVICE" com.vanson.local.languagecheck >/dev/null 2>&1 || true' EXIT
xcrun simctl launch --console "$DEVICE" com.vanson.local.languagecheck | tee "$TEST_DIR/results.log"
# simctl can exit successfully even if the app exits with a failing assertion.
! rg -q '^FAIL ' "$TEST_DIR/results.log"
rg '^PASS: [0-9]+ language UI checks$' "$TEST_DIR/results.log"
