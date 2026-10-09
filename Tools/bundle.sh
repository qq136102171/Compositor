#!/bin/bash
# Assembles Compositor.app from the freshly built executable.
#
# Xcode is installed but its licence has not been accepted, so `xcodebuild`
# refuses to run and `actool` cannot compile the asset catalog. The assets are
# unchanged upstream files, so they are copied from the shipped app instead;
# everything else here comes from this repository's sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/Tools/upstream-resources"
APP="$ROOT/build/Compositor 中文版.app"
BUNDLE_ID="com.wonderassembly.compositor.zh"
APP_NAME="Compositor 中文版"

test -x "$ROOT/build/Compositor" || { echo "run Tools/build.sh first" >&2; exit 1; }
test -f "$ASSETS/Assets.car" || { echo "missing $ASSETS/Assets.car" >&2; exit 1; }

case "$APP" in
    "$ROOT"/build/*) rm -rf "$APP" ;;
    *) echo "refusing to clear $APP" >&2; exit 1 ;;
esac

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/build/Compositor" "$APP/Contents/MacOS/Compositor"

# Unchanged upstream assets: app icon and the compiled asset catalog.
cp "$ASSETS/Assets.car" "$ASSETS/AppIcon.icns" "$APP/Contents/Resources/"

# Localisation.
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj"
cp "$ROOT"/Tools/zh-Hans.lproj/*.strings "$APP/Contents/Resources/zh-Hans.lproj/"

# Info.plist: the shipped one already has every key the generated plist had;
# only the identity and the updater change.
plutil -convert xml1 -o "$APP/Contents/Info.plist" "$ASSETS/Info.plist"
PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$PLIST"
plutil -replace CFBundleName -string "$APP_NAME" "$PLIST"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$PLIST"
plutil -replace CFBundleExecutable -string "Compositor" "$PLIST"
plutil -remove SUFeedURL "$PLIST" 2>/dev/null || true
plutil -replace SUEnableAutomaticChecks -bool NO "$PLIST"

printf 'APPL????' > "$APP/Contents/PkgInfo"

xattr -cr "$APP"
codesign --force --deep --sign - --timestamp=none \
    --entitlements "$ROOT/Tools/entitlements.plist" "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | tail -2

echo "built: $APP"
