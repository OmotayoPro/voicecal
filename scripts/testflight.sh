#!/bin/bash
# Archives a release build and uploads it to App Store Connect for TestFlight.
#
#   scripts/testflight.sh <TEAM_ID>
#
# Needs: a paid Apple Developer Program membership, that account signed in to Xcode
# (Xcode > Settings > Accounts), an app record for com.omotayotaiwo.voicecal in App Store
# Connect, and a release (non-beta) Xcode selected with `xcode-select`.
# This script has not been run end to end: it could not be, without a developer account.
set -euo pipefail

TEAM_ID="${1:?Usage: scripts/testflight.sh <TEAM_ID>}"
cd "$(dirname "$0")/.."

if xcodebuild -version | grep -qi beta || [[ "$(xcode-select -p)" == *beta* ]]; then
  echo "A beta Xcode is selected. App Store Connect rejects builds from beta Xcode." >&2
  echo "Install the release Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

xcodegen generate
ARCHIVE="build/Voicecal.xcarchive"
xcodebuild archive \
  -project Voicecal.xcodeproj -scheme Voicecal -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates

echo "Uploaded. The build appears in App Store Connect > TestFlight after processing (usually 5 to 30 minutes)."
