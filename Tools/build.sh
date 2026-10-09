#!/bin/bash
# Builds the Compositor executable with the command line tools alone.
#
# Xcode is not installed on this machine, so this replaces `xcodebuild`: it
# compiles the same sources against the same SDK, links a stub Sparkle module
# instead of the auto-updater, and leaves the asset catalog to be copied out of
# the signed upstream app (Tools/bundle.sh does that).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Xcode's toolchain, called directly. `xcrun` and `xcodebuild` refuse to run
# until the licence agreement is accepted, and accepting it needs an admin
# password; the compiler binaries themselves have no such gate.
DEVELOPER="${DEVELOPER:-/Applications/Xcode.app/Contents/Developer}"
SWIFTC="$DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="$DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
# SwiftUI's @State/@Observable and friends are macros; this is where their
# plugin lives. The command line tools alone don't ship it.
PLUGINS="$DEVELOPER/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
OUT="$ROOT/build"
mkdir -p "$OUT"
# Xcode asks the compiler for one .stringsdata per file (SWIFT_EMIT_LOC_STRINGS);
# it is the authoritative list of keys SwiftUI will look up, format specifiers
# and all. Tools/check-strings.py diffs it against the translation.
rm -rf "$OUT/stringsdata"
mkdir -p "$OUT/stringsdata"

test -x "$SWIFTC" || { echo "no compiler at $SWIFTC" >&2; exit 1; }
test -d "$PLUGINS" || { echo "no macro plugins at $PLUGINS" >&2; exit 1; }

# The stub has to be built for the same deployment target as the app, or the
# compiler refuses to import it.
mkdir -p Tools/SparkleLib
"$SWIFTC" -emit-module -emit-library -static -module-name Sparkle \
    -sdk "$SDK" -target arm64-apple-macos26.0 \
    -emit-module-path Tools/SparkleLib/Sparkle.swiftmodule \
    -o Tools/SparkleLib/libSparkle.a \
    Tools/SparkleStub/Sparkle.swift

# bash 3.2 (the system bash) has no mapfile, so read the file lists by hand.
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Compositor -name '*.swift' | sort)
CFILES=()
while IFS= read -r file; do CFILES+=("$file"); done < <(find Compositor -name '*.c' | sort)

echo "compiling ${#SOURCES[@]} Swift files and ${#CFILES[@]} C files"

# The Swift driver hands .c files straight to the linker, so build them with
# clang first and link the objects instead.
CLANG="$DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
OBJECTS=()
mkdir -p "$OUT/obj"
for c in "${CFILES[@]}"; do
    obj="$OUT/obj/$(basename "${c%.c}").o"
    "$CLANG" -c -O2 -isysroot "$SDK" -target arm64-apple-macos26.0 \
        -ICompositor/Rendering -o "$obj" "$c"
    OBJECTS+=("$obj")
done

"$SWIFTC" \
    -sdk "$SDK" \
    -target arm64-apple-macos26.0 \
    -swift-version 5 \
    -O -parse-as-library \
    -plugin-path "$PLUGINS" \
    -emit-localized-strings -emit-localized-strings-path "$OUT/stringsdata" \
    -default-isolation MainActor \
    -enable-upcoming-feature MemberImportVisibility \
    -enable-upcoming-feature NonisolatedNonsendingByDefault \
    -enable-upcoming-feature InferIsolatedConformances \
    -import-objc-header Compositor/Compositor-Bridging-Header.h \
    -Xcc -ICompositor/Rendering \
    -I Tools/SparkleLib -L Tools/SparkleLib -lSparkle \
    -framework SwiftUI -framework AppKit -framework CoreImage \
    -framework Metal -framework Vision -framework Accelerate \
    -framework CoreText -framework QuartzCore -framework UniformTypeIdentifiers \
    -Xlinker -dead_strip \
    -o "$OUT/Compositor" \
    "${SOURCES[@]}" "${OBJECTS[@]}"

echo "built $OUT/Compositor"
