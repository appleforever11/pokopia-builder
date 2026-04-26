#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PokopiaBuilder"
DISPLAY_NAME="Pokopia Builder"
APP_DIR="$ROOT_DIR/dist/$DISPLAY_NAME.app"
DMG_STAGING="$ROOT_DIR/dist/dmg-staging-pokopia-builder"
DMG_RW="$ROOT_DIR/dist/Pokopia-Builder-0.1.0-arm64-rw.dmg"
DMG_PATH="$ROOT_DIR/dist/Pokopia-Builder-0.1.0-arm64.dmg"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
POKOPEDIA_ASSETS="/Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets"

cd "$ROOT_DIR"
swift build -c release --arch arm64 --product "$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/arm64-apple-macosx/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "Sources/PokopiaBuilder/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Sources/PokopiaBuilder/Resources/PokopiaBuilder.icns" "$RESOURCES_DIR/PokopiaBuilder.icns"
while IFS= read -r bundle; do
  ditto "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
done < <(find ".build/arm64-apple-macosx/release" -maxdepth 1 -type d -name "*_PokopiaBuilder.bundle")
if [[ -d "$POKOPEDIA_ASSETS" ]]; then
  ditto "$POKOPEDIA_ASSETS" "$RESOURCES_DIR/PokopediaAssets"
else
  echo "Warning: Pokopedia assets were not found at $POKOPEDIA_ASSETS" >&2
fi
chmod +x "$MACOS_DIR/$APP_NAME"
xattr -cr "$APP_DIR" 2>/dev/null || true

if [[ "${CODE_SIGN:-0}" == "1" ]] && command -v codesign >/dev/null; then
  SIGNING_IDENTITY="${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name.}"
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto --noextattr --noqtn "$APP_DIR" "$DMG_STAGING/$DISPLAY_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
xattr -cr "$DMG_STAGING/$DISPLAY_NAME.app" 2>/dev/null || true

rm -f "$DMG_RW" "$DMG_PATH"
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$DMG_STAGING" -ov -format UDRW "$DMG_RW" >/dev/null
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$DMG_RW"
rm -rf "$DMG_STAGING"

echo "$DMG_PATH"
