# OmniRoute Tray for Linux

<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="OmniRoute Logo" />
</p>

<p align="center">
  <strong>A modern system tray supervisor, real-time telemetry dashboard, diagnostics tool, and auto-updater for <a href="https://www.npmjs.com/package/omniroute">OmniRoute</a> on Linux.</strong>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/Platform-Linux-blue?logo=linux" alt="Linux" /></a>
  <a href="#desktop-environment-support"><img src="https://img.shields.io/badge/Desktop-KDE%20Plasma%20%7C%20GNOME%20%7C%20XFCE%20%7C%20Wayland-brightgreen" alt="Desktops" /></a>
  <a href="#installation"><img src="https://img.shields.io/badge/Python-3.10%2B-blue?logo=python" alt="Python" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" /></a>
</p>

---

OmniRoute Tray replaces the manual terminal workflow of starting `omniroute`, checking logs, keeping background processes alive across logins, and upgrading versions by hand.

It features a **dual-interface architecture**:
1. **Native KDE Plasma 6 Widget (Plasmoid)**: A sleek, tabbed popover built with native QML and Kirigami. Integrates directly into your KDE panel or system tray with zero Electron or extra runtime overhead (standard Python 3 only).
2. **Universal Desktop Tray (Qt/PySide6)**: A dark glassmorphic system tray card compatible with **GNOME**, **XFCE**, **Cinnamon**, **MATE**, **LXQt**, and tiling Wayland/X11 compositors (**Hyprland**, **Sway**, **i3**).

Inspired by [zoispag/omniroute-tray](https://github.com/zoispag/omniroute-tray) (macOS). Developed for Linux by [Susanthakuri92](https://github.com/Susanthakuri92).

---

## Screenshots

| 🖥️ Server Supervisor | 📊 Telemetry & Quotas | 🩺 Diagnostics & Logs |
| :---: | :---: | :---: |
| ![Server Tab](screenshot/Screenshot_20260917_160202.png) | ![Monitor Tab](screenshot/Screenshot_20260917_160218.png) | ![Doctor & Logs Tab](screenshot/Screenshot_20260917_160230.png) |

---

## Features

- **Process Supervision & Adoption**: Starts, stops, and restarts the OmniRoute daemon. Automatically adopts an already-running instance on port `20128` without spawning duplicate processes.
- **Provider Health & Breakers**: Real-time status badge showing active providers, configured catalog connections, and open circuit breakers.
- **Live Quotas & Session Limits**: Visual progress bars for Claude, OpenAI, Gemini, and custom providers with dynamic reset countdowns and `% left` / `% used` toggle.
- **Spend & Token Analytics**: High-speed spend aggregation across **1D**, **7D**, and **30D** ranges with per-model breakdown, token counts, and `% share` toggles.
- **30-Day Trend Sparkline**: Interactive daily spend trend bar chart with hover tooltips.
- **Doctor Diagnostics**: Instant one-click diagnostic checks verifying Node.js runtime, OmniRoute CLI availability, SQLite database health, and loopback authorization.
- **Live Log Viewer**: Streaming server activity log viewer with a quick shortcut to open log files directly in your default editor.
- **Clean Updates Center**:
  - Distinct cards for **OmniRoute Server** and **OmniRoute Tray**.
  - Direct **GitHub ↗** buttons opening each project's repository in your browser.
  - Live version badges and Git commit hash tracking.
  - One-click tray auto-update pulling latest code directly from GitHub.
  - Dynamic update banner with a copyable `npm i -g omniroute@latest` command when an upstream server release is found.
- **Single-Instance Protection**: Prevents duplicate tray icons and process stacking using kernel file locks and desktop containment detection.
- **Desktop Autostart**: One-click toggle to launch OmniRoute automatically on desktop login (via XDG autostart).
- **Dynamic Tray Icon**: Vector-rendered official OmniRoute glyph that changes color dynamically (white when stopped, red when running).

---

## Desktop Environment Support

OmniRoute Tray runs across all major Linux desktop environments:

| Desktop Environment | Interface Mode | Prerequisites | Experience |
| :--- | :--- | :--- | :--- |
| **KDE Plasma 6** | Native Plasmoid Widget | Python 3, Git (PySide6 **not** required) | Seamless integration into system tray or panel |
| **Ubuntu GNOME** | Standalone Qt Tray | `python3-pyside6` | Tray icon in top bar (AppIndicator is built-in on Ubuntu) |
| **Fedora / Arch / Debian GNOME** | Standalone Qt Tray | `python3-pyside6` + AppIndicator extension | Tray icon in top bar via AppIndicator |
| **XFCE / Cinnamon / MATE / LXQt** | Standalone Qt Tray | `python3-pyside6` | Native system tray out of the box |
| **Hyprland / Sway / i3** | Standalone Qt Tray | `python3-pyside6` | Displays in Waybar (`"tray"` module), Polybar, or i3bar |

---

## Installation

### ⚡ Quick One-Line Install

Run this command in your terminal to download the files, link the CLI binary, register the KDE Plasma 6 widget, and create application shortcuts:

```bash
curl -fsSL https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/install.sh | bash
```

*Or with `wget`:*
```bash
wget -qO- https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/install.sh | bash
```

> **What this command does:**
> - Clones or updates the repository in `~/.local/share/omniroute-tray`
> - Symlinks the CLI executable to `~/.local/bin/omniroute-tray`
> - Registers the KDE Plasma 6 Plasmoid to `~/.local/share/plasma/plasmoids/`
> - Generates a `.desktop` application menu launcher with official brand icons
> - Detects your desktop environment and safely refreshes Plasma Shell if active
> - **Safe & Idempotent**: Cleanly updates existing files without creating duplicate applets or nested folders.

---

### Setup by Desktop Environment

#### 1. KDE Plasma 6
The native widget requires standard Python 3 and Git (no PySide6 or compiler needed).
1. Run the **Quick One-Line Install** above.
2. Right-click your Plasma panel → **Add Widgets...**
3. Search for **OmniRoute** and drag it into your panel or System Tray.

#### 2. GNOME Desktop (Ubuntu, Fedora, Debian, Arch)
GNOME displays system tray icons through the standard AppIndicator protocol:
1. **Install PySide6**:
   ```bash
   # Ubuntu / Debian
   sudo apt install python3-pyside6

   # Fedora
   sudo dnf install python3-pyside6

   # Arch Linux / CachyOS / Manjaro
   sudo pacman -S python-pyside6
   ```
2. **Enable AppIndicator Support in GNOME**:
   * **Ubuntu**: Included out of the box.
   * **Fedora / Debian / Arch**: Install the extension package:
     ```bash
     sudo dnf install gnome-shell-extension-appindicator   # Fedora
     sudo pacman -S gnome-shell-extension-appindicator     # Arch
     sudo apt install gnome-shell-extension-appindicator    # Debian
     ```
     *(Or enable "AppIndicator and KStatusNotifierItem Support" via Extension Manager / extensions.gnome.org).*
3. **Launch OmniRoute Tray**:
   Launch **OmniRoute Tray** from your application menu, or run:
   ```bash
   omniroute-tray &
   ```

#### 3. XFCE, Cinnamon, MATE, LXQt
These desktops provide built-in system tray notification areas:
1. Ensure PySide6 is installed (`sudo apt/dnf/pacman install python3-pyside6`).
2. Run the one-line install command.
3. Launch **OmniRoute Tray** from your menu or terminal.

#### 4. Tiling Window Managers (Hyprland, Sway, i3)
Works with **Waybar**, **Polybar**, or **i3bar**:
* **Waybar** (`~/.config/waybar/config`): Ensure `"tray"` is in your modules list:
  ```json
  "modules-right": ["tray", "clock"]
  ```
* **Autostart**:
  * Hyprland (`~/.config/hypr/hyprland.conf`): `exec-once = ~/.local/bin/omniroute-tray`
  * Sway / i3: `exec_always --no-startup-id ~/.local/bin/omniroute-tray`

---

## Manual Installation (From Git)

```bash
# 1. Clone repository
git clone https://github.com/Susanthakuri92/omniroute-tray-linux.git ~/.local/share/omniroute-tray
cd ~/.local/share/omniroute-tray

# 2. Run local installer
./install.sh
```

---

## Updating

### In-App Update (Recommended)
1. Open the tray popover and click the **Updates** tab.
2. Click **Check for Tray Updates** to pull the latest features and bug fixes from GitHub.
3. Click **Check for Updates** on OmniRoute Server to query npm for newer server releases.
4. Click **GitHub ↗** on either card to view the upstream repository.

### Via Command Line
```bash
omniroute-tray --update-tray
```

---

## Uninstallation

OmniRoute Tray includes a clean uninstaller that removes all symlinks, plasmoids, autostart entries, and desktop shortcuts.

### ⚡ One-Line Quick Uninstall
```bash
curl -fsSL https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/uninstall.sh | bash
```

### From Local Installation
```bash
# Using the dedicated uninstaller script:
~/.local/share/omniroute-tray/uninstall.sh

# Or with install.sh:
~/.local/share/omniroute-tray/install.sh --uninstall
```

### Complete Purge (Optional)
By default, the uninstaller preserves your configuration (`~/.config/omniroute-tray`) and server logs. To remove them as well, pass `--purge`:
```bash
~/.local/share/omniroute-tray/uninstall.sh --purge
```

> **What the uninstaller removes:**
> - Running tray and background processes
> - Executable symlink: `~/.local/bin/omniroute-tray`
> - KDE Plasma widget: `~/.local/share/plasma/plasmoids/org.omniroute.plasmoid`
> - Desktop menu entry: `~/.local/share/applications/omniroute-tray.desktop`
> - Login autostart entry: `~/.config/autostart/omniroute-tray.desktop`
> - Vector application icons: `~/.local/share/icons/hicolor/scalable/apps/omniroute-tray*.svg`
> - Cloned repository: `~/.local/share/omniroute-tray`
> - Clears QML cache and refreshes desktop databases

---

## CLI Shortcuts & Automation

`omniroute-tray` functions as a full-featured CLI utility for scripts and terminal workflows:

| Command | Action |
| :--- | :--- |
| `omniroute-tray --start` | Start the OmniRoute server daemon in background |
| `omniroute-tray --stop` | Gracefully stop all OmniRoute processes |
| `omniroute-tray --restart` | Restart the OmniRoute server daemon |
| `omniroute-tray --cost --range 1d` | Sub-second JSON dump of 24h spend by model |
| `omniroute-tray --cost --range 7d` | Sub-second JSON dump of 7-day spend by model |
| `omniroute-tray --cost --range 30d` | Sub-second JSON dump of 30-day spend by model |
| `omniroute-tray --snapshot` | Full telemetry JSON snapshot (health, quotas, rates, cost) |
| `omniroute-tray --update-tray` | Pull latest code from GitHub and sync desktop widgets |
| `omniroute-tray --toggle-autostart` | Toggle start on desktop login |

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
| :--- | :--- | :--- |
| `serve_command` | `["omniroute"]` | Command used to spawn OmniRoute |
| `api_base` | `"http://127.0.0.1:20128"` | Management API base URL |
| `poll_interval_seconds` | `15` | Polling interval for health and telemetry (seconds) |
| `start_on_login` | `false` | Automatically launch OmniRoute on desktop login |
| `percent_mode` | `"left"` | Quota display mode (`left` or `used`) |
| `cost_range` | `"30d"` | Active spend range (`1d`, `7d`, `30d`) |
| `cost_mode` | `"pct"` | Analytics breakdown (`pct` or `tokens`) |
| `adopt_existing` | `true` | Adopt existing daemon without spawning duplicates |

---

## Troubleshooting

### GNOME: Tray icon does not appear in top bar
GNOME 40+ does not display tray icons without an extension.
* **Fix**: Install and enable `gnome-shell-extension-appindicator` (pre-installed on Ubuntu; on Fedora/Arch/Debian install via your package manager or the Extensions app).

### Duplicate tray icon on KDE Plasma
OmniRoute incorporates multi-layer deduplication:
* If you see two icons on KDE Plasma, one is likely placed as a **standalone panel applet** and the other is inside your **System Tray**.
* **Fix**: Right-click the larger panel applet → **Remove from Panel**. Keep the one inside the System Tray for the best compact experience.
* Launching `omniroute-tray` on KDE automatically detects the active Plasmoid and exits without spawning a redundant Qt tray icon.

### Resetting KDE Plasma Cache
If widget changes do not appear immediately after an update:
```bash
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/qmlcache
kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell
```

---

## Contributing

Contributions, bug reports, and suggestions are welcome! Feel free to open an issue or submit a pull request on [GitHub](https://github.com/Susanthakuri92/omniroute-tray-linux).

---

## License

This project is licensed under the [MIT License](LICENSE).
