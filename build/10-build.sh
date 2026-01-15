#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/ 2>/dev/null || true

echo "::groupend::"

echo "::group:: Copy Custom Files"

# Copy OCI brew files (Homebrew integration)
if [[ -d /ctx/oci/brew ]]; then
    cp -r /ctx/oci/brew/usr/* /usr/
    cp -r /ctx/oci/brew/etc/* /etc/ 2>/dev/null || true
    # Copy Homebrew tarball for first-boot extraction
    mkdir -p /usr/share
    cp /ctx/oci/brew/usr/share/homebrew.tar.zst /usr/share/ 2>/dev/null || true
fi

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::groupend::"

# Restore default glob behavior
shopt -u nullglob

echo "::group:: Install Packages"

# Install DNF groups
dnf5 group install -y development-tools
dnf5 group install -y c-development
dnf5 group install -y container-management

dnf5 install -y distrobox fish zsh fastfetch

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

echo "::groupend::"

echo "::group:: Flatpak Patching"

# Patch flatpak for Fedora >= 42 (temporary workaround until preinstall lands in Fedora)
if [[ "$(rpm -E %fedora)" -ge "42" ]]; then
    dnf -y copr enable ublue-os/flatpak-test
    dnf -y copr disable ublue-os/flatpak-test
    dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak flatpak
    dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-libs flatpak-libs
    dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-session-helper flatpak-session-helper
    dnf -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test install flatpak-debuginfo flatpak-libs-debuginfo flatpak-session-helper-debuginfo
fi

echo "::groupend::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
# Homebrew services (preset enables based on 01-homebrew.preset)
systemctl preset brew-setup.service brew-update.timer brew-upgrade.timer

echo "::groupend::"

echo "Custom build complete!"
