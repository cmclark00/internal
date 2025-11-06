# rtl8188eu WiFi Adapter Status for rk-g350-v

## Current Status

✅ **WiFi Scanning**: WORKS - Networks are detected successfully using `iwlist`
❌ **WiFi Connection**: DOES NOT WORK for WPA/WPA2 networks
⚠️ **Open Networks**: May work (untested)

## The Problem

The rtl8188eu USB WiFi adapter uses an old staging driver (r8188eu) in kernel 4.4.189 that:
- Only supports the deprecated Wireless Extensions (WEXT) API
- Does NOT support modern nl80211 authentication commands

Meanwhile, wpa_supplicant 2.11 on muOS:
- Removed support for the WEXT driver
- Only supports nl80211 driver interface

**Result**: wpa_supplicant cannot authenticate with WPA/WPA2 networks on this adapter.

## Error Messages

```
wpa_supplicant with wext: "Unsupported driver 'wext'"
wpa_supplicant with nl80211: "Driver does not support authentication/association or connect commands"
```

## Solutions

### Option 1: Build wpa_supplicant with WEXT Support (Recommended)

**Complete build infrastructure is now included in this repository!**

See `third-party/wpa_supplicant/README.md` for full instructions.

**Quick Start**:

1. Download wpa_supplicant source:
   ```bash
   cd third-party/wpa_supplicant
   wget https://w1.fi/releases/wpa_supplicant-2.10.tar.gz
   tar -xzf wpa_supplicant-2.10.tar.gz
   ```

2. Build (with cross-compiler for ARM64):
   ```bash
   export CROSS_COMPILE=aarch64-linux-gnu-
   export STATIC=1
   ./build.sh
   ```

3. Install on device:
   ```bash
   # Copy binary to SD card MUOS partition, then on device:
   mv /usr/sbin/wpa_supplicant /usr/sbin/wpa_supplicant.bak
   cp /path/to/new/wpa_supplicant /usr/sbin/
   chmod +x /usr/sbin/wpa_supplicant
   ```

The build script automatically:
- Configures with WEXT and nl80211 support
- Optimizes for size
- Verifies WEXT is enabled
- Provides installation instructions

### Option 2: Use Different WiFi Adapter

Consider using a USB WiFi adapter with better Linux support:
- MediaTek MT7601U (good mainline support)
- Ralink RT5370 (mature driver)
- Realtek RTL8188FU (newer, better support)

### Option 3: Test Open Networks

The current code may work with unencrypted/open WiFi networks since they don't require WPA authentication.

## Files Modified

This branch includes fixes for:
1. Module name (8188eu → r8188eu)
2. Network module loading for rk* devices
3. SSID scanning using wireless extensions (iwlist)
4. Attempted connection logic using iwconfig

## Technical Details

**Working**:
- USB device detection
- Kernel module loading (r8188eu)
- Interface creation (wlan0)
- Network scanning (iwlist scan)
- Wireless extensions tools (iwconfig, iwlist)

**Not Working**:
- WPA/WPA2 authentication (no compatible wpa_supplicant)
- Connection to encrypted networks

## Testing

To test if your network is reachable, run:
```
Configuration → Tasks → Network Tasks → "WiFi Connection Test"
```

This will show detailed debug output and save logs to `/opt/muos/log/wifi_connection_test.log`
