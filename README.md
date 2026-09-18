# OmniRoute Tray for Linux

<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="OmniRoute Logo" />
</p>

<p align="center">
  <strong>A modern system tray supervisor, real-time telemetry dashboard, diagnostics tool, and auto-updater for <a href="https://www.npmjs.com/package/omniroute">OmniRoute</a> on Linux.</strong>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/Platform-Linux-blue?logo=linux" alt="Linux" /></a>
  <a href="#installation"><img src="https://img.shields.io/badge/Desktop-KDE%20Plasma%20%7C%20GNOME%20%7C%20XFCE%20%7C%20Wayland-brightgreen" alt="Desktops" /></a>
  <a href="#installation"><img src="https://img.shields.io/badge/Python-3.10%2B-blue?logo=python" alt="Python" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" /></a>
</p>

---

OmniRoute Tray replaces the manual workflow of starting `omniroute serve`, checking terminal logs, keeping processes alive across desktop logins, and upgrading versions by hand.

It provides a dual-interface architecture:
1. **Native KDE Plasma 6 Widget (Plasmoid)**: A sleek, tabbed panel popover engineered with native QML and Kirigami design standards.
2. **Universal Standalone Tray (PySide6)**: A dark glassmorphic system tray card compatible with **GNOME**, **XFCE**, **Cinnamon**, **MATE**, **LXQt**, and tiling Wayland/X11 compositors (**i3**, **Sway**, **Hyprland**).

Inspired by [zoispag/omniroute-tray](https://github.com/zoispag/omniroute-tray) (macOS). Ported and expanded for Linux by [Susanthakuri92](https://github.com/susanthakuri92).

---

## Screenshots

| 🖥️ Server Supervisor | 📊 Telemetry & Usage | 🩺 Diagnostics & Logs |
| :---: | :---: | :---: |
| ![Server Tab](screenshot/Screenshot_20260917_160202.png) | ![Monitor Tab](screenshot/Screenshot_20260917_160218.png) | ![Doctor & Logs Tab](screenshot/Screenshot_20260917_160230.png) |

---

## Features

- **Process Supervision & Adoption**: Starts, stops, and restarts the OmniRoute daemon. Automatically adopts an already-running instance on port `20128` without spawning duplicate processes.
- **Provider Health & Breakers**: Real-time status badge showing active providers, configured catalog connections, and open circuit breakers.
- **Live Quotas & Session Limits**: Visual progress bars for Claude, OpenAI, Gemini, and custom provider connections with dynamic reset countdowns and `% left` / `% used` toggle.
- **Spend & Token Analytics**: High-speed spend aggregation across **1D**, **7D**, and **30D** ranges with per-model breakdown, token counts, and `% share` toggles.
- **30-Day Trend Sparkline**: Interactive daily spend trend bar chart with hover tooltips.
- **Doctor Diagnostics**: Instant one-click diagnostic checks verifying Node.js runtime, OmniRoute CLI availability, SQLite database health, and loopback authorization.
- **Live Log Viewer**: Streaming server activity log viewer with a quick shortcut to open log files directly in your default editor.
- **Dedicated Updates Center**: Separate `🔄 Updates` tab with distinct one-click actions: **Check for Omniroute server updates** (queries npm registry) and **Check for omniroute-tray updates** (pulls from GitHub, updates binaries, and syncs plasmoids).
- **Desktop Autostart**: One-click toggle to launch OmniRoute automatically on desktop login (via XDG autostart).
- **Dynamic Tray Icon**: Vector-rendered official OmniRoute glyph that changes color dynamically based on server status (pure white when stopped, vibrant light red when running).

---

## Installation

### ⚡ Quick One-Line Install

Run this single command in your terminal to automatically download the files, link the CLI binary, register the KDE Plasma 6 widget, and configure desktop application shortcuts:

```bash
curl -fsSL https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/install.sh | bash
```

*Or with `wget`:*
```bash
wget -qO- https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/install.sh | bash
```

> **What this does automatically:**
> - Clones or updates the repository in `~/.local/share/omniroute-tray`
> - Symlinks the CLI executable to `~/.local/bin/omniroute-tray`
> - Registers the KDE Plasma 6 Plasmoid to `~/.local/share/plasma/plasmoids/`
> - Generates a `.desktop` application menu launcher with official brand icons
> - Detects your desktop environment and safely reloads Plasma Shell if active

#### Desktop Compatibility & Requirements

| Desktop Environment | Interface | Compatibility | Requirements |
| :--- | :--- | :--- | :--- |
| **KDE Plasma 6** | Native QML Plasmoid | **100% Out-of-the-Box** | Standard Python 3 (included with all distros) |
| **XFCE, Cinnamon, MATE, LXQt** | Standalone PySide6 Tray | **Supported** | `python3-pyside6` package |
| **i3, Sway, Hyprland** | Status Bar Tray (Waybar) | **Supported** | `python3-pyside6` + bar `tray` module |
| **GNOME Desktop** | Standalone PySide6 Tray | **Supported** | `python3-pyside6` + [AppIndicator Extension](https://extensions.gnome.org/extension/615/appindicator-support/)* |

*\* Note: GNOME Shell disabled system tray icons by default. Ubuntu includes the AppIndicator extension pre-installed; on Fedora or Arch GNOME, install `gnome-shell-extension-appindicator`.*

---

### Manual Installation by Desktop Environment

#### Option 1: KDE Plasma 6 (Native Plasmoid Widget)

If you use KDE Plasma 6, install the native QML plasmoid for the best desktop experience:

```bash
# Clone the repository
git clone https://github.com/susanthakuri92/Omniroute-tray.git
cd Omniroute-tray

# Install the plasmoid to your user Plasma directory
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r org.omniroute.plasmoid ~/.local/share/plasma/plasmoids/

# Install the CLI helper to your user PATH
mkdir -p ~/.local/bin
install -m 755 omniroute_tray.py ~/.local/bin/omniroute-tray

# Reload Plasma Shell to detect the new widget
systemctl --user restart plasma-plasmashell
```

**Add to Panel:**
1. Right-click your Plasma panel and select **Add Widgets...**
2. Search for **OmniRoute**.
3. Drag the OmniRoute widget onto your panel or system tray.

---

#### Option 2: GNOME Desktop (Ubuntu, Fedora, Debian, Arch)

GNOME displays system tray icons via the AppIndicator protocol.

#### 1. Prerequisites:
Install Python and PySide6:
```bash
# Arch Linux / CachyOS / Manjaro
sudo pacman -S python python-pyside6

# Ubuntu / Debian
sudo apt install python3 python3-pip python3-pyside6

# Fedora
sudo dnf install python3 python3-pyside6
```

#### 2. Enable AppIndicator Support in GNOME:
Ensure you have the AppIndicator GNOME Shell extension installed:
* **Ubuntu**: Included by default (`gnome-shell-extension-appindicator`).
* **Fedora / Debian / Arch**:
  ```bash
  # Install via package manager
  sudo dnf install gnome-shell-extension-appindicator # Fedora
  sudo pacman -S gnome-shell-extension-appindicator   # Arch
  ```
  Or enable **AppIndicator and KStatusNotifierItem Support** via the [GNOME Extensions Website](https://extensions.gnome.org/extension/615/appindicator-support/) or the Extension Manager app.

#### 3. Install and Run:
```bash
# Install to ~/.local/bin
install -m 755 omniroute_tray.py ~/.local/bin/omniroute-tray

# Run in background
omniroute-tray &
```

---

#### Option 3: XFCE, Cinnamon, MATE, LXQt

These desktop environments support system tray icons natively without extra extensions.

```bash
# Install dependencies
pip install PySide6 # or install via your distro package manager

# Install binary
install -m 755 omniroute_tray.py ~/.local/bin/omniroute-tray

# Launch
omniroute-tray &
```

---

#### Option 4: Tiling Window Managers (i3, Sway, Hyprland)

The tray runs seamlessly on standalone status bars (such as **Waybar**, **Polybar**, **tint2**, or **trayer**).

#### Waybar (Hyprland / Sway):
Ensure your `~/.config/waybar/config` includes the `"tray"` module:
```json
{
  "modules-right": ["tray", "clock"]
}
```

#### Autostart with Window Manager:
* **Hyprland** (`~/.config/hypr/hyprland.conf`):
  ```ini
  exec-once = ~/.local/bin/omniroute-tray
  ```
* **Sway / i3** (`~/.config/sway/config` or `~/.config/i3/config`):
  ```ini
  exec_always --no-startup-id ~/.local/bin/omniroute-tray
  ```

---

---

## Updating

### 1. In-App One-Click Update (Recommended)
- **KDE Plasma 6**: Open the tray popup, switch to the **🔄 Updates** tab, and click either:
  * **`Check for Omniroute server updates`** to check npm for server releases.
  * **`Check for omniroute-tray updates`** to update the tray application directly from GitHub.
- **GNOME / XFCE / Other DEs**: Right-click the system tray icon and select **Check server updates…** or **Update tray app…**.

### 2. Via CLI
```bash
omniroute-tray --update-tray
```
This automatically fetches latest commits from GitHub, updates `~/.local/bin/omniroute-tray`, syncs plasmoids, and refreshes the desktop cache.

### 3. Manual Update
```bash
cd Omniroute-tray
git pull
install -m 755 omniroute_tray.py ~/.local/bin/omniroute-tray
systemctl --user restart plasma-plasmashell
```

## Desktop Autostart & Background Daemon

You can enable autostart with a single click inside the tray popup (**Launch Omniroute server automatically on login**), or via the CLI:

```bash
# Enable launch on login (creates ~/.config/autostart/omniroute-tray.desktop)
omniroute-tray --toggle-autostart
```

### Optional: Systemd User Service

If you prefer managing the tray as a systemd user service:

```ini
# ~/.config/systemd/user/omniroute-tray.service
[Unit]
Description=OmniRoute System Tray Supervisor
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=%h/.local/bin/omniroute-tray
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
```

Enable and start with:
```bash
systemctl --user daemon-reload
systemctl --user enable --now omniroute-tray.service
```

---

## CLI Shortcuts & Automation

`omniroute-tray` doubles as a command-line utility for automation and scripting:

```bash
omniroute-tray --start              # Start the OmniRoute server daemon
omniroute-tray --stop               # Gracefully stop all OmniRoute processes
omniroute-tray --restart            # Restart server daemon
omniroute-tray --cost --range 1d    # Sub-second JSON dump of 24h spend by model
omniroute-tray --cost --range 7d    # Sub-second JSON dump of 7-day spend by model
omniroute-tray --cost --range 30d   # Sub-second JSON dump of 30-day spend by model
omniroute-tray --update-tray        # Self-update tray from GitHub and refresh cache
omniroute-tray --snapshot           # Complete telemetry JSON snapshot
omniroute-tray --toggle-autostart   # Toggle launch on desktop login
```

---

## Configuration

Settings are stored at `~/.config/omniroute-tray/settings.json`:

```json
{
  "serve_command": ["omniroute"],
  "api_base": "http://127.0.0.1:20128",
  "poll_interval_seconds": 15,
  "start_on_login": false,
  "percent_mode": "left",
  "cost_range": "30d",
  "cost_mode": "pct",
  "adopt_existing": true,
  "hidden_sections": []
}
```

| Key | Default | Description |
|---|---|---|
| `serve_command` | `["omniroute"]` | Command used to spawn OmniRoute |
| `api_base` | `"http://127.0.0.1:20128"` | Management API base URL |
| `poll_interval_seconds`| `15` | Polling interval for background health/metrics |
| `cost_range` | `"30d"` | Active spend range (`1d`, `7d`, `30d`) |
| `percent_mode` | `"left"` | Quota display mode (`left` or `used`) |
| `adopt_existing` | `true` | Adopt existing daemon without spawning duplicates |

---

## Repository Structure

```
Omniroute-tray/
├── org.omniroute.plasmoid/         # Native KDE Plasma 6 widget
│   ├── contents/
│   │   ├── ui/
│   │   │   ├── main.qml            # Core engine, polling, command execution
│   │   │   ├── FullRepresentation.qml # Tabbed UI (Server, Monitor, Doctor, Updates)
│   │   │   ├── CompactRepresentation.qml # Dynamic tray panel icon
│   │   │   └── configGeneral.qml   # Plasma configuration dialog
│   │   └── icons/                  # Scalable official vector SVGs
│   └── metadata.json               # Plasmoid metadata & Plasma 6 definition
├── omniroute_tray.py               # Standalone PySide6 system-tray application
├── screenshot/                     # High-resolution screenshots
│   ├── Screenshot_20260917_160202.png # Server View
│   ├── Screenshot_20260917_160218.png # Monitor View
│   └── Screenshot_20260917_160230.png # Doctor & Logs View
├── install.sh                      # Universal one-line installer script
├── omniroute.svg                   # Canonical app icon (white)
├── omniroute_red.svg               # Canonical app icon (light red)
├── omniroute_white.svg             # Canonical app icon (white)
├── .gitignore                      # Clean development exclusions
└── README.md                       # Documentation
```

---

## Contributing

Contributions, bug reports, and suggestions are welcome! Feel free to open an issue or submit a pull request.

---

## License

This project is licensed under the [MIT License](LICENSE).
