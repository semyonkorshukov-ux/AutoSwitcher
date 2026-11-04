#!/bin/bash
# Собирает AutoSwitcher из исходников и устанавливает в /Applications.
# Запускается и для первой установки, и для обновления.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="AutoSwitcher.app"
TARGET="/Applications/$APP"
BUNDLE_ID="local.autoswitcher.app"

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Нужны Command Line Tools. Выполните xcode-select --install и запустите скрипт снова." >&2
    exit 1
fi

./scripts/make-app.sh

# Выходим из работающей копии: две одновременно исправляли бы текст дважды.
pkill -x AutoSwitcher 2>/dev/null || true
sleep 1

rm -rf "$TARGET"
ditto "$APP" "$TARGET"

# У каждой сборки своя подпись, поэтому доступ от прошлой версии не подойдёт
# и macOS не покажет новый запрос, пока старая запись не сброшена.
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true

open "$TARGET"

echo
echo "AutoSwitcher установлен: $TARGET"
echo "В появившемся запросе нажмите «Открыть Системные настройки» и включите AutoSwitcher."
