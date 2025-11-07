# Build Troubleshooting for wpa_supplicant

## Common Build Errors and Solutions

### Error: "openssl/opensslconf.h: No such file or directory" (Cross-Compilation)

**Problem**: Cross-compiling but finding native OpenSSL headers instead of ARM64 headers.

**Solution 1** - Install ARM64 OpenSSL development package:
```bash
# Ubuntu/Debian
sudo apt-get install libssl-dev:arm64

# Or more specifically:
sudo dpkg --add-architecture arm64
sudo apt-get update
sudo apt-get install libssl-dev:arm64
```

**Solution 2** - Use the fixed build script (automatically sets correct paths):
```bash
# The build.sh now handles this automatically
export CROSS_COMPILE=aarch64-linux-gnu-
CONFIG_FILE=wpa_supplicant-minimal.config ./build.sh
```

**Solution 3** - Manual path fix:
```bash
export CROSS_COMPILE=aarch64-linux-gnu-
export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
export CFLAGS="-I/usr/include/aarch64-linux-gnu"
export LDFLAGS="-L/usr/lib/aarch64-linux-gnu"
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
