#!/bin/bash

echo "🚀 FeLangKit Development Environment Setup"
echo "=========================================="

echo ""
echo "📍 Current Swift version:"
swift --version

echo ""
echo "📦 Resolving Swift package dependencies..."
if swift package resolve; then
    echo "✅ Dependencies resolved successfully!"
else
    echo "❌ Failed to resolve dependencies. This might be due to:"
    echo "   - Network connectivity issues"
    echo "   - Swift version compatibility" 
    echo "   - Container filesystem issues"
    echo ""
    echo "💡 Try running these commands manually:"
    echo "   swift package clean"
    echo "   swift package resolve"
    echo "   swift build"
fi

echo ""
echo "🔨 Building FeLangKit..."
if swift build; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed. Check the error messages above."
fi

echo ""
echo "🧪 Running tests..."
if swift test; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed. Check the output above."
fi

echo ""
echo "🎉 Setup complete! Available commands:"
echo "   swift build          - Build the project"
echo "   swift test           - Run tests"
echo "   swift package clean  - Clean build artifacts"
echo "   swift package resolve - Resolve dependencies"
echo ""
echo "📝 To install SwiftLint:"
echo "   git clone https://github.com/realm/SwiftLint.git"
echo "   cd SwiftLint && git checkout 0.57.0" 
echo "   swift build -c release"
echo "   cp .build/release/swiftlint /usr/local/bin/"