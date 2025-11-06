#!/bin/sh
# HELP: Test WiFi connection manually
# ICON: ethernet

# Manual WiFi Connection Test
# This script will attempt to connect to WiFi with verbose output

. /opt/muos/script/var/func.sh

FRONTEND stop

TEST_LOG="/opt/muos/log/wifi_connection_test.log"
rm -f "$TEST_LOG"

echo "==================================================================" | tee -a "$TEST_LOG"
echo "Manual WiFi Connection Test" | tee -a "$TEST_LOG"
echo "==================================================================" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Get configuration
SSID=$(GET_VAR "config" "network/ssid")
IFCE="wlan0"
DRIV=$(GET_VAR "device" "network/type")

echo "Configuration:" | tee -a "$TEST_LOG"
echo "  SSID: $SSID" | tee -a "$TEST_LOG"
echo "  Interface: $IFCE" | tee -a "$TEST_LOG"
echo "  Driver Type: $DRIV" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Load network module
echo "Loading network module..." | tee -a "$TEST_LOG"
/opt/muos/script/device/network.sh load
TBOX sleep 2

# Check interface state
echo "Interface state:" | tee -a "$TEST_LOG"
ip link show "$IFCE" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Bring interface up
echo "Bringing interface up..." | tee -a "$TEST_LOG"
ip link set dev "$IFCE" up
TBOX sleep 1

# Check current wireless state
echo "Current wireless state (iwconfig):" | tee -a "$TEST_LOG"
iwconfig "$IFCE" 2>&1 | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Kill any existing wpa_supplicant
echo "Stopping any existing wpa_supplicant..." | tee -a "$TEST_LOG"
killall -q wpa_supplicant
TBOX sleep 1

# Generate wpa_supplicant config
echo "Generating wpa_supplicant config..." | tee -a "$TEST_LOG"
/opt/muos/script/web/password.sh

if [ ! -f "/etc/wpa_supplicant.conf" ]; then
	echo "[ERROR] Failed to generate wpa_supplicant.conf" | tee -a "$TEST_LOG"
	echo "Press any key to exit..."
	read -r
	FRONTEND start task
	exit 1
fi

echo "WPA Supplicant config:" | tee -a "$TEST_LOG"
cat /etc/wpa_supplicant.conf | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Start wpa_supplicant with verbose output
echo "Starting wpa_supplicant with driver: $DRIV" | tee -a "$TEST_LOG"
wpa_supplicant -B -i "$IFCE" -c /etc/wpa_supplicant.conf -D "$DRIV" -d 2>&1 | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Wait and check connection status multiple times
echo "Checking connection status every 2 seconds..." | tee -a "$TEST_LOG"
for i in 1 2 3 4 5 6 7 8 9 10; do
	echo "--- Check $i/10 ---" | tee -a "$TEST_LOG"

	echo "iwconfig output:" | tee -a "$TEST_LOG"
	iwconfig "$IFCE" 2>&1 | tee -a "$TEST_LOG"

	# Check if connected
	if iwconfig "$IFCE" 2>/dev/null | grep -q 'ESSID:"[^"]'; then
		echo "[SUCCESS] Connected to WiFi!" | tee -a "$TEST_LOG"
		break
	else
		echo "Not connected yet..." | tee -a "$TEST_LOG"
	fi

	echo "" | tee -a "$TEST_LOG"
	TBOX sleep 2
done

# Check wpa_supplicant status
echo "Checking wpa_supplicant process:" | tee -a "$TEST_LOG"
ps | grep wpa_supplicant | grep -v grep | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Try wpa_cli status
echo "WPA CLI status:" | tee -a "$TEST_LOG"
wpa_cli -i "$IFCE" status 2>&1 | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Check kernel messages
echo "Recent kernel messages:" | tee -a "$TEST_LOG"
dmesg | tail -30 | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

echo "==================================================================" | tee -a "$TEST_LOG"
echo "Test Complete!" | tee -a "$TEST_LOG"
echo "Log saved to: $TEST_LOG" | tee -a "$TEST_LOG"
echo "==================================================================" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"
echo "Press any key to return to muOS..."
read -r

FRONTEND start task
exit 0
