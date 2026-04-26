#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/PokopiaBuilder.xcodeproj"
SCHEME="PokopiaBuilder"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/AppStoreArchives/PokopiaBuilder.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/AppStoreExport}"
EXPORT_OPTIONS="$ROOT_DIR/config/ExportOptions-AppStore.plist"

cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

build_settings=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  build_settings+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "generic/platform=macOS" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates \
  "${build_settings[@]}"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "$ARCHIVE_PATH"
echo "$EXPORT_PATH"
