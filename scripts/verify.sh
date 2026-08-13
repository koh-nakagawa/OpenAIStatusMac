#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This project requires macOS."
  exit 1
fi

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
elif ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 "Xcode is required. Install Xcode 26 or later and run this script again."
  exit 1
fi

cd "$PROJECT_ROOT"

print "==> Toolchain"
xcodebuild -version
xcrun swift --version

print "==> Project metadata"
plutil -lint OpenAIStatusMac.xcodeproj/project.pbxproj
plutil -lint OpenAIStatus/Widget/Info.plist
plutil -lint OpenAIStatus/Widget/OpenAIStatusWidget.entitlements

print "==> Swift tests"
xcrun swift test

print "==> Live OpenAI status API verification"
xcrun swift run StatusVerifier

print "==> Unsigned Debug build"
xcodebuild \
  -project OpenAIStatusMac.xcodeproj \
  -scheme "OpenAI Status" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$PROJECT_ROOT/.build/xcode" \
  CODE_SIGNING_ALLOWED=NO \
  build

print "==> Verification completed"
