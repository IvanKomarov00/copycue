#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/CopyCue.app"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/copycue-build.XXXXXX")"
STAGED_APP_DIR="$STAGING_DIR/CopyCue.app"
CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

trap '/bin/rm -rf "$STAGING_DIR"' EXIT

cd "$PROJECT_DIR"
mkdir -p ".build/ModuleCache" ".cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export XDG_CACHE_HOME="$PROJECT_DIR/.cache"

SWIFT_BUILD_FLAGS=(-c release --product CopyCue)
if [[ "${COPYCUE_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    SWIFT_BUILD_FLAGS=(--disable-sandbox "${SWIFT_BUILD_FLAGS[@]}")
fi

swift build "${SWIFT_BUILD_FLAGS[@]}"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
install -m 755 ".build/release/CopyCue" "$MACOS_DIR/CopyCue"
install -m 644 "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
install -m 644 "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

xattr -cr "$STAGED_APP_DIR"
codesign --force --deep --sign - "$STAGED_APP_DIR"
xattr -cr "$STAGED_APP_DIR"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP_DIR"

/bin/rm -rf "$APP_DIR"
mkdir -p "${APP_DIR:h}"
/bin/cp -R -X "$STAGED_APP_DIR" "$APP_DIR"
codesign --verify --deep --verbose=2 "$APP_DIR"

echo "$APP_DIR"
