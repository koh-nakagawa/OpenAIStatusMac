#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
VERSION="${1:-1.1.0}"
TEAM_ID="${OPENAI_STATUS_DEVELOPMENT_TEAM:-}"
SIGNING_IDENTITY="${OPENAI_STATUS_CODE_SIGN_IDENTITY:-}"
DERIVED_DATA_PATH="${PROJECT_ROOT}/.build/release-${VERSION}"
DIST_DIR="${PROJECT_ROOT}/dist"
ASSET_NAME="OpenAIStatusMac-unnotarized.zip"
CHECKSUM_NAME="${ASSET_NAME}.sha256"

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "Release packaging requires macOS."
  exit 1
fi

if [[ -z "$TEAM_ID" ]]; then
  print -u2 "Set OPENAI_STATUS_DEVELOPMENT_TEAM to the Apple Development Team ID."
  exit 1
fi

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
elif ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 "Xcode 26 or later is required on the maintainer's build Mac."
  exit 1
fi

for command_name in codesign ditto lipo shasum xcodebuild; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    print -u2 "Required command not found: ${command_name}"
    exit 1
  fi
done

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  print -u2 "No valid Apple Development signing identity was found in the Keychain."
  exit 1
fi

mkdir -p "$DIST_DIR"
if [[ -e "${DIST_DIR}/${ASSET_NAME}" || -e "${DIST_DIR}/${CHECKSUM_NAME}" ]]; then
  print -u2 "Release assets already exist in ${DIST_DIR}. Move them aside before rebuilding."
  exit 1
fi

cd "$PROJECT_ROOT"

print "==> Building OpenAI Status ${VERSION}"
xcodebuild \
  -project OpenAIStatusMac.xcodeproj \
  -scheme "OpenAI Status" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  PROVISIONING_PROFILE_SPECIFIER="" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  clean build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/OpenAI Status.app"
WIDGET_PATH="${APP_PATH}/Contents/PlugIns/OpenAIStatusWidget.appex"

if [[ ! -d "$APP_PATH" || ! -d "$WIDGET_PATH" ]]; then
  print -u2 "The built app or embedded Widget Extension is missing."
  exit 1
fi

print "==> Verifying host and Widget Extension signatures"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --strict --verbose=2 "$WIDGET_PATH"

if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -q '<key>com.apple.security.get-task-allow</key><true/>'; then
  print -u2 "The host app contains the development-only get-task-allow entitlement."
  exit 1
fi

if codesign -d --entitlements :- "$WIDGET_PATH" 2>/dev/null | grep -q '<key>com.apple.security.get-task-allow</key><true/>'; then
  print -u2 "The Widget Extension contains the development-only get-task-allow entitlement."
  exit 1
fi

HOST_EXECUTABLE="${APP_PATH}/Contents/MacOS/OpenAI Status"
WIDGET_EXECUTABLE="${WIDGET_PATH}/Contents/MacOS/OpenAIStatusWidget"
lipo "$HOST_EXECUTABLE" -verify_arch arm64 x86_64
lipo "$WIDGET_EXECUTABLE" -verify_arch arm64 x86_64

HOST_TEAM="$(codesign -d --verbose=4 "$APP_PATH" 2>&1 | awk -F= '/^TeamIdentifier=/ { print $2; exit }')"
WIDGET_TEAM="$(codesign -d --verbose=4 "$WIDGET_PATH" 2>&1 | awk -F= '/^TeamIdentifier=/ { print $2; exit }')"

if [[ -z "$HOST_TEAM" || "$HOST_TEAM" != "$WIDGET_TEAM" || "$HOST_TEAM" != "$TEAM_ID" ]]; then
  print -u2 "Host/Widget signing-team mismatch: host=${HOST_TEAM:-none}, widget=${WIDGET_TEAM:-none}, expected=${TEAM_ID}"
  exit 1
fi

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openai-status-release.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT
ditto "$APP_PATH" "${STAGING_ROOT}/OpenAI Status.app"

print "==> Creating ${ASSET_NAME}"
(
  cd "$STAGING_ROOT"
  ditto -c -k --sequesterRsrc --keepParent "OpenAI Status.app" "${DIST_DIR}/${ASSET_NAME}"
)

print "==> Writing SHA-256 checksum"
(
  cd "$DIST_DIR"
  shasum -a 256 "$ASSET_NAME" > "$CHECKSUM_NAME"
)

print "==> Rechecking the packaged application"
ditto -x -k "${DIST_DIR}/${ASSET_NAME}" "${STAGING_ROOT}/verification"
codesign --verify --deep --strict --verbose=2 "${STAGING_ROOT}/verification/OpenAI Status.app"

print ""
print "Release assets created:"
print "  ${DIST_DIR}/${ASSET_NAME}"
print "  ${DIST_DIR}/${CHECKSUM_NAME}"
print "Signing Team: ${HOST_TEAM}"
print "Architectures: $(lipo "$HOST_EXECUTABLE" -archs)"
print "Notarized: no"
