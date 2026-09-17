#!/bin/sh
set -eu

if ! xcrun --find clang >/dev/null 2>&1; then
    echo "缺少可用的 Apple Command Line Tools。请先运行：xcode-select --install" >&2
    exit 1
fi
SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="$SOURCE_DIR/build-smart"
QT_ROOT=${QT_ROOT:-}
if [ -z "$QT_ROOT" ] && command -v brew >/dev/null 2>&1; then
    QT_ROOT=$(brew --prefix qt@5 2>/dev/null || brew --prefix qt5 2>/dev/null || true)
fi
if [ -z "$QT_ROOT" ] && [ -d "$HOME/Qt/5.15.2/clang_64" ]; then
    QT_ROOT="$HOME/Qt/5.15.2/clang_64"
fi
MAC_ARCH=${MAC_ARCH:-$(uname -m)}
case "$MAC_ARCH" in
    x86_64) DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-10.15} ;;
    arm64) DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0} ;;
    *) echo "不支持的 Mac 架构：$MAC_ARCH" >&2; exit 1 ;;
esac
CMAKE_BIN=$(command -v cmake || true)
if [ -z "$CMAKE_BIN" ] && [ -x /Users/wangzhen/Library/Python/3.9/bin/cmake ]; then
    CMAKE_BIN=/Users/wangzhen/Library/Python/3.9/bin/cmake
fi
if [ -z "$CMAKE_BIN" ]; then
    echo "缺少 CMake。请先安装 CMake 3.13 或更高版本。" >&2
    exit 1
fi
if [ -z "$QT_ROOT" ] || [ ! -d "$QT_ROOT/lib/cmake/Qt5" ]; then
    echo "没有找到 Qt 5，请通过 QT_ROOT 指定 Qt 5.15 的安装目录。" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"
cp "$SOURCE_DIR/packaging/macos/flameshot.icns" "$BUILD_DIR/flameshot.icns"

"$CMAKE_BIN" -S "$SOURCE_DIR" -B "$BUILD_DIR" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$MAC_ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -DQt5_DIR="$QT_ROOT/lib/cmake/Qt5" \
    -DCMAKE_PREFIX_PATH="$QT_ROOT"
"$CMAKE_BIN" --build "$BUILD_DIR" --parallel 4

APP_PATH="$BUILD_DIR/src/flameshot.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Flameshot AI" \
    "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Flameshot AI" \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Flameshot AI" \
        "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 12.1.0" \
    "$APP_PATH/Contents/Info.plist"
if [ -x "$QT_ROOT/bin/macdeployqt" ]; then
    "$QT_ROOT/bin/macdeployqt" "$APP_PATH" -always-overwrite
    codesign --force --deep --sign - "$APP_PATH"
    codesign --force --sign - \
        --requirements '=designated => identifier "org.flameshot.ai"' \
        "$APP_PATH"
else
    echo "已编译，但没有找到 macdeployqt；应用尚不能独立分发。" >&2
fi
echo "构建结果：$APP_PATH"
