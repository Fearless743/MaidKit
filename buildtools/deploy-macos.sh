#!/bin/bash

set -e

# --- CONFIGURATION ---
APP_NAME="MaidKit"
PUBSPEC_FILE="pubspec.yaml"
# ---------------------

if [ ! -f "$PUBSPEC_FILE" ]; then
  echo "Error: pubspec.yaml not found in the current directory."
  exit 1
fi

FLUTTER_VERSION=$(grep '^version: ' "$PUBSPEC_FILE" | awk '{print $2}')

if [ -z "$FLUTTER_VERSION" ]; then
  echo "Error: Could not parse version from pubspec.yaml"
  exit 1
fi

echo "Found Flutter version: $FLUTTER_VERSION"

SKIP_BUILD=false
for arg in "$@"; do
  case "$arg" in
  --no-build) SKIP_BUILD=true ;;
  esac
done

if [ "$SKIP_BUILD" = false ]; then
  echo "Building Flutter macOS app..."
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  ./buildtools/flutter.sh build macos --release
else
  echo "Skipping build (--no-build flag detected)..."
fi

APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "Signing macOS app with Developer ID..."
  codesign --deep --force --verbose \
    --sign "$DEVELOPER_ID" \
    --options runtime \
    "$APP_PATH"

  echo "Verifying code signature..."
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"

  if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    TEMP_ZIP="maidkit-notarization.zip"
    echo "Creating notarization archive..."
    ditto -c -k --keepParent "$APP_PATH" "$TEMP_ZIP"

    echo "Submitting app for notarization..."
    xcrun notarytool submit "$TEMP_ZIP" \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_PASSWORD" \
      --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_PATH"

    echo "Running Gatekeeper verification..."
    spctl -a -vvv "$APP_PATH"

    rm "$TEMP_ZIP"
  else
    echo "Skipping notarization (missing APPLE_ID, TEAM_ID, or APP_PASSWORD)."
  fi
else
  echo "Skipping code signing (no DEVELOPER_ID set)."
fi

echo "Packaging .app bundle into .tar.gz..."
BUILD_DIR="build/macos/Build/Products/Release"
ARCHIVE_NAME="maidkit-macos.tar.gz"

cd "$BUILD_DIR"
tar -czvf "$FLUTTER_PROJECT_DIR/$ARCHIVE_NAME" "${APP_NAME}.app"
cd "$FLUTTER_PROJECT_DIR"

if [ -n "${RCLONE_REMOTE:-}" ] && [ -n "${S3_BUCKET:-}" ]; then
  echo "Uploading archive to S3 via rclone..."
  rclone copyto "$ARCHIVE_NAME" "${RCLONE_REMOTE}:${S3_BUCKET}/$ARCHIVE_NAME" --progress
  echo "Uploaded to ${S3_BUCKET}/${ARCHIVE_NAME}"
else
  echo "Skipping upload (set RCLONE_REMOTE and S3_BUCKET to enable)."
fi

echo "Done! macOS app version $FLUTTER_VERSION packaged."
