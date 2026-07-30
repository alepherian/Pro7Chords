#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INPUT="${1:-/Users/adamhill/Desktop/Test Chord Song_chords.pro}"
PRODUCTS_DIR=""

if BUILD_SETTINGS="$(xcodebuild -project Pro7Chords.xcodeproj -scheme Pro7Chords -showBuildSettings 2>/dev/null)"; then
    PRODUCTS_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { print $2; exit }')"
fi

if [[ -z "$PRODUCTS_DIR" || ! -d "$PRODUCTS_DIR/PackageFrameworks" ]]; then
    for candidate in "$HOME"/Library/Developer/Xcode/DerivedData/Pro7Chords-*/Build/Products/Debug; do
        if [[ -d "$candidate/PackageFrameworks" ]]; then
            PRODUCTS_DIR="$candidate"
            break
        fi
    done
fi

if [[ -z "$PRODUCTS_DIR" || ! -d "$PRODUCTS_DIR/PackageFrameworks" ]]; then
    xcodebuild -project Pro7Chords.xcodeproj -scheme Pro7Chords build
    if BUILD_SETTINGS="$(xcodebuild -project Pro7Chords.xcodeproj -scheme Pro7Chords -showBuildSettings 2>/dev/null)"; then
        PRODUCTS_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { print $2; exit }')"
    fi
fi

if [[ -z "$PRODUCTS_DIR" || ! -d "$PRODUCTS_DIR/PackageFrameworks" ]]; then
    echo "Could not locate built SwiftProtobuf framework. Build the Pro7Chords scheme in Xcode, then rerun this script." >&2
    exit 1
fi

PACKAGE_FRAMEWORKS="$PRODUCTS_DIR/PackageFrameworks"
MODULE_CACHE="/tmp/pro7chords-roundtrip-module-cache"
EXECUTABLE="/tmp/pro7chords-roundtrip-harness"

mkdir -p "$MODULE_CACHE"

xcrun --sdk macosx swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -F "$PACKAGE_FRAMEWORKS" \
    -framework AppKit \
    -framework SwiftUI \
    -framework SwiftProtobuf \
    Pro7Chords/*.pb.swift \
    Pro7Chords/Utilities/AppLogger.swift \
    Pro7Chords/SongSectionAnalyzer.swift \
    Pro7Chords/ProPresenterFileInfo.swift \
    Pro7Chords/ProFileParser.swift \
    Pro7Chords/Services/FileManagerService.swift \
    Diagnostics/RoundTripHarness.swift \
    -o "$EXECUTABLE"

DYLD_FRAMEWORK_PATH="$PACKAGE_FRAMEWORKS" "$EXECUTABLE" "$INPUT"
