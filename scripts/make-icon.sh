#!/bin/bash
# Генерирует Assets/AppIcon.icns из скрипта отрисовки.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AutoSwitcher.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" build

swift scripts/make-icon.swift "$ICONSET"
mkdir -p Assets
iconutil -c icns "$ICONSET" -o Assets/AppIcon.icns
echo "Иконка: $(pwd)/Assets/AppIcon.icns"
