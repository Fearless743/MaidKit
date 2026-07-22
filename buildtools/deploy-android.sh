#!/bin/bash

set -e

# --- CONFIGURATION ---
RCLONE_REMOTE="${RCLONE_REMOTE:-r2}"
S3_BUCKET="${S3_BUCKET:-maidkit-releases}"

FLUTTER_PROJECT_DIR=$(pwd)
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
SKIP_PATCH=false
for arg in "$@"; do
  case "$arg" in
  --no-build) SKIP_BUILD=true ;;
  --no-patch) SKIP_PATCH=true ;;
  esac
done

if [ "$SKIP_BUILD" = false ]; then
  echo "Building Flutter Android APK..."
  if [ "$SKIP_PATCH" = false ]; then
    ./buildtools/patch-android-gradle-cfg.sh
  else
    echo "Skipping gradle patch (--no-patch flag detected)..."
  fi
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  ./buildtools/flutter.sh build apk --release --split-per-abi
else
  echo "Skipping build (--no-build flag detected)..."
fi

APK_DIR="build/app/outputs/flutter-apk"
echo "Uploading split APKs to S3 via rclone..."
for apk in "$APK_DIR"/app-*-release.apk; do
  [ -f "$apk" ] || continue
  apk_name=$(basename "$apk")
  echo "  Uploading $apk_name..."
  rclone copyto "$apk" "${RCLONE_REMOTE}:${S3_BUCKET}/$apk_name" --progress
done

echo "Done! Split APKs uploaded to ${S3_BUCKET}/"
