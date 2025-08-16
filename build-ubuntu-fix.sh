#!/bin/bash

# Build Script for Ubuntu 24.10 Compatibility Fixes
# This script builds Zulip Desktop with the implemented fixes

set -e

echo "🚀 Building Zulip Desktop with Ubuntu 24.10 compatibility fixes..."

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the zulip-desktop directory"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Error: Node.js 18+ is required (found version $NODE_VERSION)"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is not installed"
    exit 1
fi

echo "✅ npm version: $(npm --version)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf node_modules
rm -rf dist
rm -rf dist-electron

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Check for critical dependencies
echo "🔍 Verifying critical dependencies..."
if [ ! -d "node_modules/@electron/remote" ]; then
    echo "❌ Error: @electron/remote not found"
    exit 1
fi

if [ ! -d "node_modules/electron" ]; then
    echo "❌ Error: electron not found"
    exit 1
fi

echo "✅ Dependencies verified"

# TypeScript compilation check
echo "🔧 Checking TypeScript compilation..."
npm run watch-ts &
TS_PID=$!

# Wait a bit for compilation
sleep 5

# Check if compilation is successful
if ! kill -0 $TS_PID 2>/dev/null; then
    echo "❌ TypeScript compilation failed"
    exit 1
fi

# Stop TypeScript compilation
kill $TS_PID 2>/dev/null || true

echo "✅ TypeScript compilation successful"

# Build the application
echo "🏗️ Building application..."
npm run dist

# Check if build was successful
if [ ! -d "dist" ]; then
    echo "❌ Build failed - dist directory not found"
    exit 1
fi

echo "✅ Build completed successfully"

# Check for built files
if [ ! -f "dist/linux-unpacked/zulip" ]; then
    echo "❌ Build failed - zulip executable not found"
    exit 1
fi

echo "✅ Executable found: dist/linux-unpacked/zulip"

# Create Snap package if snapcraft is available
if command -v snapcraft &> /dev/null; then
    echo "📦 Creating Snap package..."
    cd snap
    snapcraft build --output ../zulip-ubuntu-fix.snap
    cd ..
    
    if [ -f "zulip-ubuntu-fix.snap" ]; then
        echo "✅ Snap package created: zulip-ubuntu-fix.snap"
        echo "📏 Package size: $(du -h zulip-ubuntu-fix.snap | cut -f1)"
    else
        echo "⚠️ Snap package creation failed"
    fi
else
    echo "ℹ️ snapcraft not found - skipping Snap package creation"
fi

# Create AppImage if appimagetool is available
if command -v appimagetool &> /dev/null; then
    echo "📦 Creating AppImage..."
    cp -r dist/linux-unpacked zulip.AppDir
    cp resources/zulip.png zulip.AppDir/
    
    # Create .desktop file
    cat > zulip.AppDir/zulip.desktop << EOF
[Desktop Entry]
Name=Zulip
Comment=Zulip Desktop Client
Exec=zulip
Icon=zulip
Type=Application
Categories=Network;InstantMessaging;
EOF

    appimagetool zulip.AppDir zulip-ubuntu-fix.AppImage
    rm -rf zulip.AppDir
    
    if [ -f "zulip-ubuntu-fix.AppImage" ]; then
        echo "✅ AppImage created: zulip-ubuntu-fix.AppImage"
        echo "📏 Package size: $(du -h zulip-ubuntu-fix.AppImage | cut -f1)"
    else
        echo "⚠️ AppImage creation failed"
    fi
else
    echo "ℹ️ appimagetool not found - skipping AppImage creation"
fi

# Create .deb package if dpkg-deb is available
if command -v dpkg-deb &> /dev/null; then
    echo "📦 Creating .deb package..."
    
    # Create package structure
    mkdir -p zulip-deb/DEBIAN
    mkdir -p zulip-deb/usr/bin
    mkdir -p zulip-deb/usr/share/applications
    mkdir -p zulip-deb/usr/share/icons/hicolor/256x256/apps
    
    # Copy executable
    cp dist/linux-unpacked/zulip zulip-deb/usr/bin/
    chmod +x zulip-deb/usr/bin/zulip
    
    # Copy icon
    cp resources/zulip.png zulip-deb/usr/share/icons/hicolor/256x256/apps/
    
    # Create .desktop file
    cat > zulip-deb/usr/share/applications/zulip.desktop << EOF
[Desktop Entry]
Name=Zulip
Comment=Zulip Desktop Client
Exec=zulip
Icon=zulip
Type=Application
Categories=Network;InstantMessaging;
EOF

    # Create control file
    cat > zulip-deb/DEBIAN/control << EOF
Package: zulip-desktop
Version: 5.11.1+ubuntu-fixes
Architecture: amd64
Maintainer: Zulip Team <support@zulip.com>
Depends: libgtk-3-0, libwebkit2gtk-4.0-37
Description: Zulip Desktop Client with Ubuntu 24.10 compatibility fixes
 Zulip combines the immediacy of Slack with an email threading model.
 This version includes fixes for Ubuntu 24.10 compatibility issues.
EOF

    # Build .deb package
    dpkg-deb --build zulip-deb zulip-ubuntu-fix.deb
    rm -rf zulip-deb
    
    if [ -f "zulip-ubuntu-fix.deb" ]; then
        echo "✅ .deb package created: zulip-ubuntu-fix.deb"
        echo "📏 Package size: $(du -h zulip-ubuntu-fix.deb | cut -f1)"
    else
        echo "⚠️ .deb package creation failed"
    fi
else
    echo "ℹ️ dpkg-deb not found - skipping .deb package creation"
fi

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "📁 Build artifacts:"
ls -la *.snap *.AppImage *.deb 2>/dev/null || echo "No packages created"
echo ""
echo "🚀 To test the fixes:"
echo "1. Install the created package"
echo "2. Launch Zulip Desktop"
echo "3. Try adding a new organization"
echo "4. Type in the Organization URL field"
echo "5. Verify no crashes occur"
echo ""
echo "📖 For more information, see: UBUNTU_24_10_FIXES.md"
