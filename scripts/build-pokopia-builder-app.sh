#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PokopiaBuilder"
DISPLAY_NAME="Pokopia Builder"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.appleforever11.pokopiabuilder}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-F025E64E839EE98CCB4208CC695132BBBE0CCA6D}"
DIST_DIR="$ROOT_DIR/dist"
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d /tmp/pokopia-builder-dist.XXXXXX)}"
APP_DIR="$BUILD_ROOT/$DISPLAY_NAME.app"
DMG_STAGING="$BUILD_ROOT/dmg-staging-pokopia-builder"
DMG_MOUNT="$BUILD_ROOT/dmg-mount-pokopia-builder"
DMG_RW="$BUILD_ROOT/Pokopia-Builder-0.1.0-arm64-rw.dmg"
DMG_PATH="$BUILD_ROOT/Pokopia-Builder-0.1.0-arm64.dmg"
FINAL_APP_DIR="$DIST_DIR/$DISPLAY_NAME.app"
FINAL_DMG_PATH="$DIST_DIR/Pokopia-Builder-0.1.0-arm64.dmg"
DMG_BACKGROUND="$ROOT_DIR/dist/assets/pokopia-dmg-background.png"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
POKOPEDIA_ASSETS="/Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets"

clean_bundle_metadata() {
  local target="$1"

  find "$target" -name '._*' -delete 2>/dev/null || true
  dot_clean -m "$target" 2>/dev/null || true
  xattr -cr "$target" 2>/dev/null || true
  find "$target" -name '._*' -delete 2>/dev/null || true
}

cleanup_build_root() {
  if [[ "${KEEP_BUILD_ROOT:-0}" != "1" && "$BUILD_ROOT" == /tmp/pokopia-builder-dist.* ]]; then
    rm -rf "$BUILD_ROOT"
  fi
}

trap cleanup_build_root EXIT

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/generate-dmg-background.py" >/dev/null
swift build -c release --arch arm64 --product "$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/arm64-apple-macosx/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "Sources/PokopiaBuilder/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$CONTENTS_DIR/Info.plist"
cp "Sources/PokopiaBuilder/Resources/PokopiaBuilder.icns" "$RESOURCES_DIR/PokopiaBuilder.icns"
while IFS= read -r bundle; do
  ditto --noextattr --noqtn "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
done < <(find ".build/arm64-apple-macosx/release" -maxdepth 1 -type d -name "*_PokopiaBuilder.bundle")
if [[ -d "$POKOPEDIA_ASSETS" ]]; then
  ditto --noextattr --noqtn "$POKOPEDIA_ASSETS" "$RESOURCES_DIR/PokopediaAssets"
else
  echo "Warning: Pokopedia assets were not found at $POKOPEDIA_ASSETS" >&2
fi
chmod +x "$MACOS_DIR/$APP_NAME"
clean_bundle_metadata "$APP_DIR"

if [[ "${CODE_SIGN:-1}" == "1" ]] && command -v codesign >/dev/null; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
fi

echo "$APP_DIR"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto --noextattr --noqtn "$APP_DIR" "$DMG_STAGING/$DISPLAY_NAME.app"
clean_bundle_metadata "$DMG_STAGING/$DISPLAY_NAME.app"

rm -f "$DMG_RW" "$DMG_PATH"
if command -v create-dmg >/dev/null; then
  create-dmg \
    --volname "$DISPLAY_NAME" \
    --background "$DMG_BACKGROUND" \
    --window-pos 100 100 \
    --window-size 720 480 \
    --icon-size 96 \
    --icon "$DISPLAY_NAME.app" 220 245 \
    --app-drop-link 500 245 \
    --no-internet-enable \
    --filesystem HFS+ \
    --format UDZO \
    "$DMG_PATH" \
    "$DMG_STAGING" >/dev/null
else
  ln -s /Applications "$DMG_STAGING/Applications"
  hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$DMG_STAGING" -ov -format UDRW "$DMG_RW" >/dev/null

  rm -rf "$DMG_MOUNT"
  mkdir -p "$DMG_MOUNT"
  hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen -mountpoint "$DMG_MOUNT" >/dev/null
  mkdir -p "$DMG_MOUNT/.background"
  cp "$DMG_BACKGROUND" "$DMG_MOUNT/.background/pokopia-dmg-background.png"

  if command -v SetFile >/dev/null; then
    SetFile -a V "$DMG_MOUNT/.background"
  fi

  osascript <<APPLESCRIPT >/dev/null
tell application "Finder"
  set dmgFolder to POSIX file "$DMG_MOUNT" as alias
  open dmgFolder
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set the bounds of container window of dmgFolder to {100, 100, 820, 580}
  set viewOptions to the icon view options of container window of dmgFolder
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set background picture of viewOptions to file ".background:pokopia-dmg-background.png" of dmgFolder
  set position of item "$DISPLAY_NAME.app" of dmgFolder to {220, 245}
  set position of item "Applications" of dmgFolder to {500, 245}
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
APPLESCRIPT

  clean_bundle_metadata "$DMG_MOUNT/$DISPLAY_NAME.app"
  if [[ "${CODE_SIGN:-1}" == "1" ]] && command -v codesign >/dev/null; then
    codesign --verify --deep --strict --verbose=2 "$DMG_MOUNT/$DISPLAY_NAME.app"
  fi

  hdiutil detach "$DMG_MOUNT" -quiet
  hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
fi
if [[ "${CODE_SIGN:-1}" == "1" ]] && command -v codesign >/dev/null; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH" >/dev/null
  codesign --verify --verbose=2 "$DMG_PATH"
fi
rm -f "$DMG_RW"
rm -rf "$DMG_STAGING"
rm -rf "$DMG_MOUNT"

mkdir -p "$DIST_DIR"
rm -rf "$FINAL_APP_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$FINAL_APP_DIR"
rm -f "$FINAL_DMG_PATH"
ditto --noextattr --noqtn "$DMG_PATH" "$FINAL_DMG_PATH"
if [[ "${CODE_SIGN:-1}" == "1" ]] && command -v codesign >/dev/null; then
  codesign --verify --verbose=2 "$FINAL_DMG_PATH"
fi

echo "$FINAL_DMG_PATH"
