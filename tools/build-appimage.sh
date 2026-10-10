#!/usr/bin/env bash
# Build the Zohal Connect Linux AppImage (x86_64) on a CI runner.
# Assumes (done by earlier workflow steps):
#   app/build/linux/x64/release/bundle/   (flutter build linux --release)
#   engine/target/release/zohald          (cargo build --release -p zohald)
#   third_party/dist/linux-x86_64/aether  (tools/fetch-aether.sh linux-x86_64)
#   packaging/linux/zohal.png             (tools/gen-icon.py)
# Usage: bash tools/build-appimage.sh <version> [out-dir]
set -euo pipefail

VERSION="${1:?usage: build-appimage.sh <version> [out-dir]}"
OUT_DIR="${2:-dist/linux}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE="app/build/linux/x64/release/bundle"
[ -x "$BUNDLE/zohal" ] || { echo "Missing $BUNDLE/zohal; run flutter build first" >&2; exit 1; }
[ -x "engine/target/release/zohald" ] || { echo "Missing engine/target/release/zohald" >&2; exit 1; }
[ -x "third_party/dist/linux-x86_64/aether" ] || { echo "Missing Aether binary" >&2; exit 1; }
[ -f "packaging/linux/zohal.png" ] || python3 tools/gen-icon.py 256 packaging/linux/zohal.png

APPDIR="$(mktemp -d)/Zohal.AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications"

# Flutter bundle layout is kept intact (binary, lib/, data/ as siblings).
cp "$BUNDLE/zohal" "$APPDIR/usr/bin/"
cp -r "$BUNDLE/lib" "$APPDIR/usr/bin/lib"
cp -r "$BUNDLE/data" "$APPDIR/usr/bin/data"
# Privileged helper + tunnel core next to the UI so the Dart bridge finds
# them ($exeDir/zohald, $exeDir/aether) and auto-spawns the user scope.
cp "engine/target/release/zohald" "$APPDIR/usr/bin/zohald"
cp "third_party/dist/linux-x86_64/aether" "$APPDIR/usr/bin/aether"
chmod +x "$APPDIR/usr/bin/zohal" "$APPDIR/usr/bin/zohald" "$APPDIR/usr/bin/aether"

# Desktop entry + icon (Exec is rewritten to the AppImage-relative binary).
sed 's|^Exec=.*|Exec=zohal|; s|^Icon=.*|Icon=zohal|' \
  packaging/linux/zohal.desktop > "$APPDIR/usr/share/applications/zohal.desktop"
cp packaging/linux/zohal.png "$APPDIR/zohal.png"
cp packaging/linux/zohal.png "$APPDIR/.DirIcon"
ln -sf usr/share/applications/zohal.desktop "$APPDIR/zohal.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
export ZOHAL_APPDIR="$HERE"
export PATH="$HERE/usr/bin:$PATH"
exec "$HERE/usr/bin/zohal" "$@"
EOF
chmod +x "$APPDIR/AppRun"

mkdir -p "$OUT_DIR"
APPIMAGE="$OUT_DIR/Zohal-${VERSION}-x86_64.AppImage"
if [ -z "${APPIMAGETOOL:-}" ]; then
  curl -sSL -o /tmp/appimagetool.AppImage \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x /tmp/appimagetool.AppImage
  APPIMAGETOOL=/tmp/appimagetool.AppImage
fi
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$APPIMAGE"
chmod +x "$APPIMAGE"
echo "Built $APPIMAGE"
ls -la "$APPIMAGE"
