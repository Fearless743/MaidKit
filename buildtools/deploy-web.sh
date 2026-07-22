#!/bin/bash

set -e

# --- CONFIGURATION ---
PROJECT_NAME="${PROJECT_NAME:-maidkit}"
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

echo "Building Flutter web app..."
flutter pub get
dart run build_runner build --delete-conflicting-outputs
./buildtools/flutter.sh build web --base-href=/ --release

echo "Deploying to Cloudflare Pages..."
BUILD_DIR="build/web"

cd "$BUILD_DIR"
wrangler pages deploy . --project-name="$PROJECT_NAME" --branch main
cd -

echo "Done! Web app version $FLUTTER_VERSION has been deployed to Cloudflare Pages."
