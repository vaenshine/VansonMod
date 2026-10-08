#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:?Pass the UDID of a booted Apple Silicon simulator}"
OUTPUT="$ROOT/.theos/string-engine-tests"
APP="$OUTPUT/StringEngineTests.app"
mkdir -p "$APP"
python3 - "$ROOT" "$APP" "$OUTPUT" <<'PY'
import pathlib, plistlib, sys
root, app, output = map(pathlib.Path, sys.argv[1:])
info = plistlib.loads((root/'tests/LanguageRefresh-Info.plist').read_bytes())
info.update(CFBundleIdentifier='com.vanson.local.stringenginetests', CFBundleName='StringEngineTests', CFBundleExecutable='StringEngineTests')
(app/'Info.plist').write_bytes(plistlib.dumps(info))
make = (root/'Makefile').read_text().split('VansonMod_FILES =',1)[1].split('# 依赖框架',1)[0]
paths = [p for p in make.replace('\\',' ').split() if p.endswith(('.mm','.cpp')) and p not in ['main.mm','src/core/VMAppDelegate.mm']]
(output/'sources.txt').write_text('\n'.join('"'+str(root/p)+'"' for p in paths))
PY
xcrun --sdk iphonesimulator clang++ -target arm64-apple-ios14.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fobjc-arc -std=c++17 -Wno-deprecated-declarations -Wno-nullability-completeness -I"$ROOT" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework AVFoundation -framework MobileCoreServices \
  -framework UniformTypeIdentifiers -framework LinkPresentation -framework JavaScriptCore -framework WebKit \
  "$ROOT/tests/StringEngineTests.mm" @"$OUTPUT/sources.txt" -o "$APP/StringEngineTests" > "$OUTPUT/simulator-build.log" 2>&1
codesign -s - --force "$APP"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --terminate-running-process --console "$DEVICE" com.vanson.local.stringenginetests | tee "$OUTPUT/test.log"
! rg -q '^FAIL' "$OUTPUT/test.log"
rg '^PASS: .* live string engine checks' "$OUTPUT/test.log"
