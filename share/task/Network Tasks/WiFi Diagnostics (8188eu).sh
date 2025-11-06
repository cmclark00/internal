#!/bin/sh
# HELP: Run diagnostics for rtl8188eu USB WiFi adapter
# ICON: ethernet

# WiFi Diagnostics script for rtl8188eu USB WiFi adapters
# This script will test each step of the WiFi setup process and log the results

. /opt/muos/script/var/func.sh

FRONTEND stop

DIAG_LOG="/tmp/wifi_diagnostics.log"
rm -f "$DIAG_LOG"

echo "==================================================================" | tee -a "$DIAG_LOG"
echo "WiFi Diagnostics for rtl8188eu USB Adapter" | tee -a "$DIAG_LOG"
echo "==================================================================" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"

# Get device info
DEV_BOARD=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_MODULE=$(GET_VAR "device" "network/module")
NET_NAME=$(GET_VAR "device" "network/name")
NET_IFACE=$(GET_VAR "device" "network/iface")
NET_IFACE_ACTIVE=$(GET_VAR "device" "network/iface_active")

echo "=== Device Configuration ===" | tee -a "$DIAG_LOG"
echo "Device Board:        $DEV_BOARD" | tee -a "$DIAG_LOG"
echo "Network Enabled:     $HAS_NETWORK" | tee -a "$DIAG_LOG"
echo "Module Path:         $NET_MODULE" | tee -a "$DIAG_LOG"
echo "Module Name:         $NET_NAME" | tee -a "$DIAG_LOG"
echo "Network Interface:   $NET_IFACE" | tee -a "$DIAG_LOG"
echo "Active Interface:    $NET_IFACE_ACTIVE" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"

# Check if USB WiFi adapter is plugged in
echo "=== USB Device Detection ===" | tee -a "$DIAG_LOG"
if lsusb | grep -i "Realtek"; then
	echo "[OK] Realtek USB device detected:" | tee -a "$DIAG_LOG"
	lsusb | grep -i "Realtek" | tee -a "$DIAG_LOG"
else
	echo "[WARN] No Realtek USB device detected" | tee -a "$DIAG_LOG"
	echo "       Please ensure USB WiFi adapter is plugged in" | tee -a "$DIAG_LOG"
fi
echo "" | tee -a "$DIAG_LOG"

# Check if module file exists
echo "=== Kernel Module File ===" | tee -a "$DIAG_LOG"
if [ -f "$NET_MODULE" ]; then
	echo "[OK] Module file exists: $NET_MODULE" | tee -a "$DIAG_LOG"
	ls -lh "$NET_MODULE" | tee -a "$DIAG_LOG"
else
	echo "[ERROR] Module file NOT found: $NET_MODULE" | tee -a "$DIAG_LOG"
fi
echo "" | tee -a "$DIAG_LOG"

# Check if module is currently loaded
echo "=== Kernel Module Status ===" | tee -a "$DIAG_LOG"
if grep -qw "^$NET_NAME" /proc/modules 2>/dev/null; then
	echo "[OK] Module '$NET_NAME' is currently loaded" | tee -a "$DIAG_LOG"
	grep "^$NET_NAME" /proc/modules | tee -a "$DIAG_LOG"
else
	echo "[WARN] Module '$NET_NAME' is NOT loaded" | tee -a "$DIAG_LOG"
	echo "       Attempting to load module..." | tee -a "$DIAG_LOG"

	# Try to load the module
	if modprobe -qf "$NET_NAME"; then
		echo "[OK] Module loaded successfully" | tee -a "$DIAG_LOG"
		TBOX sleep 2
		if grep -qw "^$NET_NAME" /proc/modules 2>/dev/null; then
			echo "[OK] Module verified in /proc/modules" | tee -a "$DIAG_LOG"
		else
			echo "[ERROR] Module loaded but not in /proc/modules" | tee -a "$DIAG_LOG"
		fi
	else
		echo "[ERROR] Failed to load module" | tee -a "$DIAG_LOG"
		echo "       Check dmesg for errors:" | tee -a "$DIAG_LOG"
		dmesg | tail -20 | tee -a "$DIAG_LOG"
	fi
fi
echo "" | tee -a "$DIAG_LOG"

# Check for network interfaces
echo "=== Network Interfaces ===" | tee -a "$DIAG_LOG"
echo "All network interfaces:" | tee -a "$DIAG_LOG"
ip link show | grep "^[0-9]" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"

if [ -d "/sys/class/net/$NET_IFACE" ]; then
	echo "[OK] Interface $NET_IFACE exists" | tee -a "$DIAG_LOG"

	# Show interface details
	echo "Interface state:" | tee -a "$DIAG_LOG"
	ip link show "$NET_IFACE" | tee -a "$DIAG_LOG"
	echo "" | tee -a "$DIAG_LOG"

	# Try to bring interface up
	echo "Bringing interface up..." | tee -a "$DIAG_LOG"
	if ip link set dev "$NET_IFACE" up 2>&1 | tee -a "$DIAG_LOG"; then
		echo "[OK] Interface brought up" | tee -a "$DIAG_LOG"
		TBOX sleep 1
		ip link show "$NET_IFACE" | tee -a "$DIAG_LOG"
	else
		echo "[ERROR] Failed to bring interface up" | tee -a "$DIAG_LOG"
	fi
	echo "" | tee -a "$DIAG_LOG"

	# Check if wireless extension is available
	echo "Checking wireless capabilities..." | tee -a "$DIAG_LOG"
	if [ -d "/sys/class/net/$NET_IFACE/phy80211" ]; then
		echo "[OK] IEEE 802.11 (phy80211) detected" | tee -a "$DIAG_LOG"
		ls -la "/sys/class/net/$NET_IFACE/phy80211" | tee -a "$DIAG_LOG"
	else
		echo "[WARN] No phy80211 link found" | tee -a "$DIAG_LOG"
	fi
	echo "" | tee -a "$DIAG_LOG"

	# Try a scan
	echo "Attempting WiFi scan..." | tee -a "$DIAG_LOG"
	if timeout 15 iw dev "$NET_IFACE" scan 2>&1 | tee -a "$DIAG_LOG" | grep -q "SSID:"; then
		echo "[OK] Scan completed successfully" | tee -a "$DIAG_LOG"
		echo "Networks found:" | tee -a "$DIAG_LOG"
		timeout 15 iw dev "$NET_IFACE" scan 2>/dev/null | grep "SSID:" | sed 's/^[[:space:]]*SSID: //' | sort -u | tee -a "$DIAG_LOG"
	else
		echo "[ERROR] Scan failed or no networks found" | tee -a "$DIAG_LOG"
	fi
else
	echo "[ERROR] Interface $NET_IFACE does NOT exist" | tee -a "$DIAG_LOG"
	echo "       Available interfaces:" | tee -a "$DIAG_LOG"
	ls -1 /sys/class/net/ | tee -a "$DIAG_LOG"
fi
echo "" | tee -a "$DIAG_LOG"

# Check kernel ring buffer for recent WiFi/USB messages
echo "=== Recent Kernel Messages (dmesg) ===" | tee -a "$DIAG_LOG"
echo "Recent rtl8188eu/USB/WiFi messages:" | tee -a "$DIAG_LOG"
dmesg | grep -iE "rtl8188|r8188|usb.*1-|wlan|80211" | tail -30 | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"

# Check rfkill status
echo "=== RF Kill Status ===" | tee -a "$DIAG_LOG"
if command -v rfkill >/dev/null 2>&1; then
	rfkill list all | tee -a "$DIAG_LOG"
else
	echo "rfkill command not available" | tee -a "$DIAG_LOG"
fi
echo "" | tee -a "$DIAG_LOG"

# Show loaded modules
echo "=== All Loaded WiFi-Related Modules ===" | tee -a "$DIAG_LOG"
lsmod | grep -iE "8188|8821|cfg80211|mac80211" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"

# Recent log files
echo "=== Recent muOS Log Files ===" | tee -a "$DIAG_LOG"
if [ -d "/opt/muos/log" ]; then
	ls -lh /opt/muos/log/ | tail -10 | tee -a "$DIAG_LOG"
	echo "" | tee -a "$DIAG_LOG"

	# Show recent network logs if they exist
	LATEST_NET_LOG=$(ls -t /opt/muos/log/*NETWORK* 2>/dev/null | head -1)
	if [ -n "$LATEST_NET_LOG" ]; then
		echo "Latest network log: $LATEST_NET_LOG" | tee -a "$DIAG_LOG"
		echo "Last 30 lines:" | tee -a "$DIAG_LOG"
		tail -30 "$LATEST_NET_LOG" | tee -a "$DIAG_LOG"
	fi
	echo "" | tee -a "$DIAG_LOG"

	LATEST_SSID_LOG=$(ls -t /opt/muos/log/*SSID* 2>/dev/null | head -1)
	if [ -n "$LATEST_SSID_LOG" ]; then
		echo "Latest SSID scan log: $LATEST_SSID_LOG" | tee -a "$DIAG_LOG"
		echo "Last 30 lines:" | tee -a "$DIAG_LOG"
		tail -30 "$LATEST_SSID_LOG" | tee -a "$DIAG_LOG"
	fi
else
	echo "Log directory not found" | tee -a "$DIAG_LOG"
fi
echo "" | tee -a "$DIAG_LOG"

echo "==================================================================" | tee -a "$DIAG_LOG"
echo "Diagnostics Complete!" | tee -a "$DIAG_LOG"
echo "==================================================================" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"
echo "Full diagnostic log saved to: $DIAG_LOG" | tee -a "$DIAG_LOG"
echo "You can view it by running: cat $DIAG_LOG" | tee -a "$DIAG_LOG"
echo "" | tee -a "$DIAG_LOG"
echo "Press any key to return to muOS..."
read -r

FRONTEND start task
exit 0
