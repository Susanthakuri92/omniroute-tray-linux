#!/usr/bin/env bash
# ==============================================================================
# OmniRoute Tray for Linux - One-Line Installer
# Repository: https://github.com/Susanthakuri92/omniroute-tray-linux
# ==============================================================================

set -euo pipefail

# Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

REPO_URL="https://github.com/Susanthakuri92/omniroute-tray-linux.git"
INSTALL_DIR="${HOME}/.local/share/omniroute-tray"
BIN_DIR="${HOME}/.local/bin"
PLASMOID_DIR="${HOME}/.local/share/plasma/plasmoids/org.omniroute.plasmoid"
DESKTOP_DIR="${HOME}/.local/share/applications"

log_info() {
    echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"
}

log_success() {
    echo -e "${GREEN}✓${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}!${RESET} $1"
}

log_error() {
    echo -e "${RED}✗${RESET} $1" >&2
}

# Handle uninstall flag
if [ "${1:-}" = "--uninstall" ]; then
    log_info "Uninstalling OmniRoute Tray..."
    rm -f "${BIN_DIR}/omniroute-tray"
    if [ -L "${PLASMOID_DIR}" ]; then
        rm -f "${PLASMOID_DIR}"
    else
        rm -rf "${PLASMOID_DIR}"
    fi
    rm -f "${DESKTOP_DIR}/omniroute-tray.desktop"
    rm -rf "${INSTALL_DIR}"
    rm -rf "${HOME}/.cache/plasmashell/qmlcache" "${HOME}/.cache/qmlcache" 2>/dev/null || true
    if command -v kbuildsycoca6 &>/dev/null; then
        kbuildsycoca6 --noincremental 2>/dev/null || true
    fi
    if pgrep -x "plasmashell" &>/dev/null; then
        systemctl --user restart plasma-plasmashell 2>/dev/null || true
    fi
    log_success "OmniRoute Tray has been uninstalled."
    exit 0
fi

echo -e "${BOLD}"
cat << "EOF"
   ___                  _ ____             _         _____                  
  / _ \ _ __ ___  _ __ (_)  _ \ ___  _   _| |_ ___  |_   _| __ __ _ _   _   
 | | | | '_ \` _ \| '_ \| | |_) / _ \| | | | __/ _ \   | || '__/ _\` | | | |  
 | |_| | | | | | | | | | |  _ < (_) | |_| | ||  __/   | || | | (_| | |_| |_ 
  \___/|_| |_| |_|_| |_|_|_| \_\___/ \__,_|\__\___|   |_||_|  \__,_|\__, ( )
                                                                    |___/|/ 
EOF
echo -e "${RESET}"
echo -e "Installing OmniRoute Tray for Linux...\n"

# 1. Check prerequisites
log_info "Checking prerequisites..."
if ! command -v python3 &>/dev/null; then
    log_error "Python 3 is required but was not found. Please install python3."
    exit 1
fi

if ! command -v git &>/dev/null; then
    log_error "git is required for installation and auto-updates. Please install git."
    exit 1
fi

PYSIDE_INSTALLED=1
python3 -c "import PySide6" &>/dev/null || PYSIDE_INSTALLED=0

# 2. Clone or Update Repository
log_info "Setting up repository..."
mkdir -p "${HOME}/.local/share"
mkdir -p "${BIN_DIR}"
mkdir -p "${DESKTOP_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/omniroute_tray.py" ] && [ "${SCRIPT_DIR}" != "${INSTALL_DIR}" ]; then
    SOURCE_DIR="${SCRIPT_DIR}"
    log_info "Installing from local directory: ${SOURCE_DIR}"
else
    SOURCE_DIR="${INSTALL_DIR}"
    if [ -d "${INSTALL_DIR}/.git" ]; then
        log_info "Updating existing repository in ${INSTALL_DIR}..."
        git -C "${INSTALL_DIR}" fetch --quiet origin main 2>/dev/null || true
        git -C "${INSTALL_DIR}" reset --hard origin/main --quiet 2>/dev/null || git -C "${INSTALL_DIR}" pull --quiet || true
    else
        log_info "Cloning repository into ${INSTALL_DIR}..."
        rm -rf "${INSTALL_DIR}"
        git clone --quiet "${REPO_URL}" "${INSTALL_DIR}"
    fi
fi
log_success "Files ready."

# 3. Install CLI helper to ~/.local/bin
log_info "Setting up executable in ${BIN_DIR}/omniroute-tray..."
ln -sf "${SOURCE_DIR}/omniroute_tray.py" "${BIN_DIR}/omniroute-tray"
chmod +x "${BIN_DIR}/omniroute-tray"
log_success "Executable linked."

# 4. Install KDE Plasma Plasmoid
log_info "Setting up KDE Plasma 6 widget..."
mkdir -p "${HOME}/.local/share/plasma/plasmoids"
ln -sfn "${SOURCE_DIR}/org.omniroute.plasmoid" "${PLASMOID_DIR}"
rm -rf "${HOME}/.cache/plasmashell/qmlcache" "${HOME}/.cache/qmlcache" 2>/dev/null || true
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
fi
log_success "Plasmoid registered."

# 5. Create Desktop Launcher
log_info "Creating desktop application entry..."
cat > "${DESKTOP_DIR}/omniroute-tray.desktop" << EOF
[Desktop Entry]
Name=OmniRoute Tray
GenericName=AI Gateway Tray
Comment=System Tray Supervisor and Telemetry Monitor for OmniRoute
Exec=${BIN_DIR}/omniroute-tray
Icon=${SOURCE_DIR}/omniroute.svg
Terminal=false
Type=Application
Categories=Utility;Network;Development;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
chmod +x "${DESKTOP_DIR}/omniroute-tray.desktop"
log_success "Desktop launcher created."

# 6. Check PATH
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    log_warn "${BIN_DIR} is not in your current PATH."
    echo -e "  Add this line to your ~/.bashrc or ~/.zshrc:"
    echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}\n"
fi

# 7. Desktop Environment & Dependency Checks
IS_KDE=0
if pgrep -x "plasmashell" &>/dev/null || [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]]; then
    IS_KDE=1
    log_success "KDE Plasma 6 detected! Native Plasmoid registered (runs with standard Python 3, PySide6 not required)."
    systemctl --user restart plasma-plasmashell 2>/dev/null || true
fi

if [ "${IS_KDE}" -eq 0 ]; then
    # Non-KDE desktops use the PySide6 standalone tray
    if [ "${PYSIDE_INSTALLED}" -eq 0 ]; then
        log_warn "PySide6 is not detected. Standalone system tray mode requires PySide6."
        echo -e "  Install it using your distribution package manager:"
        echo -e "  • Arch / CachyOS: ${BOLD}sudo pacman -S python-pyside6${RESET}"
        echo -e "  • Ubuntu / Debian: ${BOLD}sudo apt install python3-pyside6${RESET}"
        echo -e "  • Fedora:          ${BOLD}sudo dnf install python3-pyside6${RESET}"
        echo -e "  • Or via pip:      ${BOLD}pip install PySide6${RESET}\n"
    fi

    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
        log_info "GNOME Shell detected."
        echo -e "  ${YELLOW}!${RESET} GNOME requires the ${BOLD}AppIndicator${RESET} extension to display tray icons in the top bar."
        echo -e "    Ubuntu includes this by default. On Fedora/Debian/Arch: ${BOLD}sudo apt/dnf/pacman install gnome-shell-extension-appindicator${RESET}\n"
    fi
fi

echo -e "\n${GREEN}${BOLD}Installation completed successfully!${RESET}\n"
echo -e "${BOLD}Next steps:${RESET}"
echo -e "  • ${BOLD}KDE Plasma 6:${RESET} Right-click panel → ${BLUE}Add Widgets...${RESET} → search for ${BOLD}OmniRoute${RESET} and drag it to your panel."
echo -e "  • ${BOLD}GNOME / XFCE / Tiling WMs:${RESET} Run ${BOLD}omniroute-tray &${RESET} or launch it from your application menu."
echo -e "  • ${BOLD}In-App Updates:${RESET} Click ${BOLD}[Check for omniroute-tray updates]${RESET} in the tray or run ${BOLD}omniroute-tray --update-tray${RESET} anytime."
