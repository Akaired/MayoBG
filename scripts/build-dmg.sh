#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Building Release ==="
xcodebuild -project MayoBG.xcodeproj -scheme MayoBG -configuration Release build -quiet

APP_PATH="$(find /Users/davide/Library/Developer/Xcode/DerivedData/MayoBG-*/Build/Products/Release -name 'MayoBG.app' -type d | head -1)"

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built MayoBG.app"
    exit 1
fi

echo "App: $APP_PATH"

rm -rf dist
mkdir -p dist

STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "=== Creating DMG ==="
DMG_TEMP="dist/MayoBG_temp.dmg"
DMG_FINAL="dist/MayoBG.dmg"

hdiutil create -volname MayoBG -srcfolder "$STAGING" -ov -format UDRW -size 100M -fs HFS+ "$DMG_TEMP"
rm -rf "$STAGING"

echo "=== Mounting ==="
hdiutil attach -readwrite -noverify "$DMG_TEMP" -quiet
sleep 2

if [ ! -d "/Volumes/MayoBG" ]; then
    echo "Error: not mounted"
    exit 1
fi

# Generate background directly in mounted volume
mkdir -p "/Volumes/MayoBG/.background"
python3 - "/Volumes/MayoBG/.background/background.png" <<'PYEOF'
import sys
from PIL import Image, ImageDraw
w, h = 460, 340
img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
cx, cy = 230, 155
b, a = 50, 30
draw.polygon([(cx-b, cy-a), (cx+b, cy), (cx-b, cy+a)],
             fill=(255,255,255,150), outline=(255,255,255,220))
img.save(sys.argv[1])
PYEOF

sleep 1

echo "=== Setting layout ==="
osascript <<'OSAEOF'
tell application "Finder"
    set d to disk "MayoBG"
    open d
    delay 0.4
    set cw to container window of d
    set toolbar visible of cw to false
    set statusbar visible of cw to false
    set bounds of cw to {200, 200, 660, 540}
    set vo to icon view options of cw
    set icon size of vo to 96
    set arrangement of vo to not arranged
    set background picture of vo to file ".background:background.png" of d
    set position of item "MayoBG.app" of d to {120, 180}
    set position of item "Applications" of d to {340, 180}
    update d without registering applications
    delay 0.3
    close cw
end tell
OSAEOF

echo "=== Finalizing ==="
sleep 1
DEVICE=$(hdiutil info | awk '/\/dev\// && /MayoBG/ { print $1; exit }')
hdiutil detach "$DEVICE" -quiet
sleep 2
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TEMP"

echo "=== Done: $DMG_FINAL ==="
ls -lh "$DMG_FINAL"

cp "$DMG_FINAL" ~/Downloads/MayoBG.dmg
echo "Copied to ~/Downloads/MayoBG.dmg"
