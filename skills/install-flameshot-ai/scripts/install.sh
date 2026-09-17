#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO_DIR=$(CDPATH= cd -- "$SKILL_DIR/../.." && pwd)

if [ "$(uname -s)" != "Darwin" ]; then
    echo "此安装 skill 仅支持 macOS。" >&2
    exit 1
fi

exec "$REPO_DIR/scripts/install-macos.sh"
