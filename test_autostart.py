from pathlib import Path
import os
from omniroute_tray import TrayAssetPaths, XDG_CONFIG_HOME

# Print path used by the script
autostart_target = XDG_CONFIG_HOME / "autostart" / "omniroute-tray.desktop"
print(f"Target path: {autostart_target}")

# Test set_autostart logic
print(f"Executing set_autostart(True)...")
TrayAssetPaths.set_autostart(True)

if autostart_target.exists():
    print("SUCCESS: File created.")
else:
    print("FAILURE: File not created.")
