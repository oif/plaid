#!/bin/bash
set -e

# Plaid Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0

APP_NAME="Plaid"
SCHEME="Plaid"
BUILD_DIR="build"
RELEASES_DIR="releases"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check version argument
VERSION=${1:-}
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

log "Building $APP_NAME v$VERSION"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RELEASES_DIR"

# Update version in Info.plist
log "Updating version to $VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Plaid/Info.plist
BUILD_NUMBER=$(date +%Y%m%d%H%M)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Plaid/Info.plist

# Build
log "Building Release archive..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -quiet

# Export
log "Exporting app..."
mkdir -p "$BUILD_DIR/export"
cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$BUILD_DIR/export/"

# Create DMG
log "Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$RELEASES_DIR/$DMG_NAME" \
        "$BUILD_DIR/export/" 2>/dev/null || true
fi

# Fallback to hdiutil
if [ ! -f "$RELEASES_DIR/$DMG_NAME" ]; then
    hdiutil create -volname "$APP_NAME" -srcfolder "$BUILD_DIR/export" -ov -format UDZO \
        "$RELEASES_DIR/$DMG_NAME"
fi

# Find Sparkle bin
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -name "bin" -type d -path "*sparkle*" 2>/dev/null | head -1)
if [ -z "$SPARKLE_BIN" ]; then
    warn "Sparkle bin not found. Run 'xcodebuild -resolvePackageDependencies' first."
    warn "Skipping Sparkle signing."
else
    # Sign with Sparkle
    log "Signing with Sparkle EdDSA..."
    SIGNATURE=$("$SPARKLE_BIN/sign_update" "$RELEASES_DIR/$DMG_NAME" 2>/dev/null || echo "")
    
    if [ -n "$SIGNATURE" ]; then
        log "Signature: $SIGNATURE"
        
        # Generate appcast item
        DMG_SIZE=$(stat -f%z "$RELEASES_DIR/$DMG_NAME")
        DATE=$(date -R)
        
        cat > "$RELEASES_DIR/appcast_item_$VERSION.xml" << EOF
    <item>
      <title>Version $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://dl.plaid.oo.sb/releases/$DMG_NAME"
        $SIGNATURE
        length="$DMG_SIZE"
        type="application/octet-stream" />
      <sparkle:releaseNotesLink>https://github.com/user/plaid/releases/tag/v$VERSION</sparkle:releaseNotesLink>
    </item>
EOF
        log "Appcast item saved to $RELEASES_DIR/appcast_item_$VERSION.xml"
    else
        warn "No Sparkle private key found. Run 'generate_keys' first."
    fi
fi

# Summary
echo ""
log "Release build complete!"
echo ""
echo "  DMG: $RELEASES_DIR/$DMG_NAME"
echo "  Size: $(du -h "$RELEASES_DIR/$DMG_NAME" | cut -f1)"
echo ""
echo "Next steps:"
echo "  1. Test the DMG locally"
echo "  2. Upload to R2: ./scripts/upload-r2.sh $VERSION"
echo "  3. Or push a tag: git tag v$VERSION && git push origin v$VERSION"
