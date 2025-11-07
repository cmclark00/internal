#!/bin/bash
# Simple native build script for wpa_supplicant (for testing on your PC)
# This builds a native x86_64 binary to verify the config works
# It won't run on the ARM device but helps debug build issues

set -e

WPA_VERSION="2.10"
WPA_DIR="wpa_supplicant-${WPA_VERSION}"
BUILD_DIR="${WPA_DIR}/wpa_supplicant"
CONFIG_FILE="${CONFIG_FILE:-wpa_supplicant-minimal.config}"

echo "=== Native wpa_supplicant Build (x86_64) ==="
echo "This is for TESTING ONLY - won't run on ARM device"
echo "Config: ${CONFIG_FILE}"
echo

if [ ! -d "$WPA_DIR" ]; then
    echo "Error: wpa_supplicant source not found!"
    echo "Please download it first:"
    echo "  wget https://w1.fi/releases/wpa_supplicant-${WPA_VERSION}.tar.gz"
    echo "  tar -xzf wpa_supplicant-${WPA_VERSION}.tar.gz"
    exit 1
fi

# Native compilation - much simpler!
unset CROSS_COMPILE
export CC=gcc
export CFLAGS="-Os"
export LDFLAGS=""

echo "Step 1: Copying configuration"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi
cp "$CONFIG_FILE" "${BUILD_DIR}/.config"

echo "Step 2: Building"
cd "$BUILD_DIR"
make clean || true
make -j$(nproc)

echo
echo "Build complete!"
echo "Binary: ${BUILD_DIR}/wpa_supplicant"
echo
file wpa_supplicant
echo
./wpa_supplicant -v
echo
echo "If you see 'wext' in the drivers list above, the config is correct!"
echo "Now you need to do a cross-compile build for ARM64 to run on the device."
