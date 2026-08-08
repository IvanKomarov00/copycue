#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"

cd "$PROJECT_DIR"
mkdir -p ".build/ModuleCache" ".cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export XDG_CACHE_HOME="$PROJECT_DIR/.cache"

SWIFT_TEST_FLAGS=()
if [[ "${COPYCUE_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    SWIFT_TEST_FLAGS+=(--disable-sandbox)
fi

swift test "${SWIFT_TEST_FLAGS[@]}"
