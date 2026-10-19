#!/bin/bash
# Builds Renamer.app (universal) and packages it into dist/Renamer-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
APP="dist/Renamer.app"
DMG="dist/Renamer-$VERSION.dmg"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Compiling (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/Renamer "$APP/Contents/MacOS/Renamer"

echo "▸ Icon"
swift scripts/make-icon.swift dist/AppIcon.iconset
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf dist/AppIcon.iconset

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Renamer</string>
  <key>CFBundleDisplayName</key><string>Renamer</string>
  <key>CFBundleIdentifier</key><string>app.renamer.mac</string>
  <key>CFBundleExecutable</key><string>Renamer</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "▸ Building DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Renamer" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ $DMG"
