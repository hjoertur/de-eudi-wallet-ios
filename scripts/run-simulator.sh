#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
device="${1:-045FA0F4-99FB-4755-96C8-C0D4C028E9FE}"
build_dir="$PWD/.local-build"
xcodebuild build -project IDGo.xcodeproj -scheme 'IDGo Dev' \
  -configuration DevDebug -destination "platform=iOS Simulator,id=$device" \
  -derivedDataPath "$build_dir" -skipMacroValidation \
  -skipPackagePluginValidation -packageAuthorizationProvider netrc \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
if ! xcrun simctl list devices booted | grep -Fq "$device"; then
  xcrun simctl boot "$device"
fi
xcrun simctl bootstatus "$device" -b
open -a "$DEVELOPER_DIR/Applications/Simulator.app"
app=$(find "$build_dir/Build/Products/DevDebug-iphonesimulator" -maxdepth 1 -name '*.app' -print -quit)
test -n "$app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName d-you Local' "$app/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :NSAppTransportSecurity:NSAllowsLocalNetworking' "$app/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' "$app/Info.plist"
codesign --force --sign - "$app"
xcrun simctl install "$device" "$app"
SIMCTL_CHILD_TRUSTABLES_LOCAL_SIMULATION=1 \
SIMCTL_CHILD_TRUSTABLES_E2E_PID="${TRUSTABLES_E2E_PID:-}" \
SIMCTL_CHILD_TRUSTABLES_MOCK_PID="${TRUSTABLES_MOCK_PID:-}" \
  xcrun simctl launch --terminate-running-process "$device" org.sprind.wallet.dev
