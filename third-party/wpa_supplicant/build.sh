#!/bin/bash
# Build script for wpa_supplicant with WEXT support

set -e

# Configuration
WPA_VERSION="2.10"
WPA_DIR="wpa_supplicant-${WPA_VERSION}"
BUILD_DIR="${WPA_DIR}/wpa_supplicant"
CONFIG_FILE="${CONFIG_FILE:-wpa_supplicant.config}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== wpa_supplicant Build Script ===${NC}"
echo "Version: ${WPA_VERSION}"
echo "Config: ${CONFIG_FILE}"
echo

# Check if source exists
if [ ! -d "$WPA_DIR" ]; then
    echo -e "${RED}Error: wpa_supplicant source not found!${NC}"
    echo
    echo "Please download wpa_supplicant source first:"
    echo "  wget https://w1.fi/releases/wpa_supplicant-${WPA_VERSION}.tar.gz"
    echo "  tar -xzf wpa_supplicant-${WPA_VERSION}.tar.gz"
    echo
    exit 1
fi

# Check for cross-compiler
if [ -n "$CROSS_COMPILE" ]; then
    echo -e "${YELLOW}Cross-compiling for ARM64/aarch64${NC}"
    export CC="${CROSS_COMPILE}gcc"
    export STRIP="${CROSS_COMPILE}strip"
    export PKG_CONFIG="${CROSS_COMPILE}pkg-config"

    # Point to ARM64 libraries
    ARCH_TRIPLET="aarch64-linux-gnu"
    export PKG_CONFIG_PATH="/usr/lib/${ARCH_TRIPLET}/pkgconfig:/usr/share/pkgconfig"
    export PKG_CONFIG_LIBDIR="/usr/lib/${ARCH_TRIPLET}/pkgconfig"

    # Set include and library paths for cross-compilation
    export CFLAGS="${CFLAGS} -I/usr/include/${ARCH_TRIPLET}"
    export LDFLAGS="${LDFLAGS} -L/usr/lib/${ARCH_TRIPLET}"

    echo "CC=${CC}"
    echo "PKG_CONFIG_PATH=${PKG_CONFIG_PATH}"
else
    echo -e "${YELLOW}Native compilation (may not work on rk-g350-v)${NC}"
    export CC="${CC:-gcc}"
    export STRIP="${STRIP:-strip}"
fi

# Set compilation flags for size optimization
export CFLAGS="${CFLAGS:-} -Os -ffunction-sections -fdata-sections"
export LDFLAGS="${LDFLAGS:-} -Wl,--gc-sections"

# Optionally build static binary (recommended for embedded systems)
if [ "$STATIC" = "1" ]; then
    echo -e "${YELLOW}Building static binary${NC}"
    export LDFLAGS="${LDFLAGS} -static"
fi

echo
echo -e "${GREEN}Step 1: Copying configuration${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file '$CONFIG_FILE' not found!${NC}"
    exit 1
fi
cp "$CONFIG_FILE" "${BUILD_DIR}/.config"

echo -e "${GREEN}Step 2: Cleaning previous build${NC}"
cd "$BUILD_DIR"
make clean || true

echo -e "${GREEN}Step 3: Compiling wpa_supplicant${NC}"
make -j$(nproc) || make

echo -e "${GREEN}Step 4: Stripping binary${NC}"
${STRIP} wpa_supplicant
${STRIP} wpa_cli

echo
echo -e "${GREEN}=== Build Complete ===${NC}"
echo
echo "Binary location: ${BUILD_DIR}/wpa_supplicant"
echo "Binary size: $(du -h wpa_supplicant | cut -f1)"
echo

echo -e "${YELLOW}Verifying build:${NC}"
file wpa_supplicant
echo

echo -e "${YELLOW}Supported drivers:${NC}"
./wpa_supplicant -v | grep "drivers:"
echo

if ./wpa_supplicant -v | grep -q "wext"; then
    echo -e "${GREEN}✓ WEXT driver support ENABLED${NC}"
else
    echo -e "${RED}✗ WEXT driver support NOT FOUND${NC}"
    exit 1
fi

echo
echo -e "${GREEN}Ready to install!${NC}"
echo
echo "To install on device:"
echo "  1. Copy to SD card MUOS partition:"
echo "     cp ${BUILD_DIR}/wpa_supplicant /path/to/sdcard/muos/usr/sbin/"
echo
echo "  2. Or copy directly if device is accessible:"
echo "     scp ${BUILD_DIR}/wpa_supplicant root@device:/usr/sbin/"
echo
echo "  3. On device, backup original and install:"
echo "     mv /usr/sbin/wpa_supplicant /usr/sbin/wpa_supplicant.bak"
echo "     cp /path/to/new/wpa_supplicant /usr/sbin/"
echo "     chmod +x /usr/sbin/wpa_supplicant"
echo
