#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:?Pass the UDID of a booted Apple Silicon simulator}"
MODE="${2:-}"
case "$MODE" in
  ""|--interactive|--search-zero-only|--update-ui-only|--form-hints-only) ;;
  *) echo "Unknown review mode: $MODE" >&2; exit 2 ;;
esac
OUTPUT="$ROOT/.theos/ui-review"
APP="$OUTPUT/UIReview.app"
mkdir -p "$APP" "$OUTPUT/screenshots"
python3 - "$ROOT" "$APP" <<'PY'
import pathlib, plistlib, sys
root, app = map(pathlib.Path, sys.argv[1:])
info = plistlib.loads((root/'tests/LanguageRefresh-Info.plist').read_bytes())
versions = plistlib.loads((root/'Resources/Info.plist').read_bytes())
info.update(CFBundleIdentifier='com.vanson.local.uireview', CFBundleName='VansonMod UI Review', CFBundleExecutable='UIReview', CFBundleDevelopmentRegion='en', CFBundleVersion=versions['CFBundleVersion'], CFBundleShortVersionString=versions['CFBundleShortVersionString'])
(app/'Info.plist').write_bytes(plistlib.dumps(info))
make = (root/'Makefile').read_text().split('VansonMod_FILES =',1)[1].split('# 依赖框架',1)[0]
paths = [p for p in make.replace('\\',' ').split() if p.endswith(('.mm','.cpp')) and p not in ['main.mm','src/core/VMAppDelegate.mm']]
(root/'.theos/ui-review/sources.txt').write_text('\n'.join('"'+str(root/p)+'"' for p in paths))
PY
cp "$ROOT/Resources/AppIcon60x60@2x.png" "$APP/AppIcon60x60@2x.png"
xcrun --sdk iphonesimulator clang++ -target arm64-apple-ios14.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fobjc-arc -std=c++17 -Wno-deprecated-declarations -Wno-nullability-completeness -I"$ROOT" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework AVFoundation -framework MobileCoreServices \
  -framework UniformTypeIdentifiers -framework LinkPresentation -framework JavaScriptCore -framework WebKit \
  "$ROOT/tests/UIReviewHarness.mm" @"$OUTPUT/sources.txt" -o "$APP/UIReview" > "$OUTPUT/simulator-build.log" 2>&1
codesign -s - --force "$APP"
xcrun simctl install "$DEVICE" "$APP"
if [[ "$MODE" == "--interactive" ]]; then
  xcrun simctl launch --terminate-running-process "$DEVICE" com.vanson.local.uireview --interactive
  echo "Interactive preview installed: $APP"
  exit 0
fi
REVIEW_ARGS=()
if [[ "$MODE" == "--search-zero-only" || "$MODE" == "--update-ui-only" || "$MODE" == "--form-hints-only" ]]; then REVIEW_ARGS+=("$MODE"); fi
xcrun simctl launch --terminate-running-process --console "$DEVICE" com.vanson.local.uireview "${REVIEW_ARGS[@]}" | tee "$OUTPUT/ui-review.log"
CONTAINER="$(xcrun simctl get_app_container "$DEVICE" com.vanson.local.uireview data)"
cp "$CONTAINER/Documents/UIReview/"*.png "$OUTPUT/screenshots/"
! rg -q '^FAIL ' "$OUTPUT/ui-review.log"
rg '^PASS: UI review completed' "$OUTPUT/ui-review.log"
echo "Screenshots: $OUTPUT/screenshots"
