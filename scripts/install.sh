#!/bin/zsh
set -euo pipefail

readonly REPOSITORY="koh-nakagawa/OpenAIStatusMac"
readonly ASSET_NAME="OpenAIStatusMac-unnotarized.zip"
readonly CHECKSUM_NAME="${ASSET_NAME}.sha256"
readonly RELEASE_BASE_URL="https://github.com/${REPOSITORY}/releases/latest/download"
readonly INSTALL_ROOT="${HOME}/Applications"
readonly APP_NAME="OpenAI Status.app"
readonly INSTALL_PATH="${INSTALL_ROOT}/${APP_NAME}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "OpenAI Status requires macOS."
  exit 1
fi

for command_name in curl ditto shasum; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    print -u2 "Required command not found: ${command_name}"
    exit 1
  fi
done

if [[ -e "$INSTALL_PATH" ]]; then
  print -u2 "OpenAI Status is already installed at:"
  print -u2 "  ${INSTALL_PATH}"
  print -u2 "Move the existing app elsewhere, then run this installer again."
  exit 1
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openai-status-install.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

print "==> Downloading the latest release"
curl --fail --location --silent --show-error \
  "${RELEASE_BASE_URL}/${ASSET_NAME}" \
  --output "${TEMP_ROOT}/${ASSET_NAME}"
curl --fail --location --silent --show-error \
  "${RELEASE_BASE_URL}/${CHECKSUM_NAME}" \
  --output "${TEMP_ROOT}/${CHECKSUM_NAME}"

print "==> Verifying SHA-256 checksum"
(
  cd "$TEMP_ROOT"
  shasum -a 256 -c "$CHECKSUM_NAME"
)

print "==> Extracting the application"
ditto -x -k "${TEMP_ROOT}/${ASSET_NAME}" "${TEMP_ROOT}/expanded"

SOURCE_APP="${TEMP_ROOT}/expanded/${APP_NAME}"
if [[ ! -d "$SOURCE_APP" ]]; then
  print -u2 "The release archive does not contain ${APP_NAME}."
  exit 1
fi

mkdir -p "$INSTALL_ROOT"
ditto "$SOURCE_APP" "$INSTALL_PATH"

print ""
print "Installed: ${INSTALL_PATH}"
print ""
print "This free build is signed with an Apple Development certificate but is not notarized."
print "On first launch, macOS may block it. If that happens:"
print "  1. Try to open OpenAI Status once."
print "  2. Open System Settings > Privacy & Security."
print "  3. Click Open Anyway for OpenAI Status."
print ""
print "Do not disable Gatekeeper and do not remove quarantine attributes."
print "After approving the app, launch it once before adding its widgets."
open -R "$INSTALL_PATH"
