#!/bin/bash

echo "🚀 Initializing FeLangKit Dev Container..."

# Ensure proper permissions for temporary directories
mkdir -p /tmp
chmod 1777 /tmp

# Set up working directory
cd /workspaces/FeLangKit

# Clean any existing build state that might cause conflicts
echo "Cleaning existing build state..."
rm -rf .build/.build-operations 2>/dev/null || true
rm -rf .build/checkouts 2>/dev/null || true

# Test Swift toolchain
echo "Testing Swift toolchain..."
swift --version

# Test package manifest parsing
echo "Testing package manifest..."
if swift package dump-package > /dev/null 2>&1; then
    echo "✅ Package manifest is valid"
else
    echo "❌ Package manifest parsing failed"
    exit 1
fi

echo "✅ Dev container initialization complete!"
echo ""
echo "You can now run:"
echo "  swift package resolve"
echo "  swift build"
echo "  swift test"
echo ""
echo "Or use the setup script:"
echo "  .devcontainer/setup.sh"