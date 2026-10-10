#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/third_party/dist"

TAG="v2.3.0"
PLATFORM="${1:-linux-x86_64}"

mkdir -p "$DIST_DIR"

case "$PLATFORM" in
  linux-x86_64)
    ARCHIVE="aether-linux-x86_64.tar.gz"
    EXPECTED_SHA256="77c6ce41695a616660d834b55be235c17e7588a474dfd737b71ca80b685bdc8a"
    ;;
  linux-arm64)
    ARCHIVE="aether-linux-arm64.tar.gz"
    EXPECTED_SHA256="7251cbb90c4a0eccb62412727ebee9f0a7b775d20d26492c082ba5df64f8c21f"
    ;;
  android-arm64)
    ARCHIVE="aether-android-arm64.tar.gz"
    EXPECTED_SHA256="038748745244828ea41a808958f16a1c25053dc61db977c95ceb2d3a0b2f7970"
    ;;
  android-armeabi-v7a)
    ARCHIVE="aether-android-armv7.tar.gz"
    EXPECTED_SHA256="9e9c59b188ff235053ae22b9f007f31de3e9bc71c8252ef73b0d626b85b64dae"
    ;;
  android-x86_64)
    ARCHIVE="aether-android-x86_64.tar.gz"
    EXPECTED_SHA256="9acd35dc7bafd4bbf0f4bd8337cb26c4efe6ab0d84ec01d1a0a9fa68168b09c1"
    ;;
  windows-x86_64)
    ARCHIVE="aether-windows-x86_64.zip"
    EXPECTED_SHA256="0cc32dd2d7573f91d2e55d4f427bfe4c6f6252342494e1b410d61b12d1e4dc79"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

DEST_ARCHIVE="$DIST_DIR/$ARCHIVE"
URL="https://github.com/CluvexStudio/Aether/releases/download/$TAG/$ARCHIVE"

if [ ! -f "$DEST_ARCHIVE" ]; then
  echo "Downloading $URL..."
  curl -sSL -o "$DEST_ARCHIVE" "$URL"
fi

ACTUAL_SHA256=$(sha256sum "$DEST_ARCHIVE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "SHA256 checksum mismatch for $ARCHIVE!" >&2
  echo "Expected: $EXPECTED_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi

echo "Verified SHA256 for $ARCHIVE: $ACTUAL_SHA256"

# Extract binary
TARGET_BIN_DIR="$DIST_DIR/$PLATFORM"
mkdir -p "$TARGET_BIN_DIR"
if [[ "$ARCHIVE" == *.tar.gz ]]; then
  tar -xzf "$DEST_ARCHIVE" -C "$TARGET_BIN_DIR"
elif [[ "$ARCHIVE" == *.zip ]]; then
  unzip -q -o "$DEST_ARCHIVE" -d "$TARGET_BIN_DIR"
fi

echo "Extracted $PLATFORM binary to $TARGET_BIN_DIR"
