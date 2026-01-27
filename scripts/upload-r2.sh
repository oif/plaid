#!/bin/bash
set -e

# Upload release to Cloudflare R2
# Usage: ./scripts/upload-r2.sh <version>
# Requires: AWS CLI configured with R2 credentials

APP_NAME="Plaid"
RELEASES_DIR="releases"
R2_BUCKET="${R2_BUCKET:-plaid-updates}"
R2_ENDPOINT="${R2_ENDPOINT:-https://\${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

VERSION=${1:-}
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

DMG_FILE="$RELEASES_DIR/$APP_NAME-$VERSION.dmg"
APPCAST_ITEM="$RELEASES_DIR/appcast_item_$VERSION.xml"

# Check files exist
[ -f "$DMG_FILE" ] || error "DMG not found: $DMG_FILE"
[ -f "$APPCAST_ITEM" ] || error "Appcast item not found: $APPCAST_ITEM"

# Check R2 credentials
if [ -z "$R2_ACCOUNT_ID" ]; then
    error "R2_ACCOUNT_ID not set. Export it first."
fi

R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

log "Uploading $APP_NAME v$VERSION to R2..."

# Upload DMG
log "Uploading DMG..."
aws s3 cp "$DMG_FILE" "s3://${R2_BUCKET}/releases/$APP_NAME-$VERSION.dmg" \
    --endpoint-url "$R2_ENDPOINT"

# Download or create appcast.xml
log "Updating appcast.xml..."
APPCAST_FILE="$RELEASES_DIR/appcast.xml"

aws s3 cp "s3://${R2_BUCKET}/appcast.xml" "$APPCAST_FILE" \
    --endpoint-url "$R2_ENDPOINT" 2>/dev/null || cat > "$APPCAST_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Plaid Updates</title>
    <link>https://dl.plaid.oo.sb/appcast.xml</link>
    <description>Plaid app updates</description>
    <language>en</language>
  </channel>
</rss>
EOF

# Check if this version already exists
if grep -q "shortVersionString>$VERSION<" "$APPCAST_FILE"; then
    warn "Version $VERSION already exists in appcast. Skipping appcast update."
else
    # Insert new item before </channel>
    ITEM_CONTENT=$(cat "$APPCAST_ITEM")
    # Use perl for reliable multiline insertion
    perl -i -pe "s|</channel>|$ITEM_CONTENT\n  </channel>|" "$APPCAST_FILE"
fi

# Upload updated appcast
log "Uploading appcast.xml..."
aws s3 cp "$APPCAST_FILE" "s3://${R2_BUCKET}/appcast.xml" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type "application/xml"

log "Upload complete!"
echo ""
echo "  DMG: https://dl.plaid.oo.sb/releases/$APP_NAME-$VERSION.dmg"
echo "  Appcast: https://dl.plaid.oo.sb/appcast.xml"
