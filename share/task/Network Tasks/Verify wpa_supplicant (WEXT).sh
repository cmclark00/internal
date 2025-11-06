#!/bin/sh
# HELP: Verify wpa_supplicant and test WEXT driver
# ICON: ethernet

# Verification script for wpa_supplicant with WEXT support

. /opt/muos/script/var/func.sh

FRONTEND stop

VERIFY_LOG="/opt/muos/log/wpa_supplicant_verify.log"
rm -f "$VERIFY_LOG"

echo "==================================================================" | tee -a "$VERIFY_LOG"
echo "wpa_supplicant Verification & WEXT Driver Test" | tee -a "$VERIFY_LOG"
echo "==================================================================" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Check wpa_supplicant version and drivers
echo "=== wpa_supplicant Information ===" | tee -a "$VERIFY_LOG"
echo "Binary location:" | tee -a "$VERIFY_LOG"
which wpa_supplicant | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

echo "Version:" | tee -a "$VERIFY_LOG"
wpa_supplicant -v 2>&1 | head -5 | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

echo "Checking for WEXT driver support:" | tee -a "$VERIFY_LOG"
if wpa_supplicant -v 2>&1 | grep -q "wext"; then
	echo "[OK] WEXT driver IS supported" | tee -a "$VERIFY_LOG"
	wpa_supplicant -v 2>&1 | grep "drivers:" | tee -a "$VERIFY_LOG"
else
	echo "[ERROR] WEXT driver NOT supported!" | tee -a "$VERIFY_LOG"
	echo "You need to install wpa_supplicant compiled with CONFIG_DRIVER_WEXT=y" | tee -a "$VERIFY_LOG"
	echo "See third-party/wpa_supplicant/README.md for build instructions" | tee -a "$VERIFY_LOG"
fi
echo "" | tee -a "$VERIFY_LOG"

# Get configuration
SSID=$(GET_VAR "config" "network/ssid")
IFCE="wlan0"

echo "=== Configuration ===" | tee -a "$VERIFY_LOG"
echo "SSID: $SSID" | tee -a "$VERIFY_LOG"
echo "Interface: $IFCE" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Load network module
echo "=== Loading Network Module ===" | tee -a "$VERIFY_LOG"
/opt/muos/script/device/network.sh load
TBOX sleep 2

# Check interface
echo "Interface state:" | tee -a "$VERIFY_LOG"
ip link show "$IFCE" 2>&1 | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Bring up interface
echo "Bringing interface up..." | tee -a "$VERIFY_LOG"
ip link set dev "$IFCE" up
TBOX sleep 1

# Check current state
echo "Current wireless state:" | tee -a "$VERIFY_LOG"
iwconfig "$IFCE" 2>&1 | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Kill existing wpa_supplicant
echo "=== Stopping Existing wpa_supplicant ===" | tee -a "$VERIFY_LOG"
killall -q wpa_supplicant
TBOX sleep 1

# Generate config
echo "=== Generating WPA Config ===" | tee -a "$VERIFY_LOG"
/opt/muos/script/web/password.sh

if [ ! -f "/etc/wpa_supplicant.conf" ]; then
	echo "[ERROR] Failed to generate wpa_supplicant.conf" | tee -a "$VERIFY_LOG"
	echo "Press any key to exit..."
	read -r
	FRONTEND start task
	exit 1
fi

echo "WPA Config:" | tee -a "$VERIFY_LOG"
cat /etc/wpa_supplicant.conf | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Test wpa_supplicant with wext driver
echo "=== Testing wpa_supplicant with WEXT Driver ===" | tee -a "$VERIFY_LOG"
echo "Starting wpa_supplicant in debug mode with wext driver..." | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Start with debug output
wpa_supplicant -i "$IFCE" -c /etc/wpa_supplicant.conf -D wext -dd 2>&1 | tee -a "$VERIFY_LOG" &
WPA_PID=$!

echo "wpa_supplicant PID: $WPA_PID" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Wait and monitor
echo "Monitoring connection for 30 seconds..." | tee -a "$VERIFY_LOG"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	echo "--- Check $i/15 (every 2 seconds) ---" | tee -a "$VERIFY_LOG"

	# Check process
	if ! kill -0 $WPA_PID 2>/dev/null; then
		echo "[ERROR] wpa_supplicant process died!" | tee -a "$VERIFY_LOG"
		break
	fi

	# Check association
	IWCONFIG_OUT=$(iwconfig "$IFCE" 2>/dev/null)
	echo "iwconfig status:" | tee -a "$VERIFY_LOG"
	echo "$IWCONFIG_OUT" | grep -E "ESSID|Access Point|Link Quality" | tee -a "$VERIFY_LOG"

	if echo "$IWCONFIG_OUT" | grep -qv "unassociated" && echo "$IWCONFIG_OUT" | grep -q 'ESSID:"'; then
		if ! echo "$IWCONFIG_OUT" | grep -q 'ESSID:""'; then
			echo "[SUCCESS] WiFi Associated!" | tee -a "$VERIFY_LOG"

			# Try to get IP
			echo "Attempting DHCP..." | tee -a "$VERIFY_LOG"
			dhcpcd "$IFCE" 2>&1 | tee -a "$VERIFY_LOG" &
			TBOX sleep 5

			IP=$(ip -4 a show dev "$IFCE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p')
			if [ -n "$IP" ]; then
				echo "[SUCCESS] Got IP address: $IP" | tee -a "$VERIFY_LOG"
			else
				echo "[WARN] No IP address obtained" | tee -a "$VERIFY_LOG"
			fi
			break
		fi
	fi

	echo "" | tee -a "$VERIFY_LOG"
	TBOX sleep 2
done

echo "" | tee -a "$VERIFY_LOG"
echo "=== Final Status ===" | tee -a "$VERIFY_LOG"
echo "Interface state:" | tee -a "$VERIFY_LOG"
ip addr show "$IFCE" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

echo "iwconfig state:" | tee -a "$VERIFY_LOG"
iwconfig "$IFCE" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"

# Stop wpa_supplicant
if kill -0 $WPA_PID 2>/dev/null; then
	echo "Stopping wpa_supplicant..." | tee -a "$VERIFY_LOG"
	kill $WPA_PID
fi

echo "==================================================================" | tee -a "$VERIFY_LOG"
echo "Verification Complete!" | tee -a "$VERIFY_LOG"
echo "==================================================================" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"
echo "Log saved to: $VERIFY_LOG" | tee -a "$VERIFY_LOG"
echo "" | tee -a "$VERIFY_LOG"
echo "Press any key to return to muOS..."
read -r

FRONTEND start task
exit 0
