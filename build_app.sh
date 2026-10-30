#!/bin/bash
#
# Compila Caffeine.app y genera los artefactos de distribución:
#   dist/Caffeine-<version>.dmg
#   dist/Caffeine-<version>.zip
#
# Uso:
#   ./build_app.sh
#   VERSION=1.0.1 ./build_app.sh
#   SIGN_IDENTITY="Developer ID Application: ..." NOTARY_PROFILE="perfil" ./build_app.sh

set -euo pipefail

APP_NAME="Caffeine"
SWIFT_FILE="Caffeine.swift"
BUNDLE_ID="${BUNDLE_ID:-com.local.caffeine}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_MACOS="${MIN_MACOS:-11.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ARCHS="${ARCHS:-arm64 x86_64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_BUNDLE="$APP_NAME.app"
DIST_DIR="dist"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/caffeine-build.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "Error: $*" >&2
    exit 1
}

[ -f "$SWIFT_FILE" ] || fail "no encuentro $SWIFT_FILE en $SCRIPT_DIR"

echo "-> Compilando $APP_NAME $VERSION para macOS $MIN_MACOS+..."

slices=()
for arch in $ARCHS; do
    out="$WORK_DIR/$arch"
    log="$WORK_DIR/$arch.log"
    if (cd "$WORK_DIR" && swiftc \
            -target "${arch}-apple-macos${MIN_MACOS}" \
            -O \
            "$SCRIPT_DIR/$SWIFT_FILE" \
            -o "$out" \
            -framework Cocoa -framework IOKit -framework Carbon) >"$log" 2>&1; then
        slices+=("$out")
        echo "   ok  $arch"
    else
        echo "   --  $arch no disponible con este toolchain"
    fi
done

if [ ${#slices[@]} -eq 0 ]; then
    cat "$WORK_DIR"/*.log >&2
    fail "no se pudo compilar ninguna arquitectura"
fi

if [ ${#slices[@]} -lt 2 ]; then
    echo ""
    echo "   Aviso: el binario es de una sola arquitectura."
    echo "   Para un binario universal (Apple Silicon + Intel) hace falta el"
    echo "   toolchain completo de Xcode; Command Line Tools no incluye las"
    echo "   librerías de compatibilidad cruzada. Detalle:"
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo ""
fi

echo "-> Armando $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

lipo -create "${slices[@]}" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "-> Generando Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "-> Firmando..."
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    codesign --force --sign - "$APP_BUNDLE"
fi
codesign --verify --strict "$APP_BUNDLE"

if [ -n "$NOTARY_PROFILE" ]; then
    [ -n "$SIGN_IDENTITY" ] || fail "NOTARY_PROFILE requiere también SIGN_IDENTITY"
    echo "-> Notarizando la app (puede tardar varios minutos)..."
    ditto -c -k --keepParent --norsrc --noextattr "$APP_BUNDLE" "$WORK_DIR/notarize-app.zip"
    xcrun notarytool submit "$WORK_DIR/notarize-app.zip" \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
elif [ -z "$SIGN_IDENTITY" ]; then
    echo "   (firma ad-hoc: Gatekeeper pedirá confirmación en otros Macs)"
fi

echo "-> Generando artefactos en $DIST_DIR/..."
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$ZIP_PATH" "$DMG_PATH"

ditto -c -k --keepParent --norsrc --noextattr "$APP_BUNDLE" "$ZIP_PATH"

STAGING="$WORK_DIR/dmg"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"

if [ -n "$NOTARY_PROFILE" ]; then
    echo "-> Notarizando el DMG..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "Listo."
echo "  app: $SCRIPT_DIR/$APP_BUNDLE"
echo "  dmg: $SCRIPT_DIR/$DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
echo "  zip: $SCRIPT_DIR/$ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"
echo ""
echo "Prueba local:  open \"$SCRIPT_DIR/$APP_BUNDLE\""
