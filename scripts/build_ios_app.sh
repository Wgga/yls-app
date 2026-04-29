#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/iOS/YLSiOSHost.xcodeproj}"
SCHEME="${SCHEME:-YLSiOSHost}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist/ios/YLSiOSHost.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/dist/ios/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/iOS/ExportOptions-Development.plist}"
BUNDLE_ID="${BUNDLE_ID:-com.yls.codex-monitor.ios}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

BUILD_SETTINGS=(
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
)

if [[ -n "${IOS_DEVELOPMENT_TEAM:-}" ]]; then
  BUILD_SETTINGS+=(DEVELOPMENT_TEAM="$IOS_DEVELOPMENT_TEAM")
fi

echo "Archiving $SCHEME -> $ARCHIVE_PATH"
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  "${BUILD_SETTINGS[@]}"

echo "Exporting IPA -> $EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"
