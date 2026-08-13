#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

"$SCRIPT_DIR/verify.sh"

print ""
print "Verification passed. Opening the Xcode project..."
open "$PROJECT_ROOT/OpenAIStatusMac.xcodeproj"

print ""
print "In Xcode, select the same Signing Team for both targets:"
print "  1. OpenAI Status"
print "  2. OpenAIStatusWidget"
print "Then select the OpenAI Status scheme, choose My Mac, and press Run."
