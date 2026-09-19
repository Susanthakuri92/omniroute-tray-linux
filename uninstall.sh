#!/usr/bin/env bash
# ==============================================================================
# OmniRoute Tray for Linux - Uninstaller
# Repository: https://github.com/Susanthakuri92/omniroute-tray-linux
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

INSTALL_DIR="${HOME}/.local/share/omniroute-tray"
BIN_PATH="${HOME}/.local/bin/omniroute-tray"
PLASMOID_DIR="${HOME}/.local/share/plasma/plasmoids/org.omniroute.plasmoid"
DESKTOP_ENTRY="${HOME}/.local/share/applications/omniroute-tray.desktop"
AUTOSTART_ENTRY="${HOME}/.config/autostart/omniroute-tray.desktop"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
CONFIG_DIR="${HOME}/.config/omniroute-tray"
STATE_DIR="${HOME}/.local/state/omniroute-tray"
SYSTEM_PLASMOID_DIR="/usr/share/plasma/plasmoids/org.omniroute.plasmoid"

PURGE=0
for arg in "$@"; do
    if [ "$arg" = "--purge" ]; then
        PURGE=1
    fi
done

echo -e "${BOLD}OmniRoute Tray Uninstaller${RESET}\n"

# 1. Stop running processes
if [ -x "${BIN_PATH}" ]; then
    echo -e "${BLUE}==>${RESET} Stopping running OmniRoute processes..."
    "${BIN_PATH}" --stop 2>/dev/null || true
fi
pkill -f "omniroute_tray.py" 2>/dev/null || true

# 2. Remove desktop & autostart entries
echo -e "${BLUE}==>${RESET} Removing desktop integrations..."
rm -f "${DESKTOP_ENTRY}"
rm -f "${AUTOSTART_ENTRY}"

# 3. Remove installed icons
rm -f "${ICON_DIR}/omniroute-tray.svg"
rm -f "${ICON_DIR}/omniroute-tray-symbolic.svg"
rm -f "${ICON_DIR}/omniroute-tray-active-symbolic.svg"

# 4. Remove CLI executable symlink
echo -e "${BLUE}==>${RESET} Removing executable..."
rm -f "${BIN_PATH}"

# 5. Remove KDE Plasma widget symlink
if [ -L "${PLASMOID_DIR}" ] || [ -d "${PLASMOID_DIR}" ]; then
    echo -e "${BLUE}==>${RESET} Removing KDE Plasma widget..."
    rm -rf "${PLASMOID_DIR}"
    rm -rf "${HOME}/.cache/plasmashell/qmlcache" "${HOME}/.cache/qmlcache" 2>/dev/null || true
    if command -v kbuildsycoca6 &>/dev/null; then
        kbuildsycoca6 --noincremental 2>/dev/null || true
    fi
    if pgrep -x "plasmashell" &>/dev/null; then
        systemctl --user restart plasma-plasmashell 2>/dev/null || true
    fi
fi

# 6. Remove repository clone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || echo "")"
if [ -d "${INSTALL_DIR}" ] && [ "${SCRIPT_DIR}" != "${INSTALL_DIR}" ]; then
    echo -e "${BLUE}==>${RESET} Removing application files from ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR}"
fi

# 7. Purge configuration and logs if requested
if [ "${PURGE}" -eq 1 ]; then
    echo -e "${BLUE}==>${RESET} Purging configuration and logs (--purge specified)..."
    rm -rf "${CONFIG_DIR}"
    rm -rf "${STATE_DIR}"
    echo -e "${GREEN}✓${RESET} Configuration and logs purged."
else
    if [ -d "${CONFIG_DIR}" ] || [ -d "${STATE_DIR}" ]; then
        echo -e "${YELLOW}!${RESET} Configuration preserved in ${CONFIG_DIR}."
        echo -e "  To also delete configuration and logs, re-run with: ${BOLD}$0 --purge${RESET}"
    fi
fi

# 8. Check for system-wide plasmoid
if [ -e "${SYSTEM_PLASMOID_DIR}" ] || [ -L "${SYSTEM_PLASMOID_DIR}" ]; then
    echo -e "\n${YELLOW}!${RESET} A system-wide plasmoid was found at ${SYSTEM_PLASMOID_DIR}"
    echo -e "  To remove it, run: ${BOLD}sudo rm -rf ${SYSTEM_PLASMOID_DIR}${RESET}"
fi

echo -e "\n${GREEN}${BOLD}OmniRoute Tray has been successfully uninstalled!${RESET}"
