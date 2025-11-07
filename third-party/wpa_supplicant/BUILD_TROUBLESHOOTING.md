# Build Troubleshooting for wpa_supplicant

## Common Build Errors and Solutions

### Error: "Package 'libssl-dev:arm64' has no installation candidate" (Pop!_OS)

**Problem**: Pop!_OS repositories don't host ARM64 packages because Pop!_OS only runs on x86_64 systems.

**Solution 1 - Use internal crypto (RECOMMENDED - easiest)**:

The simplest solution is to use wpa_supplicant's built-in crypto instead of OpenSSL:

```bash
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
CONFIG_FILE=wpa_supplicant-internal.config ./build.sh
```

This requires NO ARM64 system libraries - just the cross-compiler! The internal crypto is fully functional for WPA/WPA2 authentication.

**Solution 2 - Configure Ubuntu Ports repository for ARM64 packages**:

If you specifically need OpenSSL (not required for rtl8188eu):

```bash
# Run the provided fix script
./fix-arm64-repos.sh
```

Or manually:
```bash
# Create Ubuntu Ports source list for ARM64
sudo tee /etc/apt/sources.list.d/ubuntu-ports-arm64.list << 'EOF'
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse
EOF

# Update package lists
sudo apt-get update

# Now install ARM64 OpenSSL
sudo apt-get install libssl-dev:arm64
```

Note: Even after adding Ubuntu Ports, multi-arch OpenSSL installation can be problematic. Using internal crypto is more reliable.

### Error: "openssl/opensslconf.h: No such file or directory" (Cross-Compilation)

**Problem**: Cross-compiling but finding native OpenSSL headers instead of ARM64 headers.

This error occurs when you have the native (x86_64) OpenSSL development files installed, but not the ARM64 version. When cross-compiling, the build system needs the ARM64 headers, not the native ones.

**Solution** - Install ARM64 OpenSSL development package (REQUIRED for cross-compilation):

```bash
# Ubuntu/Debian - Add ARM64 architecture support
sudo dpkg --add-architecture arm64
sudo apt-get update

# Install ARM64 OpenSSL development files
sudo apt-get install libssl-dev:arm64

# Verify installation
ls -l /usr/include/aarch64-linux-gnu/openssl/ssl.h
```

After installing, the build script will automatically detect and use the correct ARM64 headers.

If you still have issues after installing, try cleaning your previous build:
```bash
cd wpa_supplicant-2.10/wpa_supplicant
make clean
cd ../..
export CROSS_COMPILE=aarch64-linux-gnu-
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh
```

### Error: "tommath.h: No such file or directory"

**Problem**: Configuration is set to use internal TLS which requires libtommath.

**Solution 1** - Use minimal config (recommended):
```bash
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh
```

**Solution 2** - Install libtommath:
```bash
# Ubuntu/Debian
sudo apt-get install libtommath-dev

# Fedora/RHEL
sudo dnf install libtommath-devel
```

### Error: "Package libnl-3.0 was not found"

**Problem**: Missing libnl library (netlink library for nl80211).

**Solution 1** - Use minimal config which disables libnl:
```bash
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh
```

**Solution 2** - Install libnl:
```bash
# Ubuntu/Debian
sudo apt-get install libnl-3-dev libnl-genl-3-dev

# Fedora/RHEL
sudo dnf install libnl3-devel
```

**Solution 3** - Edit config and comment out:
```
# CONFIG_LIBNL32=y
```

### Error: "Package dbus-1 was not found"

**Problem**: D-Bus integration is enabled but library not found.

**Solution**: The minimal config already has D-Bus disabled. If you modified it:

```bash
# In .config file, comment out:
# CONFIG_CTRL_IFACE_DBUS_NEW=y
# CONFIG_CTRL_IFACE_DBUS_INTRO=y
```

### Error: Cross-compiler not found

**Problem**: No ARM64 cross-compiler installed.

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install gcc-aarch64-linux-gnu

# Fedora/RHEL
sudo dnf install gcc-aarch64-linux-gnu

# Then set:
export CROSS_COMPILE=aarch64-linux-gnu-
```

### Error: "undefined reference to OpenSSL functions"

**Problem**: OpenSSL development files not installed.

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install libssl-dev

# Fedora/RHEL
sudo dnf install openssl-devel
```

## Recommended Build Approach

### For Minimal Dependencies

Use the minimal configuration which only requires OpenSSL:

```bash
# Install minimal dependencies
sudo apt-get install build-essential libssl-dev gcc-aarch64-linux-gnu

# Build
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh
```

### For Full Features

Install all dependencies and use the full configuration:

```bash
# Install all dependencies
sudo apt-get install build-essential pkg-config libnl-3-dev libnl-genl-3-dev \
                     libssl-dev libtommath-dev libdbus-1-dev gcc-aarch64-linux-gnu

# Build
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
./build.sh
```

## Testing the Build

After successful compilation:

```bash
cd wpa_supplicant-2.10/wpa_supplicant

# Check architecture
file wpa_supplicant
# Should show: ELF 64-bit LSB executable, ARM aarch64

# Check WEXT support
./wpa_supplicant -v | grep drivers:
# Should show: drivers: nl80211 wext
```

## Quick Native Build (for testing on x86_64)

If you just want to test the build works:

```bash
# Don't set CROSS_COMPILE
unset CROSS_COMPILE

# Build natively
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh

# Test
./wpa_supplicant-2.10/wpa_supplicant/wpa_supplicant -v
```

This won't run on your ARM device, but verifies the configuration is correct.
