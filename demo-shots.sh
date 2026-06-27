#!/usr/bin/env bash
# Build once, then launch the app with a mocked clock per JourneyPhase and screenshot each,
# so every use case in usecase.md is captured headlessly into docs/. The mocked "now"
# (and at-venue flag) drive the real phase engine — no live clock, deterministic shots.
#
# Usage:  ./demo-shots.sh                 # prefers iPhone 17 Pro
#         ./demo-shots.sh "iPhone 16 Pro"
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="WalletDemo"
BUNDLE_ID="com.pablo.WalletDemo"
DERIVED="$DIR/build"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
OUT="$DIR/docs"
mkdir -p "$OUT"

DEVICE="${1:-iPhone 17 Pro}"
if ! xcrun simctl list devices available | grep -q "$DEVICE ("; then
  alt="$(xcrun simctl list devices available | grep -oE 'iPhone [^(]*' | head -1 | sed 's/ *$//')"
  [ -n "$alt" ] && DEVICE="$alt"
fi

echo ">> Regenerating project + building ($SCHEME, Debug, iOS Simulator)"
xcodegen generate --spec "$DIR/project.yml" --project "$DIR" >/dev/null
xcodebuild -project "$DIR/$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" build 2>&1 | xcbeautify

echo ">> Booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
# A clean, consistent status bar across every shot.
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null || true

shoot() { # name  now  atVenue
  local name="$1" now="$2" atv="$3"
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -DemoNow "$now" -DemoAtVenue "$atv" >/dev/null
  sleep 2.5
  xcrun simctl io "$DEVICE" screenshot "$OUT/uc-$name.png" >/dev/null
  echo ">> shot: docs/uc-$name.png   (now=$now atVenue=$atv)"
}

shoot preEvent    "2026-07-12T10:00:00-04:00" NO
shoot approaching "2026-07-14T14:30:00-04:00" NO
shoot atVenue     "2026-07-14T16:30:00-04:00" YES
shoot inProgress  "2026-07-14T20:00:00-04:00" NO
shoot postEvent   "2026-07-14T23:00:00-04:00" NO
shoot unknown     "none"                      NO

echo ">> All use-case screenshots in $OUT"
