# wpa_supplicant with WEXT Support for rtl8188eu

This directory contains the configuration and build scripts for compiling wpa_supplicant with WEXT (Wireless Extensions) driver support, which is required for the rtl8188eu USB WiFi adapter on rk-g350-v.

## Why This Is Needed

The rtl8188eu staging driver in kernel 4.4.189 only supports the deprecated Wireless Extensions (WEXT) API. Modern wpa_supplicant (2.11+) has removed WEXT support, causing WiFi authentication to fail.

## Prerequisites

You'll need a cross-compilation toolchain for ARM64/aarch64 that matches the muOS kernel version (4.4.189).

## Download wpa_supplicant Source

Since we can't include the source directly, download it yourself:

```bash
cd third-party/wpa_supplicant
wget https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
tar -xzf wpa_supplicant-2.10.tar.gz
```

Or use version 2.11 (latest stable):
```bash
wget https://w1.fi/releases/wpa_supplicant-2.11.tar.gz
tar -xzf wpa_supplicant-2.11.tar.gz
```

## Build Instructions

### Option 1: Quick Build (if you have the right toolchain)

```bash
./build.sh
```

### Option 2: Manual Build

1. **Extract and prepare**:
   ```bash
   cd wpa_supplicant-2.10/wpa_supplicant
   ```

2. **Copy configuration**:
   ```bash
   cp ../../wpa_supplicant.config .config
   ```

3. **Build** (native or cross-compile):
   ```bash
   # For cross-compilation (adjust your toolchain path):
   export CC=aarch64-linux-gnu-gcc
   export CFLAGS="-Os -static"
   export LDFLAGS="-static"

   make clean
   make
   ```

4. **Strip binary** (reduce size):
   ```bash
   aarch64-linux-gnu-strip wpa_supplicant
   ```

### Option 3: Build with Buildroot/muOS Build System

If muOS has a build system (Buildroot, Yocto, etc.), you can:

1. Add wpa_supplicant 2.10 package
2. Enable `CONFIG_DRIVER_WEXT=y` in package config
3. Build as part of the full system

## Installation

1. **Backup original**:
   ```bash
   # On device
   mv /usr/sbin/wpa_supplicant /usr/sbin/wpa_supplicant.bak
   ```

2. **Copy new binary**:
   ```bash
   # Copy to device (via USB, scp, or SD card mount)
   cp wpa_supplicant /usr/sbin/wpa_supplicant
   chmod +x /usr/sbin/wpa_supplicant
   ```

3. **Test**:
   ```bash
   wpa_supplicant -v
   # Should show "drivers: nl80211 wext" (note: wext is present)
   ```

## Verification

After installation, test WiFi connection:

1. Go to muOS Network settings
2. Scan for networks (should work - already working)
3. Connect to your WPA2 network
4. Should connect successfully!

## Alternative: Pre-built Binary

If cross-compilation is difficult, you can:

1. Build on the device itself (slow but works)
2. Use a pre-built wpa_supplicant binary from:
   - OpenWrt packages (aarch64)
   - Alpine Linux packages (aarch64)
   - Debian armhf/arm64 packages

Make sure any pre-built binary:
- Is for aarch64/ARM64 architecture
- Is statically linked or has compatible libraries
- Has WEXT driver support (`wpa_supplicant -v` should list "wext")

## Troubleshooting

**"wext driver not supported"**:
- Verify `.config` has `CONFIG_DRIVER_WEXT=y`
- Check `wpa_supplicant -v` output includes "wext"

**Binary won't run on device**:
- Check architecture: `file wpa_supplicant`
- May need static linking: `export LDFLAGS="-static"`
- Check library dependencies: `ldd wpa_supplicant`

**Still can't connect**:
- Check logs: `tail -f /opt/muos/log/*NETWORK*`
- Run connection test: Configuration → Tasks → Network Tasks → "WiFi Connection Test"

## Technical Notes

- **Version 2.10** recommended (proven stable with WEXT)
- **Version 2.11** also works if WEXT is enabled at compile time
- Configuration enables both nl80211 (modern) and wext (legacy) drivers
- This allows compatibility with both old and new WiFi adapters
- Binary size ~800KB (unstripped), ~400KB (stripped)

## See Also

- `RTL8188EU_STATUS.md` - Full documentation of the rtl8188eu issue
- `share/task/Network Tasks/WiFi Connection Test.sh` - Connection testing script
- https://w1.fi/wpa_supplicant/ - Official wpa_supplicant documentation
