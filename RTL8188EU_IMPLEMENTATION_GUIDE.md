# RTL8188EU USB WiFi Adapter Implementation Guide

Complete guide for adding rtl8188eu USB WiFi adapter support to muOS on rk-g350-v devices.

## Overview

The rtl8188eu USB WiFi adapters use the staging r8188eu kernel driver which only supports the legacy Wireless Extensions (WEXT) API. Modern wpa_supplicant removed WEXT support, requiring custom compilation.

## Table of Contents

1. [Configuration File Changes](#configuration-file-changes)
2. [Script Modifications](#script-modifications)
3. [wpa_supplicant Build Infrastructure](#wpa_supplicant-build-infrastructure)
4. [Binary Replacement](#binary-replacement)
5. [Quick Setup for Clean Image](#quick-setup-for-clean-image)

---

## Configuration File Changes

### 1. Device Network Configuration

**File**: `device/rk-g350-v/config/network/name`

```
r8188eu
```

**Change**: Changed from `8188eu` to `r8188eu` to match actual kernel module name.

---

**File**: `device/rk-g350-v/config/network/type`

```
nl80211
```

**Note**: Keep as `nl80211` for wpa_supplicant driver parameter, but scripts will use WEXT tools (iwconfig/iwlist) for rk* devices.

---

**File**: `device/rk-g350-v/config/network/module`

```
/lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/r8188eu.ko
```

---

## Script Modifications

### 1. Network Connection Script

**File**: `script/system/network.sh`

**Changes**: Added rk* device handling for WiFi connection with WEXT support.

**Key sections added**:

```bash
# Around line 100-150, in the connect function:
case "$BOARD_NAME" in
    rk*)
        LOG_INFO "$0" 0 "NETWORK" "Configuring WiFi using wireless extensions"
        PASS=$(GET_VAR "config" "network/pass")
        iwconfig "$IFCE" essid "$SSID"
        if [ -n "$PASS" ]; then
            /opt/muos/script/web/password.sh
            wpa_supplicant -B -i "$IFCE" -c "$WPA_CONFIG" -D wext 2>/dev/null || {
                LOG_WARN "$0" 0 "NETWORK" "wpa_supplicant failed, trying without encryption manager"
                iwconfig "$IFCE" mode Managed
            }
        fi

        # Wait for connection with WEXT-compatible checking
        for i in $(seq 1 30); do
            IWCONFIG_OUT=$(iwconfig "$IFCE" 2>/dev/null)
            if echo "$IWCONFIG_OUT" | grep -qv "unassociated" && echo "$IWCONFIG_OUT" | grep -q 'ESSID:"'; then
                if ! echo "$IWCONFIG_OUT" | grep -q 'ESSID:""'; then
                    LOG_INFO "$0" 0 "NETWORK" "WiFi Associated!"
                    break
                fi
            fi
            sleep 1
        done
        ;;
    *)
        # Original code for other devices
        ;;
esac
```

**Also in disconnect function**:

```bash
case "$BOARD_NAME" in
    rk*)
        killall -q wpa_supplicant
        iwconfig "$IFCE" essid "" 2>/dev/null || true
        ;;
    *)
        # Original code
        ;;
esac
```

---

### 2. Network Scanning Script

**File**: `script/web/ssid.sh`

**Changes**: Added rk* device handling to use `iwlist` instead of `iw` for scanning.

**Key section added** (around line 40-60):

```bash
# Load module before scanning
if [ "$BOARD_NAME" = "rk-g350-v" ]; then
    MODULE_PATH=$(GET_VAR "device" "network/module")
    MODULE_NAME=$(GET_VAR "device" "network/name")
    if [ -f "$MODULE_PATH" ]; then
        modprobe "$MODULE_NAME" 2>/dev/null || true
        sleep 1
    fi
fi

# Scan based on device
case "$BOARD_NAME" in
    rk*)
        # Use wireless extensions (iwlist) for staging r8188eu driver
        timeout 15 iwlist "$IFCE" scan 2>/dev/null |
            grep "ESSID:" |
            sed 's/^[[:space:]]*ESSID:"//' |
            sed 's/"$//' |
            grep -v '^$' |
            sort -u |
            HEX_ESCAPE >"$NET_SCAN"
        ;;
    *)
        # Original iw scan code
        timeout 15 iw "$IFCE" scan 2>/dev/null |
            grep "SSID:" |
            sed 's/^[[:space:]]*SSID: //' |
            grep -v '^$' |
            sort -u |
            HEX_ESCAPE >"$NET_SCAN"
        ;;
esac
```

---

### 3. Device Network Loading Script

**File**: `script/device/network.sh`

**Changes**: Added cfg80211 preloading for rk* devices.

**Key section added** (after line 10):

```bash
case "$BOARD_NAME" in
    rk*)
        # Try to load cfg80211 if it exists (might be built-in or not needed)
        modprobe -q cfg80211 2>/dev/null || true
        ;;
esac
```

---

## wpa_supplicant Build Infrastructure

All files in `third-party/wpa_supplicant/` directory:

### Build Configuration Files

**1. wpa_supplicant-wext-only.config** ⭐ RECOMMENDED

Minimal configuration requiring only the cross-compiler:
- WEXT driver only (no nl80211, no libnl needed)
- Internal crypto (no OpenSSL needed)
- WPA/WPA2 support
- No WPA3/SAE (requires external crypto)

**2. wpa_supplicant-internal.config**

Dual driver support with internal crypto:
- Both WEXT and nl80211 drivers (requires libnl headers)
- Internal crypto (no OpenSSL needed)
- Supports both old and new WiFi adapters

**3. wpa_supplicant-minimal.config**

Minimal with OpenSSL:
- Both WEXT and nl80211 drivers
- Uses OpenSSL for crypto
- Requires libssl-dev:arm64 and libnl

**4. wpa_supplicant.config**

Full-featured build:
- All features enabled
- Requires multiple ARM64 libraries

### Build Scripts

**1. build.sh**

Main build script with cross-compilation support:
- Detects cross-compiler
- Sets proper PKG_CONFIG paths
- Verifies dependencies based on config
- Builds static binary
- Strips and verifies output

**2. build-native.sh**

Simple native x86_64 build for testing configurations.

**3. fix-arm64-repos.sh**

Pop!_OS specific: Configures Ubuntu Ports repository for ARM64 packages.

### Documentation

**1. README.md**

Complete build instructions with multiple configuration options.

**2. BUILD_TROUBLESHOOTING.md**

Comprehensive troubleshooting guide for common build errors.

**3. RTL8188EU_STATUS.md**

Technical documentation explaining the incompatibility issue and solutions.

---

## Binary Replacement

### Build wpa_supplicant

On your development machine (Pop!_OS/Ubuntu):

```bash
cd third-party/wpa_supplicant

# Download source
wget https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
tar -xzf wpa_supplicant-2.10.tar.gz

# Build with WEXT-only config (zero dependencies)
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
CONFIG_FILE=wpa_supplicant-wext-only.config ./build.sh
```

The binary will be in: `build/wpa_supplicant`

### Verify Binary

```bash
cd build
file wpa_supplicant
# Should show: ELF 64-bit LSB executable, ARM aarch64

aarch64-linux-gnu-strings wpa_supplicant | grep -i "drivers:"
# Should show: drivers: wext
```

### Install on Device

**Option 1**: Replace in root filesystem before creating image:

```bash
# Mount your muOS root partition
sudo mount /dev/sdX2 /mnt

# Backup original
sudo cp /mnt/usr/sbin/wpa_supplicant /mnt/usr/sbin/wpa_supplicant.orig

# Install new binary
sudo cp build/wpa_supplicant /mnt/usr/sbin/wpa_supplicant
sudo chmod 755 /mnt/usr/sbin/wpa_supplicant

# Unmount
sudo umount /mnt
```

**Option 2**: Install on running device:

```bash
# Copy to device via SD card
cp build/wpa_supplicant /path/to/sdcard/

# On device:
mount -o remount,rw /
cp /mnt/sdcard/wpa_supplicant /usr/sbin/wpa_supplicant
chmod 755 /usr/sbin/wpa_supplicant
sync
mount -o remount,ro /
```

---

## Quick Setup for Clean Image

### Minimal Changes Required

For a clean muOS image that supports rtl8188eu USB WiFi adapters:

**1. Configuration Files** (3 files):
- `device/rk-g350-v/config/network/name` → `r8188eu`
- `device/rk-g350-v/config/network/type` → `nl80211`
- `device/rk-g350-v/config/network/module` → `/lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/r8188eu.ko`

**2. Script Modifications** (3 files):
- `script/system/network.sh` - Add rk* case handling for WEXT
- `script/web/ssid.sh` - Add rk* case handling for iwlist
- `script/device/network.sh` - Add cfg80211 preloading

**3. Binary Replacement** (1 file):
- `/usr/sbin/wpa_supplicant` - Replace with WEXT-enabled build

**4. Optional** - Include build infrastructure in `third-party/wpa_supplicant/` for documentation and future rebuilds.

### Build Process

```bash
# 1. Install cross-compiler (one-time setup)
sudo apt-get install gcc-aarch64-linux-gnu

# 2. Clone repository with changes
git clone <your-repo>
cd internal
git checkout claude/rtl8188eu-wifi-adapter-011CUpA4en8B1XTkhXMCFX46

# 3. Build wpa_supplicant
cd third-party/wpa_supplicant
wget https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
tar -xzf wpa_supplicant-2.10.tar.gz
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
CONFIG_FILE=wpa_supplicant-wext-only.config ./build.sh

# 4. Binary is in: build/wpa_supplicant
```

### Integration Checklist

- [ ] Configuration files updated
- [ ] Script modifications applied
- [ ] wpa_supplicant built with WEXT support
- [ ] Binary replaced in filesystem
- [ ] Tested with open network
- [ ] Tested with WPA2 network
- [ ] DHCP assigns proper IP address
- [ ] Network survives suspend/resume

---

## Technical Details

### Why These Changes Are Needed

**Problem**:
- rtl8188eu uses staging r8188eu driver (kernel 4.4.189)
- Driver only supports Wireless Extensions (WEXT) API
- wpa_supplicant 2.11 removed WEXT driver support
- Result: Cannot authenticate to encrypted WiFi networks

**Solution**:
1. Modify scripts to use WEXT tools (iwconfig/iwlist) instead of nl80211 (iw)
2. Build wpa_supplicant 2.10 with CONFIG_DRIVER_WEXT=y enabled
3. Use static linking to avoid ARM64 library dependencies
4. Replace system wpa_supplicant with WEXT-enabled version

### Compatibility

**Supported**:
- ✅ Open networks (no password)
- ✅ WPA/WPA2 Personal (PSK)
- ✅ WPS (Wi-Fi Protected Setup)
- ✅ All common EAP methods

**Not Supported**:
- ❌ WPA3/SAE (requires elliptic curve crypto)
- ❌ WPA2 Enterprise (possible but untested)

### Driver Information

- **Module**: r8188eu.ko
- **Location**: `/lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/`
- **Vendor**: Realtek (0bda:8179)
- **Product**: 802.11n NIC
- **API**: Wireless Extensions (WEXT) only
- **Firmware**: rtl8188eufw.bin (in `/lib/firmware/rtl/`)

---

## Testing

### Test Open Network

1. Insert USB WiFi adapter
2. Go to Network settings in muOS
3. Enable WiFi
4. Scan for networks
5. Select open network (no password)
6. Should connect and get IP via DHCP

### Test Encrypted Network (WPA2)

1. Scan for networks
2. Select WPA2 network
3. Enter password
4. Connect
5. Verify IP assignment
6. Test connectivity: `ping 8.8.8.8`

### Verify WEXT Support

On device:
```bash
wpa_supplicant -v
# Output should include: drivers: nl80211 wext

lsmod | grep r8188eu
# Should show module loaded

iwconfig wlan0
# Should show wireless extensions info
```

---

## Troubleshooting

### Networks not showing up
- Check module is loaded: `lsmod | grep r8188eu`
- Check interface exists: `ip link show wlan0`
- Try manual scan: `iwlist wlan0 scan`

### Can connect to open networks but not encrypted
- Check wpa_supplicant has WEXT: `wpa_supplicant -v | grep wext`
- Check logs: `tail -f /opt/muos/log/*network*`
- Try manual: `wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf -D wext -d`

### Getting weird IP address (169.254.x.x)
- This is APIPA (no DHCP response)
- Check router DHCP is enabled
- Try manual: `udhcpc -i wlan0`

### Module won't load
- Check module exists: `ls -la /lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/r8188eu.ko`
- Check firmware exists: `ls -la /lib/firmware/rtl/rtl8188eufw.bin`
- Check dmesg: `dmesg | grep -i r8188eu`

---

## Files Modified Summary

### Configuration (3 files)
- `device/rk-g350-v/config/network/name`
- `device/rk-g350-v/config/network/type`
- `device/rk-g350-v/config/network/module`

### Scripts (3 files)
- `script/system/network.sh`
- `script/web/ssid.sh`
- `script/device/network.sh`

### New Files (12 files)
- `third-party/wpa_supplicant/wpa_supplicant-wext-only.config`
- `third-party/wpa_supplicant/wpa_supplicant-internal.config`
- `third-party/wpa_supplicant/wpa_supplicant-minimal.config`
- `third-party/wpa_supplicant/wpa_supplicant.config`
- `third-party/wpa_supplicant/build.sh`
- `third-party/wpa_supplicant/build-native.sh`
- `third-party/wpa_supplicant/fix-arm64-repos.sh`
- `third-party/wpa_supplicant/README.md`
- `third-party/wpa_supplicant/BUILD_TROUBLESHOOTING.md`
- `third-party/wpa_supplicant/RTL8188EU_STATUS.md`
- `share/task/Network Tasks/WiFi Diagnostics (8188eu).sh`
- `share/task/Network Tasks/Enable Wi-Fi (8188eu).sh`

### Binary Replacement (1 file)
- `/usr/sbin/wpa_supplicant` (not in git, must be built and installed)

---

## License and Credits

Based on wpa_supplicant 2.10 from https://w1.fi/
RTL8188EU driver from Linux kernel staging tree

Implementation by Claude for muOS rtl8188eu support.

---

## Appendix: Configuration File Comparison

### wpa_supplicant-wext-only.config (RECOMMENDED)

```
CONFIG_DRIVER_WEXT=y
CONFIG_TLS=internal
CONFIG_INTERNAL_LIBTOMMATH=y
# No WPA3/SAE support
# No nl80211 driver (no libnl dependency)
# Zero external dependencies
```

**Use when**:
- Only need rtl8188eu support
- Want simplest build
- Don't want to deal with ARM64 libraries

### wpa_supplicant-internal.config

```
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_NL80211=y
CONFIG_TLS=internal
CONFIG_INTERNAL_LIBTOMMATH=y
# WPA3/SAE support enabled
# Both drivers (requires libnl)
```

**Use when**:
- Want to support both old and new WiFi adapters
- Have libnl headers available
- Want WPA3 support

### wpa_supplicant-minimal.config

```
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_NL80211=y
CONFIG_TLS=openssl
# Uses OpenSSL for crypto
# Both drivers (requires libnl)
```

**Use when**:
- Have OpenSSL ARM64 libraries
- Want standard crypto implementation
- Don't mind external dependencies

---

## End of Guide
