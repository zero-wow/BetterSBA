#!/bin/bash
# Updates the version string in Constants.lua and BetterSBA.toc.
# Format: R<release>.<lines>.<git-hash>.<version>.<build>
#
# Usage:
#   .scripts/version.sh          # update lines, hash, build (auto fields)
#   .scripts/version.sh bump     # also increment the version/patch number
#
# Run from the BetterSBA addon root directory.

cd "$(dirname "$0")/.." || exit 1

# --- Auto fields ---
LINES=$(wc -l Core/*.lua GUI/*.lua BetterSBA.lua Bindings.xml 2>/dev/null | tail -1 | awk '{print $1}')
HASH=$(git log -1 --format=%h 2>/dev/null || echo "0000000")
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo "0")
BUILD=$((BUILD + 1))  # +1 because this runs before the new commit

# --- Manual fields (read from Constants.lua) ---
RELEASE=$(grep 'NS\.VERSION_RELEASE' Core/Constants.lua | head -1 | grep -oP '\d+')
PATCH=$(grep 'NS\.VERSION_PATCH' Core/Constants.lua | head -1 | grep -oP '\d+')
RELEASE=${RELEASE:-1}
PATCH=${PATCH:-1}

# Bump version/patch if requested
if [ "$1" = "bump" ]; then
    PATCH=$((PATCH + 1))
    sed -i "s/^NS\.VERSION_PATCH\s*=\s*[0-9]*/NS.VERSION_PATCH   = ${PATCH}/" Core/Constants.lua
    echo "Version patch bumped to: ${PATCH}"
fi

# Zero-pad version to 4 digits
PATCH_PAD=$(printf "%04d" "$PATCH")

VERSION="R${RELEASE}.${LINES}.${HASH}.${PATCH_PAD}.${BUILD}"

# Update Constants.lua
sed -i "s/^NS\.VERSION = \"R[^\"]*\"/NS.VERSION = \"${VERSION}\"/" Core/Constants.lua

# Update TOC
sed -i "s/^## Version: .*/## Version: ${VERSION}/" BetterSBA.toc

echo ""
echo "Version: ${VERSION}"
echo "  Release: ${RELEASE}"
echo "  Lines:   ${LINES}"
echo "  Hash:    ${HASH} (previous commit)"
echo "  Version: ${PATCH_PAD}"
echo "  Build:   ${BUILD}"
