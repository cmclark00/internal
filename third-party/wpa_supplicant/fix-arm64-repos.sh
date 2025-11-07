#!/bin/bash
# Fix ARM64 repository configuration for Pop!_OS
# Pop!_OS doesn't host ARM64 packages, so we need to use Ubuntu repos for cross-compilation

set -e

echo "Configuring ARM64 repositories for cross-compilation..."
echo

# Create a sources list specifically for ARM64 packages from Ubuntu
cat << 'EOF' | sudo tee /etc/apt/sources.list.d/ubuntu-ports-arm64.list
# Ubuntu Ports for ARM64 cross-compilation packages
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse
deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse
EOF

echo "✓ Created /etc/apt/sources.list.d/ubuntu-ports-arm64.list"
echo

# Update package lists
echo "Updating package lists..."
sudo apt-get update

echo
echo "✓ Repository configuration complete!"
echo
echo "Now you can install ARM64 development packages:"
echo "  sudo apt-get install libssl-dev:arm64"
echo
