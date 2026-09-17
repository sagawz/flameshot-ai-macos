#!/bin/sh
set -eu

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_APP="$SOURCE_DIR/build-smart/src/flameshot.app"
TARGET_APP=${TARGET_APP:-/Applications/Flameshot AI.app}

"$SOURCE_DIR/scripts/build-macos-intel.sh"

if [ ! -x "$BUILD_APP/Contents/MacOS/flameshot" ]; then
    echo "构建结果无效：$BUILD_APP" >&2
    exit 1
fi

osascript -e 'tell application "Flameshot AI" to quit' >/dev/null 2>&1 || true
if [ -e "$TARGET_APP" ]; then
    BACKUP_APP="$TARGET_APP.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$TARGET_APP" "$BACKUP_APP"
    echo "原应用已备份到：$BACKUP_APP"
fi
cp -R "$BUILD_APP" "$TARGET_APP"
codesign --verify --deep --strict "$TARGET_APP"
echo "安装完成：$TARGET_APP"
