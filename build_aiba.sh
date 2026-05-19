#!/bin/bash
# build_aiba.sh - Automated build script for custom Aiba browser

set -euxo pipefail

# Configuration
REPO_URL="https://github.com/ungoogled-software/ungoogled-chromium.git"
REPO_DIR="ungoogled-chromium"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Aiba Browser Build Script"
echo "=========================================="
echo ""

# Step 1: Source Code Fetching
# Step 1: Source Code Fetching
echo "[1/9] Checking for ungoogled-chromium repository..."

# If we are in GitHub Actions (CI), always force a fresh start
if [ "$CI" = "true" ]; then
    echo "CI environment detected. Cleaning existing directory to ensure fresh build..."
    rm -rf "$REPO_DIR"
fi

if [ ! -d "$REPO_DIR" ]; then
    echo "Repository not found. Cloning from GitHub..."
    git clone "$REPO_URL"
    echo "Repository cloned successfully."
else
    echo "Repository already exists. Skipping clone."
fi

echo ""
echo "[2/9] Entering repository directory..."
cd "$REPO_DIR"

echo ""
echo "[3/9] Verifying repository structure..."

if [ ! -f "./getsrc.sh" ]; then
    echo "ERROR: getsrc.sh not found!"
    echo "Repository structure is invalid or outdated."
    ls -lah
    exit 1
fi

echo ""
echo "[4/9] Creating download cache directory..."
mkdir -p build/download_cache

echo ""
echo "[5/9] Downloading Chromium source code..."

chmod +x getsrc.sh
./getsrc.sh

echo ""
echo "[6/9] Running setup_aiba.py for branding..."

cd "$SCRIPT_DIR"

if [ -f "setup_aiba.py" ]; then
    python3 setup_aiba.py
else
    echo "setup_aiba.py not found. Skipping branding step."
fi

echo ""
echo "[7/9] Applying privacy patches..."

cd "$REPO_DIR"

if [ -f "utils/prune_binaries.py" ]; then
    python3 utils/prune_binaries.py
fi

if [ -f "utils/patches.py" ]; then
    python3 utils/patches.py apply build/src patches
fi

echo ""
echo "[8/9] Configuring build with GN..."

cd build/src

mkdir -p out/Default

cat > out/Default/args.gn << 'EOF'
# Optimized build settings for GitHub Actions

is_debug = false
is_official_build = true

symbol_level = 0
blink_symbol_level = 0

enable_nacl = false
enable_remoting = false

use_goma = false
is_component_build = false

concurrent_links = 1

use_sysroot = false
EOF

echo "Running gn gen..."
gn gen out/Default

echo ""
echo "[9/9] Starting compilation..."

CPU_COUNT=$(nproc)

echo "Using $CPU_COUNT CPU cores"

nice -n 19 ninja -C out/Default chrome -j"$CPU_COUNT"

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

if [ -f "out/Default/chrome" ]; then
    echo "Browser binary:"
    echo "  $REPO_DIR/build/src/out/Default/chrome"
else
    echo "Build finished but chrome binary not found."
    ls -lah out/Default
fi
