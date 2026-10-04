#!/usr/bin/env bash
set -euo pipefail

# Build a local, interactive Mac Catalyst preview using the actual UIKit pages.
# The preview harness supplies fixture applications and disables update checks.
# This script only builds and signs the app; opening it is a separate user action.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT/.theos/ui-review"
APP="$OUTPUT/VansonModPreview.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

python3 - "$ROOT" "$APP" <<'PY'
from pathlib import Path
import plistlib
import sys

root, app = map(Path, sys.argv[1:])
project_info = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
info = {
    'CFBundleIdentifier': 'com.vanson.local.macpreview',
    'CFBundleName': 'VansonMod Preview',
    'CFBundleDisplayName': 'VansonMod Preview',
    'CFBundleExecutable': 'VansonModPreview',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': project_info['CFBundleVersion'],
    'CFBundleShortVersionString': project_info['CFBundleShortVersionString'],
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleSupportedPlatforms': ['MacOSX'],
    'LSMinimumSystemVersion': '11.0',
    'NSHighResolutionCapable': True,
    'UIApplicationSupportsIndirectInputEvents': True,
    'UIDeviceFamily': [2],
    'UILaunchScreen': {},
}
# UIApplicationMain selects the UIKit application class; keep NSPrincipalClass absent.
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
(app / 'Contents/PkgInfo').write_bytes(b'APPL????')
make = (root / 'Makefile').read_text().split('VansonMod_FILES =', 1)[1].split('# 依赖框架', 1)[0]
paths = [p for p in make.replace('\\', ' ').split()
         if p.endswith(('.mm', '.cpp')) and p not in ['main.mm', 'src/core/VMAppDelegate.mm']]
(root / '.theos/ui-review/catalyst-sources.txt').write_text('\n'.join('"' + str(root / p) + '"' for p in paths))
PY
cp "$ROOT/Resources/AppIcon60x60@2x.png" "$APP/Contents/Resources/AppIcon60x60@2x.png"

if ! xcrun --sdk macosx clang++ -target arm64-apple-ios14.0-macabi \
  -isysroot "$SDK" -isystem "$SDK/System/iOSSupport/usr/include" \
  -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" \
  -F"$SDK/System/iOSSupport/System/Library/Frameworks" \
  -fobjc-arc -std=c++17 -Wno-deprecated-declarations -Wno-nullability-completeness -I"$ROOT" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  -framework AVFoundation -framework MobileCoreServices -framework UniformTypeIdentifiers \
  -framework LinkPresentation -framework JavaScriptCore -framework WebKit \
  "$ROOT/tests/UIReviewHarness.mm" @"$OUTPUT/catalyst-sources.txt" \
  -o "$OUTPUT/.VansonModPreview.new" > "$OUTPUT/catalyst-build.log" 2>&1; then
  tail -80 "$OUTPUT/catalyst-build.log"
  exit 1
fi

mv "$OUTPUT/.VansonModPreview.new" "$APP/Contents/MacOS/VansonModPreview"
codesign -s - --force "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built interactive Mac preview: $APP"
