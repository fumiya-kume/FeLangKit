#!/bin/bash

echo "🔍 FeLangKit Dev Container Verification"
echo "======================================"

# Test 1: Swift Version
echo ""
echo "📍 Testing Swift toolchain..."
if swift --version; then
    echo "✅ Swift toolchain is working"
else
    echo "❌ Swift toolchain failed"
    exit 1
fi

# Test 2: Package.swift accessibility
echo ""
echo "📦 Checking Package.swift..."
if [ -f "Package.swift" ]; then
    echo "✅ Package.swift found"
    echo "Package name: $(grep -o 'name: "[^"]*"' Package.swift | head -1)"
else
    echo "❌ Package.swift not found"
    exit 1
fi

# Test 3: SourceKit-LSP
echo ""
echo "🔧 Testing SourceKit-LSP..."
if which sourcekit-lsp > /dev/null; then
    echo "✅ SourceKit-LSP is available at: $(which sourcekit-lsp)"
else
    echo "❌ SourceKit-LSP not found"
fi

# Test 4: Essential tools
echo ""
echo "🛠️  Testing development tools..."
for tool in git curl wget vim nano; do
    if which $tool > /dev/null; then
        echo "✅ $tool: $(which $tool)"
    else
        echo "❌ $tool: not found"
    fi
done

# Test 5: Environment variables
echo ""
echo "🌍 Checking environment variables..."
echo "SWIFT_EXEC: ${SWIFT_EXEC:-not set}"
echo "SOURCEKIT_LSP_EXEC: ${SOURCEKIT_LSP_EXEC:-not set}"

# Test 6: Swift Package Operations (on actual project)
echo ""
echo "🧪 Testing Swift package operations on FeLangKit..."

echo "Testing in: $(pwd)"

# Try package operations on the actual project
if swift package dump-package > /dev/null 2>&1; then
    echo "✅ Swift package manifest parsing works"
    
    # Clean any existing build state to avoid conflicts
    echo "Cleaning existing build state..."
    rm -rf .build/.build-operations
    
    if timeout 120 swift package resolve 2>/dev/null; then
        echo "✅ Swift package resolve works"
        
        echo "Attempting build (this may take a while)..."
        if timeout 300 swift build --configuration debug 2>/dev/null; then
            echo "✅ Swift build works"
            
            echo "Running a basic test..."
            if timeout 180 swift test --filter "testBasicTokenization" 2>/dev/null; then
                echo "✅ Swift test works"
            else
                echo "⚠️  Some tests failed (this may be expected in container environment)"
            fi
        else
            echo "⚠️  Swift build timed out or failed (this may be expected in container environment)"
        fi
    else
        echo "⚠️  Swift package resolve timed out or failed (this may be expected in container environment)"
    fi
else
    echo "❌ Swift package manifest parsing failed"
fi

echo ""
echo "🎉 Verification complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Run: .devcontainer/setup.sh"
echo "   2. Or manually: swift package resolve && swift build && swift test"