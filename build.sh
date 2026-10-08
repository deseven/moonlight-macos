#!/bin/bash
#
# build.sh — Build Moonlight for macOS (debug or release) with Developer ID signing.
#
# Usage:
#   ./build.sh                 # debug build (default)
#   ./build.sh dev             # debug build
#   ./build.sh dev-release     # release build, installed to /Applications
#
# Outputs the .app bundle to the DerivedData products dir and prints its path.
# In dev-release mode the bundle is also copied to /Applications, replacing
# any existing Moonlight.app there.
#
# Requirements:
#   - Xcode (full) installed with command line tools
#   - moonlight-common-c submodule initialized:
#       git submodule update --init --recursive
#   - XCFramework deps present in xcframeworks/ (FFmpeg, Opus, SDL2)
#   - A Developer ID certificate (for local signed builds)
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT="Moonlight.xcodeproj"
SCHEME="Moonlight for macOS"

# Signing: use the user's Developer ID if found; fall back gracefully.
# Override with env vars, e.g.  SIGN_ID="Developer ID Application: Foo (BAR)"
SIGN_ID="${SIGN_ID:-}"
if [[ -z "$SIGN_ID" ]]; then
    # Look for a Developer ID certificate in the keychain,
    # extracting the value from inside the surrounding quotes.
    SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
        | head -n1 \
        || true)"
fi

# The project references a specific DEVELOPMENT_TEAM; for local builds we
# override it so our Developer ID can be used without an Apple team.
DEVELOPMENT_TEAM_OVERRIDE=""

# We build unsandboxed (ENABLE_APP_SANDBOX=NO is already in the project).
# Passing CODE_SIGN_ENTITLEMENTS= prevents the sandbox entitlement file from
# being re-applied at link time, keeping the app unsandboxed for local use.
CODE_SIGN_ENTITLEMENTS_OVERRIDE=""

# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------
MODE="${1:-dev}"

case "$MODE" in
    dev|dev-release)
        if [[ "$MODE" == "dev-release" ]]; then
            CONFIGURATION="Release"
        else
            CONFIGURATION="Debug"
        fi
        ;;
    *)
        echo "Unknown mode '$MODE'. Use 'dev' (debug) or 'dev-release' (release)." >&2
        exit 1
        ;;
esac

echo "==> Building Moonlight for macOS ($CONFIGURATION)"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
# Ensure submodules are present
if [[ ! -d "moonlight-common/moonlight-common-c/src" ]]; then
    echo "==> Initializing submodules..."
    git submodule update --init --recursive
fi

# Ensure required xcframeworks exist
missing=0
for fw in FFmpeg.xcframework Opus.xcframework SDL2.xcframework; do
    if [[ ! -d "xcframeworks/$fw" ]]; then
        echo "Missing dependency: xcframeworks/$fw" >&2
        missing=1
    fi
done
if [[ $missing -ne 0 ]]; then
    echo "Download the XCFramework deps from the coofdy moonlight-mobile-deps release into xcframeworks/ first." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
ARGS=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath ".build/DerivedData"
    CODE_SIGN_IDENTITY="$SIGN_ID"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM_OVERRIDE"
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_ENTITLEMENTS="$CODE_SIGN_ENTITLEMENTS_OVERRIDE"
)

echo "==> Signing identity: ${SIGN_ID:-<none>}"
xcodebuild "${ARGS[@]}"

# ---------------------------------------------------------------------------
# Locate and report the product
# ---------------------------------------------------------------------------
APP_PATH=".build/DerivedData/Build/Products/$CONFIGURATION/Moonlight.app"

if [[ -d "$APP_PATH" ]]; then
    echo
    echo "✅ Build complete: $APP_PATH"

    if [[ "$MODE" == "dev-release" ]]; then
        INSTALL_PATH="/Applications/Moonlight.app"
        echo "==> Installing to $INSTALL_PATH"
        rm -rf "$INSTALL_PATH"
        ditto "$APP_PATH" "$INSTALL_PATH"
        echo "✅ Installed: $INSTALL_PATH"
        echo "   Open with:  open \"$INSTALL_PATH\""
    else
        echo "   Open with:  open \"$APP_PATH\""
    fi
else
    echo "Build finished but app bundle not found at expected path: $APP_PATH" >&2
    exit 1
fi