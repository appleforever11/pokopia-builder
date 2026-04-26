#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/AppStoreArchives/PokopiaBuilder.xcarchive}"
UPLOAD_PATH="${UPLOAD_PATH:-$ROOT_DIR/build/AppStoreUpload}"
EXPORT_OPTIONS="$ROOT_DIR/config/ExportOptions-AppStoreUpload.plist"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found at $ARCHIVE_PATH. Run scripts/archive-app-store.sh first." >&2
  exit 1
fi

rm -rf "$UPLOAD_PATH"

if ! xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$UPLOAD_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates; then
  cat >&2 <<'EOF'

Upload failed. If Xcode reports "Error Downloading App Information",
verify App Store Connect has a macOS app record for bundle ID:

  com.appleforever11.pokopiabuilder

See docs/APP_STORE_SUBMISSION.md for the current checklist.
EOF
  exit 1
fi

echo "$UPLOAD_PATH"
