#!/usr/bin/env bash
# Based on Cicada (https://github.com/wquguru/cicada), Apache License 2.0.
# Modified by CognivexAI, 2026.
# Builds "build/Snart.app" (Apple silicon or Intel via ARCH=arm64|x86_64, default: host arch).
# Without RELEASE=1 it is a dev build: "Snart Dev", bundle id eu.cognivexai.interpreter.dev (its own
# settings, permissions and meeting records), stamped with the branch and commit, which show in the
# menu bar and panel; its icon carries a "DEV" band. RELEASE=1 builds the real eu.cognivexai.interpreter.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${ARCH:-$(uname -m)}"
swift build -c release --arch "$ARCH" --product Cicada
swift build -c release --product CicadaIcon
BIN=$(swift build -c release --arch "$ARCH" --show-bin-path)
HOST_BIN=$(swift build -c release --show-bin-path)

APP="build/Snart.app"
ICONSET=build/AppIcon.iconset
rm -rf "$APP" "$ICONSET" build/LiveSubs.app build/Cicada.app "build/Cognivex Interpreter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/Cicada" "$APP/Contents/MacOS/Snart"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/sample/sample.m4a "$APP/Contents/Resources/"
# The experimental voiceprint model; the app compiles it on first use (no coremlcompiler in the CLT).
cp -R Resources/models/SpeakerEmbedding.mlpackage "$APP/Contents/Resources/"
# English only, whatever languages the Mac lists.
cp -R Resources/en.lproj "$APP/Contents/Resources/"

PLIST="$APP/Contents/Info.plist"
# One version for every platform, in VERSION at the repo root (the committed Info.plist value is unused).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(tr -d '[:space:]' < VERSION)" "$PLIST"
if [[ "${RELEASE:-}" != 1 ]]; then
  STAMP="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local) @ $(git rev-parse --short HEAD 2>/dev/null || echo none)"
  [[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]] && STAMP+="+"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier eu.cognivexai.interpreter.dev" \
    -c "Set :CFBundleName Snart Dev" -c "Set :CFBundleDisplayName Snart Dev" \
    -c "Add :LiveSubsDev string $STAMP" "$PLIST"
  # Only the two name lines change: the usage descriptions in the same files stay.
  sed -i '' -E 's/^(CFBundle(Display)?Name = ")([^"]*)";/\1\3 Dev";/' \
    "$APP"/Contents/Resources/*.lproj/InfoPlist.strings
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
fi

ICON_FLAGS=()
[[ "${RELEASE:-}" == 1 ]] || ICON_FLAGS=(--dev)
"$HOST_BIN/CicadaIcon" ${ICON_FLAGS[@]+"${ICON_FLAGS[@]}"} "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# A fixed designated requirement (the bundle id alone), so rebuilding keeps the system-audio and
# microphone permissions instead of asking again after every build. A Developer ID signature
# (SIGN_IDENTITY, set for releases) keeps the same requirement: permissions granted to the earlier
# ad-hoc builds carry over. It adds the hardened runtime and a timestamp, which notarization needs.
ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$PLIST")
SIGN_FLAGS=(--sign -)
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  SIGN_FLAGS=(--sign "$SIGN_IDENTITY" --options runtime --timestamp --entitlements Resources/Cicada.entitlements)
fi
codesign --force "${SIGN_FLAGS[@]}" --requirements "=designated => identifier \"$ID\"" "$APP" >/dev/null
echo "Built $APP ($ID, signed by ${SIGN_IDENTITY:-ad hoc})"
