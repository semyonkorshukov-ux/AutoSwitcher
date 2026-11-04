#!/bin/bash
# Собирает установочный DMG из готового AutoSwitcher.app (см. scripts/make-app.sh):
# окно со значком приложения, стрелкой и ярлыком на «Программы».
set -euo pipefail
cd "$(dirname "$0")/.."

APP="AutoSwitcher.app"
VOLUME="AutoSwitcher"
[ -d "$APP" ] || { echo "Нет $APP — сначала запустите scripts/make-app.sh" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/AutoSwitcher-$VERSION.dmg"
WORK="build/dmg"
STAGING="$WORK/staging"
RW_DMG="$WORK/rw.dmg"
MOUNT="/Volumes/$VOLUME"

# Чужой или оставшийся от прошлой сборки том с тем же именем сломает настройку окна.
if [ -e "$MOUNT" ]; then
    echo "Том $MOUNT уже подключён — извлеките его и повторите." >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$STAGING/.background"
ditto "$APP" "$STAGING/$APP"
ln -s /Applications "$STAGING/Applications"

swift scripts/make-dmg-background.swift "$WORK/bg.png" 1
swift scripts/make-dmg-background.swift "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$STAGING/.background/background.tiff" 2>/dev/null

hdiutil create -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW_DMG" -quiet

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT" "$RW_DMG" | awk '/^\/dev\// {print $1; exit}')
detach() { [ -n "${DEVICE:-}" ] && hdiutil detach "$DEVICE" -quiet -force || true; DEVICE=""; }
trap detach EXIT

# Значок тома копируется уже на подключённый образ: hdiutil -srcfolder его не переносит.
if [ -f Assets/AppIcon.icns ]; then
    cp Assets/AppIcon.icns "$MOUNT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT"
fi

# Расположение значков хранит сам Finder в .DS_Store тома.
# Без разрешения на управление Finder образ останется рабочим, но без оформления окна.
if ! osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "$APP" of container window to {170, 190}
        set position of item "Applications" of container window to {490, 190}
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
then
    echo "ВНИМАНИЕ: Finder не настроил окно — DMG будет без оформления." >&2
fi

sync
rm -rf "$MOUNT/.fseventsd"
detach

rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
rm -rf "$WORK"
echo "DMG: $(pwd)/$DMG"
