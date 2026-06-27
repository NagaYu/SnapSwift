#!/usr/bin/env bash
#
# build.sh — Build SnapSwift and package the desktop app as a .app bundle (and optional .dmg).
#
# Usage:
#   ./build.sh            # build .app into ./dist
#   ./build.sh --dmg      # build .app and wrap it in a .dmg
#   ./build.sh --clean    # remove build artifacts first
#
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
APP_NAME="SnapSwift"
EXECUTABLE="SnapSwiftApp"
BUNDLE_ID="com.snapswift.app"
VERSION="0.1.1"
MIN_MACOS="26.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

MAKE_DMG=false
CLEAN=false
for arg in "$@"; do
  case "$arg" in
    --dmg) MAKE_DMG=true ;;
    --clean) CLEAN=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────────
# FoundationModels' Swift macros live in the full Xcode toolchain, not in the
# Command Line Tools. Point the build at Xcode if it isn't already selected.
# ──────────────────────────────────────────────────────────────────────────────
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  if [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    echo "→ Using Xcode toolchain at $DEVELOPER_DIR"
  else
    echo "⚠️  Xcode.app not found. FoundationModels macros require the full Xcode."
    echo "    Install Xcode 26+ and run: sudo xcode-select -s /Applications/Xcode.app"
    exit 1
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Clean
# ──────────────────────────────────────────────────────────────────────────────
if $CLEAN; then
  echo "→ Cleaning…"
  rm -rf "$SCRIPT_DIR/.build" "$DIST_DIR"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Build (release)
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Building $EXECUTABLE (release)…"
swift build -c release --product "$EXECUTABLE"
BIN_PATH="$(swift build -c release --product "$EXECUTABLE" --show-bin-path)/$EXECUTABLE"

if [ ! -f "$BIN_PATH" ]; then
  echo "✗ Build did not produce a binary at $BIN_PATH"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Assemble the .app bundle
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Assembling $APP_NAME.app…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Optional app icon: drop an AppIcon.icns into Resources/ to have it picked up.
ICON_KEY=""
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
  cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    $ICON_KEY
</dict>
</plist>
PLIST

echo "→ Bundle PkgInfo…"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# ──────────────────────────────────────────────────────────────────────────────
# Ad-hoc code signing (lets it launch locally without a Developer ID).
# For public distribution, sign with a Developer ID and notarize — see README.
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Ad-hoc signing…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || \
  echo "  (codesign skipped/failed — app will still run after right-click → Open)"

echo "✓ Built: $APP_BUNDLE"

# ──────────────────────────────────────────────────────────────────────────────
# Optional .dmg
# ──────────────────────────────────────────────────────────────────────────────
if $MAKE_DMG; then
  echo "→ Creating .dmg…"
  DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
  STAGING="$DIST_DIR/dmg-staging"
  rm -rf "$STAGING" "$DMG_PATH"
  mkdir -p "$STAGING"
  cp -R "$APP_BUNDLE" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"
  rm -rf "$STAGING"
  echo "✓ Built: $DMG_PATH"
fi

echo ""
echo "Done. Try it:"
echo "  open \"$APP_BUNDLE\""
