#!/bin/bash
# Собирает AutoSwitcher.app. DMG собирается отдельно: scripts/make-dmg.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="AutoSwitcher.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AutoSwitcher "$APP/Contents/MacOS/AutoSwitcher"

# Ресурсный бандл (словари) — внутрь Contents/Resources/.
mkdir -p "$APP/Contents/Resources"
cp -R .build/arm64-apple-macosx/release/AutoSwitcher_AutoSwitcherCore.bundle "$APP/Contents/Resources/AutoSwitcher_AutoSwitcherCore.bundle"

# Иконка, если сгенерирована (scripts/make-icon.sh).
if [ -f Assets/AppIcon.icns ]; then
    cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AutoSwitcher</string>
    <key>CFBundleIdentifier</key>
    <string>local.autoswitcher.app</string>
    <key>CFBundleName</key>
    <string>AutoSwitcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.3.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string></string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Собрано: $(pwd)/$APP"
