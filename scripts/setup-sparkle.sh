#!/bin/bash
set -e

# Setup Sparkle signing keys
# Run this once to generate EdDSA keys for Sparkle updates

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "Setting up Sparkle signing keys..."
echo ""

# Find Sparkle bin
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -name "bin" -type d -path "*sparkle*" 2>/dev/null | head -1)

if [ -z "$SPARKLE_BIN" ]; then
    echo "Sparkle not found in DerivedData."
    echo "Building project to download Sparkle..."
    xcodebuild -resolvePackageDependencies -scheme Plaid -quiet
    SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -name "bin" -type d -path "*sparkle*" 2>/dev/null | head -1)
fi

if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Could not find Sparkle. Please build the project in Xcode first."
    exit 1
fi

log "Found Sparkle at: $SPARKLE_BIN"

# Generate keys
echo ""
echo "Generating EdDSA key pair..."
echo "(The private key will be stored in your Keychain)"
echo ""

"$SPARKLE_BIN/generate_keys"

echo ""
echo "============================================"
echo ""
log "Keys generated successfully!"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Copy the SUPublicEDKey value above"
echo "2. Replace REPLACE_WITH_YOUR_PUBLIC_KEY in Plaid/Info.plist"
echo "3. For CI/CD, export the private key:"
echo ""
echo "   $SPARKLE_BIN/generate_keys -x sparkle_private_key.pem"
echo ""
echo "   Then add it as SPARKLE_PRIVATE_KEY secret in GitHub"
echo ""
echo "4. KEEP YOUR PRIVATE KEY SAFE!"
echo "   - Don't commit it to git"
echo "   - Back it up securely"
echo "   - If lost, users can't verify updates"
