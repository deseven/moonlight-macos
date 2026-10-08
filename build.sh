#!/bin/bash
#
# build.sh — Build Moonlight for macOS.
#
# Usage:
#   ./build.sh                 # debug build (default)
#   ./build.sh dev             # debug build
#   ./build.sh dev-release     # release build: Developer ID signed, notarized,
#                              # stapled, packed to dist/moonlight-macos.zip and
#                              # installed to /Applications
#
# Signing and notarization parameters are read from .env (see .env.example).
#
# Requirements:
#   - Xcode (full) installed with command line tools
#   - moonlight-common-c submodule initialized:
#       git submodule update --init --recursive
#   - XCFramework deps present in xcframeworks/ (FFmpeg, Opus, SDL2)
#   - A Developer ID Application certificate (required for dev-release)
#
set -euo pipefail

loc="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$loc"

if [[ -f "$loc/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$loc/.env"
    set +a
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT="Moonlight.xcodeproj"
SCHEME="Moonlight for macOS"
APP_NAME="Moonlight"
DERIVED_DATA=".build/DerivedData"
DIST_DIR="$loc/dist"
ZIP_NAME="moonlight-macos.zip"
NOTARY_LOG="$loc/.build/notarization.log"

SIGN_ID="${MOONLIGHT_SIGNING_IDENTITY:-}"

# The project references a specific DEVELOPMENT_TEAM; for local builds we
# override it so our Developer ID can be used without an Apple team.
DEVELOPMENT_TEAM_OVERRIDE=""

# We build unsandboxed (ENABLE_APP_SANDBOX=NO is already in the project).
# Passing CODE_SIGN_ENTITLEMENTS= prevents the sandbox entitlement file from
# being re-applied at link time, keeping the app unsandboxed for local use.
CODE_SIGN_ENTITLEMENTS_OVERRIDE=""

die() {
    echo "❌ $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------
MODE="${1:-dev}"

case "$MODE" in
    dev)         CONFIGURATION="Debug" ;;
    dev-release) CONFIGURATION="Release" ;;
    *) die "Unknown mode '$MODE'. Use 'dev' (debug) or 'dev-release' (release)." ;;
esac

# ---------------------------------------------------------------------------
# Signing & notarization parameters
# ---------------------------------------------------------------------------
if [[ "$MODE" == "dev-release" && -z "$SIGN_ID" ]]; then
    die "MOONLIGHT_SIGNING_IDENTITY is not set in .env (see .env.example); it's required for dev-release."
fi

can_notarize=false
NOTARY_AUTH=()
if [[ "$MODE" == "dev-release" ]]; then
    if [[ -n "${MOONLIGHT_NOTARY_PROFILE:-}" ]]; then
        can_notarize=true
        NOTARY_AUTH=(--keychain-profile "$MOONLIGHT_NOTARY_PROFILE")
    elif [[ -n "${MOONLIGHT_APPLE_ID:-}" && -n "${MOONLIGHT_TEAM_ID:-}" && -n "${MOONLIGHT_APP_PASSWORD:-}" ]]; then
        can_notarize=true
        NOTARY_AUTH=(--apple-id "$MOONLIGHT_APPLE_ID" --team-id "$MOONLIGHT_TEAM_ID" --password "$MOONLIGHT_APP_PASSWORD")
    fi
fi

echo "==> Building $APP_NAME for macOS ($CONFIGURATION)"
echo "==> Signing identity: ${SIGN_ID:-<ad-hoc>}"
if [[ "$MODE" == "dev-release" ]]; then
    echo "==> Notarization: $([[ "$can_notarize" == true ]] && echo enabled || echo "DISABLED (no credentials in .env)")"
fi

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if [[ ! -d "moonlight-common/moonlight-common-c/src" ]]; then
    echo "==> Initializing submodules..."
    git submodule update --init --recursive
fi

missing=0
for fw in FFmpeg.xcframework Opus.xcframework SDL2.xcframework; do
    if [[ ! -d "xcframeworks/$fw" ]]; then
        echo "Missing dependency: xcframeworks/$fw" >&2
        missing=1
    fi
done
if [[ $missing -ne 0 ]]; then
    die "Download the XCFramework deps from the coofdy moonlight-mobile-deps release into xcframeworks/ first."
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
ARGS=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath "$DERIVED_DATA"
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM_OVERRIDE"
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_ENTITLEMENTS="$CODE_SIGN_ENTITLEMENTS_OVERRIDE"
)

if [[ -n "$SIGN_ID" ]]; then
    ARGS+=(CODE_SIGN_IDENTITY="$SIGN_ID")
    if [[ "$MODE" == "dev-release" ]]; then
        # Notarization requires a secure timestamp on every signature and rejects
        # the get-task-allow entitlement Xcode injects into non-archive builds
        ARGS+=(OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
    fi
else
    # Hardened runtime enforces library validation, which rejects the embedded
    # frameworks when everything is ad-hoc signed (there's no team ID to match).
    ARGS+=(CODE_SIGN_IDENTITY="-" ENABLE_HARDENED_RUNTIME=NO)
fi

xcodebuild "${ARGS[@]}"

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || die "Build finished but app bundle not found at expected path: $APP_PATH"

echo
echo "✅ Build complete: $APP_PATH"

if [[ "$MODE" == "dev" ]]; then
    echo "   Open with:  open \"$APP_PATH\""
    exit 0
fi

# ---------------------------------------------------------------------------
# dev-release: verify, notarize, staple, pack, install
# ---------------------------------------------------------------------------
DIST_APP="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

pack_zip() {
    rm -f "$ZIP_PATH"
    # ditto keeps the framework symlinks intact (zip -r would break the signature)
    ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$ZIP_PATH"
}

echo "==> Copying app to $DIST_DIR"
rm -rf "$DIST_APP" "$ZIP_PATH"
mkdir -p "$DIST_DIR"
ditto "$APP_PATH" "$DIST_APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$DIST_APP"
if ! codesign -dvv "$DIST_APP" 2>&1 | grep -q '^Timestamp='; then
    die "The app signature has no secure timestamp, notarization would fail."
fi
if codesign -d --entitlements - "$DIST_APP" 2>/dev/null | grep -q 'get-task-allow'; then
    die "The app is signed with the get-task-allow entitlement, notarization would fail."
fi

pack_zip

if [[ "$can_notarize" == true ]]; then
    echo "==> Notarizing $ZIP_NAME (this usually takes a few minutes)"
    mkdir -p "$(dirname "$NOTARY_LOG")"
    # notarytool's exit code isn't a reliable success indicator, the final status is checked instead
    xcrun notarytool submit "$ZIP_PATH" "${NOTARY_AUTH[@]}" --wait 2>&1 | tee "$NOTARY_LOG" || true

    notary_status="$(sed -n 's/^[[:space:]]*status:[[:space:]]*//p' "$NOTARY_LOG" | tail -n1)"
    notary_id="$(sed -n 's/^[[:space:]]*id:[[:space:]]*//p' "$NOTARY_LOG" | head -n1)"
    if [[ "$notary_status" != "Accepted" ]]; then
        if [[ -n "$notary_id" ]]; then
            echo "==> Notarization log:" >&2
            xcrun notarytool log "$notary_id" "${NOTARY_AUTH[@]}" >&2 || true
        fi
        die "Notarization failed (status: ${notary_status:-unknown})."
    fi

    echo "==> Stapling notarization ticket"
    xcrun stapler staple "$DIST_APP"
    xcrun stapler validate "$DIST_APP"
    spctl --assess --type execute --verbose=2 "$DIST_APP"

    # Re-pack, so the archive contains the stapled app
    pack_zip
    echo "✅ Notarized and stapled: $ZIP_PATH"
else
    echo "⚠️  Notarization credentials are not set in .env (see .env.example)."
    echo "   $ZIP_PATH contains a signed but NOT notarized app."
fi

INSTALL_PATH="/Applications/$APP_NAME.app"
echo "==> Installing to $INSTALL_PATH"
rm -rf "$INSTALL_PATH"
ditto "$DIST_APP" "$INSTALL_PATH"
echo "✅ Installed: $INSTALL_PATH"
echo "   Open with:  open \"$INSTALL_PATH\""
