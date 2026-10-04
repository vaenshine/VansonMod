#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:?Pass the UDID of a booted Apple Silicon simulator}"
OUTPUT="$ROOT/.theos/release-screenshots"
APP="$OUTPUT/ReleaseScreenshots.app"
mkdir -p "$APP"
python3 - "$ROOT" "$APP" "$OUTPUT" <<'PY'
from pathlib import Path
import plistlib, sys
root, app, output = map(Path, sys.argv[1:])
info = plistlib.loads((root/'tests/LanguageRefresh-Info.plist').read_bytes())
version = plistlib.loads((root/'Resources/Info.plist').read_bytes())
info.update(CFBundleIdentifier='com.vanson.local.releasescreenshots', CFBundleName='VansonMod Screenshots',
            CFBundleExecutable='ReleaseScreenshots', CFBundleDevelopmentRegion='en',
            CFBundleVersion=version['CFBundleVersion'], CFBundleShortVersionString=version['CFBundleShortVersionString'])
(app/'Info.plist').write_bytes(plistlib.dumps(info))
make = (root/'Makefile').read_text().split('VansonMod_FILES =',1)[1].split('# 依赖框架',1)[0]
sources = [p for p in make.replace('\\',' ').split() if p.endswith(('.mm','.cpp')) and p not in ['main.mm','src/core/VMAppDelegate.mm']]
(output/'sources.txt').write_text('\n'.join('"'+str(root/p)+'"' for p in sources))
PY
cp "$ROOT/Resources/AppIcon60x60@2x.png" "$APP/AppIcon60x60@2x.png"
xcrun --sdk iphonesimulator clang++ -target arm64-apple-ios14.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fobjc-arc -std=c++17 -Wno-deprecated-declarations -Wno-nullability-completeness -I"$ROOT" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework AVFoundation -framework MobileCoreServices \
  -framework UniformTypeIdentifiers -framework LinkPresentation -framework JavaScriptCore -framework WebKit \
  "$ROOT/tests/ReleaseScreenshotHarness.mm" @"$OUTPUT/sources.txt" -o "$APP/ReleaseScreenshots" > "$OUTPUT/build.log" 2>&1
codesign -s - --force "$APP"
# The fixture app has its own disposable sandbox, separate from normal previews.
xcrun simctl uninstall "$DEVICE" com.vanson.local.releasescreenshots >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --terminate-running-process --console "$DEVICE" com.vanson.local.releasescreenshots | tee "$OUTPUT/capture.log"
! rg -q '^FAIL ' "$OUTPUT/capture.log"
rg '^PASS: Release screenshots completed \(12 screenshots\)' "$OUTPUT/capture.log"
CONTAINER="$(xcrun simctl get_app_container "$DEVICE" com.vanson.local.releasescreenshots data)"
python3 - "$CONTAINER" "$ROOT" <<'PY'
from pathlib import Path
import shutil, sys
container, root = map(Path, sys.argv[1:])
source = container/'Documents/ReleaseScreenshots'
names = 'APP_SELECT MEM_DEBUG MEM_BROWSER MEM_HEX_MIX POINTER_ANALYSIS POINTER_VERIFY POINTER_LOCKER RVA_MANAGER SCRIPT_EDITOR SCRIPT_CREATE SETTINGS SETTINGS_DARK'.split()
for name in names:
    path = source/(name+'.PNG')
    assert path.is_file() and path.stat().st_size > 10000, name
for name in names: shutil.copy2(source/(name+'.PNG'), root/'Screenshots'/ (name+'.PNG'))
print('Updated 12 public screenshots in Screenshots/.')
PY
