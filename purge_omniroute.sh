#!/usr/bin/env bash
CONFIG_DIR="${HOME}/.config/omniroute-tray"
STATE_DIR="${HOME}/.local/state/omniroute-tray"
echo "Purging OmniRoute Tray configuration and logs..."
rm -rf "${CONFIG_DIR}" "${STATE_DIR}"
echo "Done."
