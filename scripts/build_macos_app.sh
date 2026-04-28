#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-伊莉思监控助手}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-伊莉思监控助手}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-yls-app}"
BUNDLE_ID="${BUNDLE_ID:-com.yls.codex-monitor}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
ICON_SOURCE_REL="${ICON_SOURCE_REL:-images/yls_logo_1024.png}"
DMG_BACKGROUND_REL="${DMG_BACKGROUND_REL:-images/yls_background.png}"
BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-96}"
DMG_TEXT_SIZE="${DMG_TEXT_SIZE:-14}"
DMG_APP_ICON_POSITION="${DMG_APP_ICON_POSITION:-113,160}"
DMG_APPLICATIONS_ICON_POSITION="${DMG_APPLICATIONS_ICON_POSITION:-330,160}"
DMG_BACKGROUND_ICON_POSITION="${DMG_BACKGROUND_ICON_POSITION:-600,160}"
DMG_WINDOW_CHROME_HEIGHT="${DMG_WINDOW_CHROME_HEIGHT:-56}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_BUNDLE_NAME}.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
PLIST_PATH="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/$ICON_SOURCE_REL"
DMG_BACKGROUND="$ROOT_DIR/$DMG_BACKGROUND_REL"
APP_LOGO_SOURCE="$ROOT_DIR/Sources/yls-app/Resources/yls_logo.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICNS_PATH="$APP_RESOURCES/AppIcon.icns"
DMG_PATH="$DIST_DIR/${APP_BUNDLE_NAME}.dmg"
DMG_STAGE_DIR="$DIST_DIR/.dmg-stage"
DMG_TMP_RW="$DIST_DIR/${APP_BUNDLE_NAME}-rw.dmg"
DMG_MOUNT_DIR="$DIST_DIR/.dmg-mount"
DMG_BACKGROUND_DIR="$DMG_STAGE_DIR/.background"
DMG_BACKGROUND_STAGE_PATH="$DMG_BACKGROUND_DIR/background.png"

cd "$ROOT_DIR"

read -r -a BUILD_ARCH_ARRAY <<< "$BUILD_ARCHS"
if [[ "${#BUILD_ARCH_ARRAY[@]}" -eq 0 ]]; then
  echo "BUILD_ARCHS must contain at least one architecture" >&2
  exit 1
fi

SWIFT_BUILD_ARGS=(-c release)
for arch in "${BUILD_ARCH_ARRAY[@]}"; do
  SWIFT_BUILD_ARGS+=(--arch "$arch")
done

echo "Building release binary for architectures: ${BUILD_ARCH_ARRAY[*]}"
swift build "${SWIFT_BUILD_ARGS[@]}"

BINARY_PATH=""
if [[ "${#BUILD_ARCH_ARRAY[@]}" -gt 1 ]]; then
  UNIVERSAL_BINARY_PATH=".build/apple/Products/Release/$EXECUTABLE_NAME"
  if [[ -f "$UNIVERSAL_BINARY_PATH" ]]; then
    BINARY_PATH="$UNIVERSAL_BINARY_PATH"
  fi
fi

if [[ -z "$BINARY_PATH" ]]; then
  for arch in "${BUILD_ARCH_ARRAY[@]}"; do
    CANDIDATE=".build/${arch}-apple-macosx/release/$EXECUTABLE_NAME"
    if [[ -f "$CANDIDATE" ]]; then
      BINARY_PATH="$CANDIDATE"
      break
    fi
  done
fi

if [[ -z "$BINARY_PATH" && -f ".build/release/$EXECUTABLE_NAME" ]]; then
  BINARY_PATH=".build/release/$EXECUTABLE_NAME"
fi

if [[ -z "$BINARY_PATH" ]]; then
  echo "Release binary not found for architectures: ${BUILD_ARCH_ARRAY[*]}" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Icon source not found: $ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$DMG_BACKGROUND" ]]; then
  echo "DMG background not found: $DMG_BACKGROUND" >&2
  exit 1
fi

if [[ ! -f "$APP_LOGO_SOURCE" ]]; then
  echo "App logo resource not found: $APP_LOGO_SOURCE" >&2
  exit 1
fi

DMG_BACKGROUND_WIDTH="$(sips -g pixelWidth "$DMG_BACKGROUND" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
DMG_BACKGROUND_HEIGHT="$(sips -g pixelHeight "$DMG_BACKGROUND" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
DMG_WINDOW_WIDTH="${DMG_WINDOW_WIDTH:-$DMG_BACKGROUND_WIDTH}"
DMG_WINDOW_HEIGHT="${DMG_WINDOW_HEIGHT:-$DMG_BACKGROUND_HEIGHT}"
if [[ -z "$DMG_WINDOW_WIDTH" || -z "$DMG_WINDOW_HEIGHT" ]]; then
  echo "Failed to read DMG background size: $DMG_BACKGROUND" >&2
  exit 1
fi
DMG_WINDOW_OUTER_HEIGHT=$((DMG_WINDOW_HEIGHT + DMG_WINDOW_CHROME_HEIGHT))

rm -rf "$APP_DIR" "$DMG_PATH" "$ICONSET_DIR" "$DMG_STAGE_DIR" "$DMG_MOUNT_DIR"
rm -f "$DMG_TMP_RW"
rm -f "$DIST_DIR/${APP_BUNDLE_NAME}.zip"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$BINARY_PATH" "$APP_MACOS/$EXECUTABLE_NAME"
chmod +x "$APP_MACOS/$EXECUTABLE_NAME"

mkdir -p "$ICONSET_DIR"
sips -s format png -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$ICONSET_DIR"

cp "$APP_LOGO_SOURCE" "$APP_RESOURCES/yls_logo.png"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" || true
fi

mkdir -p "$DIST_DIR" "$DMG_STAGE_DIR" "$DMG_BACKGROUND_DIR"
cp -R "$APP_DIR" "$DMG_STAGE_DIR/"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
cp "$DMG_BACKGROUND" "$DMG_BACKGROUND_STAGE_PATH"
chflags hidden "$DMG_STAGE_DIR/.background" || true

DMG_STAGE_SIZE_MB="$(du -sm "$DMG_STAGE_DIR" | awk '{print $1}')"
if [[ -z "$DMG_STAGE_SIZE_MB" ]]; then
  DMG_STAGE_SIZE_MB=20
fi
DMG_TOTAL_SIZE_MB=$((DMG_STAGE_SIZE_MB + 80))

hdiutil create \
  -volname "$APP_BUNDLE_NAME" \
  -srcfolder "$DMG_STAGE_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -size "${DMG_TOTAL_SIZE_MB}m" \
  "$DMG_TMP_RW" >/dev/null

mkdir -p "$DMG_MOUNT_DIR"
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TMP_RW" -mountpoint "$DMG_MOUNT_DIR")"
DMG_DEVICE="$(echo "$ATTACH_OUTPUT" | awk '/^\/dev\// {print $1; exit}')"
if [[ -z "$DMG_DEVICE" ]]; then
  echo "Failed to attach temp DMG" >&2
  echo "$ATTACH_OUTPUT" >&2
  exit 1
fi

if [[ -d "$DMG_MOUNT_DIR/.background" ]]; then
  chflags hidden "$DMG_MOUNT_DIR/.background" || true
fi

if command -v osascript >/dev/null 2>&1; then
  if ! OSA_OUTPUT="$(osascript 2>&1 <<APPLESCRIPT
tell application "Finder"
  set mountAlias to (POSIX file "${DMG_MOUNT_DIR}") as alias
  set bgAlias to (POSIX file "${DMG_MOUNT_DIR}/.background/background.png") as alias
  open mountAlias
  delay 1
  set w to front Finder window
  set current view of w to icon view
  set toolbar visible of w to false
  set statusbar visible of w to false
  set sidebar width of w to 0
  set bounds of w to {120, 120, 120 + ${DMG_WINDOW_WIDTH}, 120 + ${DMG_WINDOW_OUTER_HEIGHT}}
  set opts to the icon view options of w
  set arrangement of opts to not arranged
  set icon size of opts to ${DMG_ICON_SIZE}
  set text size of opts to ${DMG_TEXT_SIZE}
  set shows item info of opts to false
  set shows icon preview of opts to false
  set background picture of opts to bgAlias
  try
    set position of item ".background" of w to {${DMG_BACKGROUND_ICON_POSITION}}
  end try
  set position of item "${APP_BUNDLE_NAME}.app" of w to {${DMG_APP_ICON_POSITION}}
  set position of item "Applications" of w to {${DMG_APPLICATIONS_ICON_POSITION}}
  set bounds of w to {120, 120, 120 + ${DMG_WINDOW_WIDTH}, 120 + ${DMG_WINDOW_OUTER_HEIGHT}}
  delay 2
  close w
end tell
APPLESCRIPT
  )"; then
    echo "Warning: Finder layout step failed: $OSA_OUTPUT" >&2
  fi
fi

if [[ -d "$DMG_MOUNT_DIR/.background" ]]; then
  chflags hidden "$DMG_MOUNT_DIR/.background" || true
fi
if [[ -d "$DMG_MOUNT_DIR/.fseventsd" ]]; then
  rm -rf "$DMG_MOUNT_DIR/.fseventsd" || true
fi
if [[ -d "$DMG_MOUNT_DIR/.Trashes" ]]; then
  rm -rf "$DMG_MOUNT_DIR/.Trashes" || true
fi

sync
hdiutil detach "$DMG_DEVICE" >/dev/null

hdiutil convert "$DMG_TMP_RW" -ov -format UDZO -o "$DMG_PATH" >/dev/null
rm -f "$DMG_TMP_RW"
rm -rf "$APP_DIR" "$DMG_STAGE_DIR" "$DMG_MOUNT_DIR"

echo "DMG package: $DMG_PATH"
echo "Binary source: $BINARY_PATH"
echo "Packaged architectures: $(lipo -archs "$BINARY_PATH")"
