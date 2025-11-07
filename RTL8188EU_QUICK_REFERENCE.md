# RTL8188EU Quick Reference

## For Creating a Clean Image

### Files to Change (6 files)

#### 1. Configuration Files (3 files)
```bash
device/rk-g350-v/config/network/name
device/rk-g350-v/config/network/type
device/rk-g350-v/config/network/module
```

#### 2. Scripts (3 files)
```bash
script/system/network.sh      # Add rk* case for WEXT connection
script/web/ssid.sh            # Add rk* case for iwlist scanning
script/device/network.sh      # Add cfg80211 preloading
```

### Binary to Replace (1 file)
```bash
/usr/sbin/wpa_supplicant      # Build from third-party/wpa_supplicant/
```

---

## Build wpa_supplicant (One-Time)

```bash
cd third-party/wpa_supplicant

# Download source
wget https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
tar -xzf wpa_supplicant-2.10.tar.gz

# Build
export CROSS_COMPILE=aarch64-linux-gnu-
export STATIC=1
CONFIG_FILE=wpa_supplicant-wext-only.config ./build.sh

# Binary is in: build/wpa_supplicant
```

---

## Integration Steps

### Option A: Before Creating Image

```bash
# 1. Apply all git changes from branch
git checkout claude/rtl8188eu-wifi-adapter-011CUpA4en8B1XTkhXMCFX46

# 2. Build wpa_supplicant (see above)

# 3. Replace binary in rootfs before packaging
sudo mount /dev/sdX2 /mnt
sudo cp build/wpa_supplicant /mnt/usr/sbin/wpa_supplicant
sudo chmod 755 /mnt/usr/sbin/wpa_supplicant
sudo umount /mnt

# 4. Create image as normal
```

### Option B: Patch Existing Image

```bash
# 1. Mount image partition
sudo mount /dev/sdX2 /mnt

# 2. Copy modified scripts
sudo cp script/system/network.sh /mnt/opt/muos/script/system/
sudo cp script/web/ssid.sh /mnt/opt/muos/script/web/
sudo cp script/device/network.sh /mnt/opt/muos/script/device/

# 3. Update config files
sudo sh -c 'echo "r8188eu" > /mnt/opt/muos/device/rk-g350-v/config/network/name'
sudo sh -c 'echo "nl80211" > /mnt/opt/muos/device/rk-g350-v/config/network/type'
sudo sh -c 'echo "/lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/r8188eu.ko" > /mnt/opt/muos/device/rk-g350-v/config/network/module'

# 4. Replace wpa_supplicant binary
sudo cp build/wpa_supplicant /mnt/usr/sbin/wpa_supplicant
sudo chmod 755 /mnt/usr/sbin/wpa_supplicant

# 5. Unmount
sudo umount /mnt
```

---

## Changed Files Overview

### script/system/network.sh
**What**: Added rk* device case for WEXT-based WiFi connection
**Lines**: ~100-200 (in connect/disconnect functions)
**Key change**: Use `iwconfig` and `wpa_supplicant -D wext` instead of `iw`

### script/web/ssid.sh
**What**: Added rk* device case for WEXT-based WiFi scanning
**Lines**: ~40-80
**Key change**: Use `iwlist scan` instead of `iw scan`

### script/device/network.sh
**What**: Added cfg80211 module preloading for rk* devices
**Lines**: ~10-20
**Key change**: `modprobe cfg80211` before loading WiFi driver

### device/rk-g350-v/config/network/name
**What**: Corrected module name
**Change**: `8188eu` → `r8188eu`

### device/rk-g350-v/config/network/type
**What**: Driver type for wpa_supplicant
**Value**: `nl80211` (but scripts use WEXT tools)

### device/rk-g350-v/config/network/module
**What**: Full path to kernel module
**Value**: `/lib/modules/4.4.189/kernel/drivers/staging/rtl8188eu/r8188eu.ko`

### /usr/sbin/wpa_supplicant
**What**: Replace with WEXT-enabled build
**From**: wpa_supplicant 2.11 (no WEXT)
**To**: wpa_supplicant 2.10 (with WEXT)
**Size**: ~400KB (stripped)

---

## Verification Commands

### On Device
```bash
# Check module loaded
lsmod | grep r8188eu

# Check interface exists
ip link show wlan0

# Check wpa_supplicant has WEXT
wpa_supplicant -v
# Should show: drivers: nl80211 wext

# Test scan
iwlist wlan0 scan

# Check wireless extensions
iwconfig wlan0
```

---

## What Works

- ✅ Open networks (no password)
- ✅ WPA/WPA2 Personal networks
- ✅ DHCP IP assignment
- ✅ Network scanning
- ✅ Automatic connection
- ✅ WPS setup
- ✅ Network reconnection after suspend

## What Doesn't Work

- ❌ WPA3/SAE (requires external elliptic curve crypto)

---

## Commits Included

```
d755463 Disable WPA3/SAE support in WEXT-only config
6054532 Add WEXT-only config for zero-dependency builds
61ab31d Add wpa_supplicant internal crypto config
b99b107 Add Pop!_OS ARM64 repository configuration fix
84e9596 Fix pkg-config cross-compilation
b12d8fe Fix cross-compilation OpenSSL header path issues
5e7f420 Add minimal wpa_supplicant config
0a56d79 Add wpa_supplicant verification script
28b5f64 Update RTL8188EU_STATUS documentation
6e20958 Add wpa_supplicant build infrastructure
c3e45b1 Add rtl8188eu limitations documentation
e420aae Add wireless extensions fallback for rk* devices
b2f054b Fix wpa_supplicant driver selection
4d7b191 Improve WiFi association detection
69cd740 Add WiFi connection test script
4e806e5 Switch from nl80211 to wireless extensions
b591591 Preload cfg80211 module for rk* devices
0ee95bc Add cfg80211 checks to diagnostics
6d438ea Enhance WiFi diagnostics
f83fbf8 Save diagnostics to persistent storage
399bc94 Add WiFi diagnostics script
52150e8 Add rk-g350-v network module loading
6b45369 Fix rtl8188eu USB WiFi adapter support
```

---

## Support

See `RTL8188EU_IMPLEMENTATION_GUIDE.md` for complete details.

For build issues, see `third-party/wpa_supplicant/BUILD_TROUBLESHOOTING.md`.

For technical background, see `third-party/wpa_supplicant/RTL8188EU_STATUS.md`.
