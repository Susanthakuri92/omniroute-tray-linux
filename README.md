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
- **Dedicated Updates Center**: A `🔄 Updates` tab with real, snapshot-driven version state — installed server version, tray version, and tray git commit — plus distinct one-click actions: **Check for Omniroute server updates** (queries the npm registry) and **Check for omniroute-tray updates** (pulls from GitHub, updates binaries, and syncs plasmoids). Shows a live *last checked* timestamp, an honest per-action status (checking / up to date / update available / registry unreachable / unknown installed version), and a **Copy update command** button that puts the exact `npm install -g omniroute@<version>` line on your clipboard.
- **Single-Instance Guarantee**: The installer is idempotent and refuses to create duplicate registrations, and the standalone tray takes an advisory file lock at startup so a second launch exits immediately instead of adding a second icon to the tray.
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

> **Safe to re-run at any time.** The installer is idempotent: every managed path is
> removed before it is recreated, so running it twice (or ten times) leaves exactly one
> binary symlink, one plasmoid registration, and one launcher. It never nests a
> plasmoid inside a plasmoid, never deletes a directory it does not own, and finishes
> with a verification pass that reports any duplicate it finds.

#### Desktop Compatibility & Distribution Matrix

| Distribution & Desktop | Status | What happens with the 1-Line Command | Extra Steps Needed? |
| :--- | :---: | :--- | :--- |
| **CachyOS / Arch Linux (KDE Plasma 6)** | 🟢 | Registers native widget, links CLI, reloads Plasma | **None! 100% Zero-touch out of the box.** |
| **Fedora KDE / openSUSE / KDE Neon** | 🟢 | Registers native widget, links CLI, reloads Plasma | **None! 100% Zero-touch out of the box.** |
| **Ubuntu Desktop (22.04 / 24.04)** | 🟡 | Installs files, links CLI, creates app launcher | `sudo apt install python3-pyside6` (Ubuntu includes AppIndicator by default) |
| **Linux Mint (Cinnamon, MATE, XFCE)** | 🟡 | Installs files, links CLI, creates app launcher | `sudo apt install python3-pyside6` |
| **Debian (XFCE / MATE / Cinnamon)** | 🟡 | Installs files, links CLI, creates app launcher | `sudo apt install python3-pyside6` |
| **Fedora Workstation (GNOME)** | 🟡 | Installs files, links CLI, creates app launcher | `sudo dnf install python3-pyside6 gnome-shell-extension-appindicator` |
| **Arch / CachyOS (Hyprland / Sway / i3)** | 🟡 | Installs files, links CLI, creates app launcher | `sudo pacman -S python-pyside6` + add `"tray"` module to Waybar |

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

- **KDE Plasma 6**: Open the tray popup and switch to the **🔄 Updates** tab. The tab header
  shows the installed versions and a badge that reads **All up to date**, **1 update available**,
  or **Check failed**. From there you can:

  | Action | What it does |
  | :--- | :--- |
  | **Check for Omniroute server updates** | Queries the npm registry for the latest published `omniroute` version and compares it against the version reported by your running server. |
  | **Check for omniroute-tray updates** | Pulls the latest commits from GitHub, re-links the CLI binary, and syncs the plasmoid. |

  Each card shows the installed version (with the tray's short git commit), a *Last checked*
  timestamp, and a status line with a colour-coded dot:

  * 🟡 **Checking…** — request in flight
  * 🟢 **Up to date (vX.Y.Z)** — the running version matches the registry
  * 🔵 **Update available: vX.Y.Z** — a newer release exists; the card also offers
    **Copy update command**, which copies `npm install -g omniroute@<version>` to your clipboard
  * 🔴 **Check failed** — the registry could not be reached, or the installed version could not
    be determined. The reason is displayed verbatim rather than being reported as "up to date".

- **GNOME / XFCE / Other DEs**: Right-click the system tray icon → **Settings…** and use
  **Check server updates** or **Update tray app** in the Updates section. The same version,
  commit, and status information is shown in the popover header.

> The tray never guesses. If it cannot determine a version, or the registry is unreachable, the
> UI says so explicitly instead of showing a green "up to date" badge.

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

### 4. Uninstalling

```bash
# If you installed with the one-line installer:
bash install.sh --uninstall
# or, from a cloned checkout:
./install.sh --uninstall
```

This removes the `omniroute-tray` binary symlink, the user plasmoid, the desktop launcher,
the cloned repository, and the QML cache, then rebuilds the KDE service cache. If a
system-wide copy of the plasmoid is also present, the uninstaller prints the `sudo rm -rf`
command needed to remove it — it will not touch system paths itself.

---

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

## Troubleshooting

### Duplicate tray icons / widget appears twice

OmniRoute incorporates multi-layer deduplication to prevent duplicate icons and processes:

**1. The widget is registered twice in Plasma.** This happens if OmniRoute ends up both as a
standalone panel applet *and* as an entry inside the system tray containment. Plasma stores both
in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`. The installer accurately checks containment
depth and warns if a duplicate is detected:

```
! OmniRoute appears twice in your panel: once as a standalone widget and once in the system tray.
```

**Fix:** right-click the redundant icon → **Remove from Panel**, or edit the system tray
settings and uncheck the entry under *Entries*.

**2. Standalone tray icon vs. Native Plasmoid on KDE.** On KDE Plasma, the native widget provides
the complete desktop experience. To prevent duplicate tray icons, launching `omniroute-tray` in GUI
mode (e.g. from the app menu or autostart) detects the active KDE widget and exits cleanly with `0`
instead of spawning a redundant PySide6 tray icon. (To force standalone mode on KDE, pass `--standalone`).
Enabling "Start on login" inside the Plasmoid automatically configures autostart to run `omniroute-tray --start`
(launching the server daemon only, with zero extra tray icons).

**3. A stale or system-wide install is shadowing the user install.** Two installs of the same
plasmoid ID (`org.omniroute.plasmoid`) will both load. Check for them:

```bash
ls -la ~/.local/share/plasma/plasmoids/org.omniroute.plasmoid        # user install (expected: a symlink)
ls -la /usr/share/plasma/plasmoids/org.omniroute.plasmoid            # system-wide (usually unwanted)
```

**Fix:**

```bash
# Re-run the installer — it removes and recreates the user paths atomically
bash install.sh

# Remove a system-wide copy (requires root)
sudo rm -rf /usr/share/plasma/plasmoids/org.omniroute.plasmoid

# Reset the QML cache and restart Plasma
rm -rf ~/.cache/qmlcache ~/.cache/plasmashell/qmlcache
kquitapp6 plasmashell; sleep 2; plasmashell &
```

Also worth checking: a leftover clone at `~/.local/share/omniroute-tray` that you no longer use.
The installer automatically cleans up stale clones of this repository.

### Two tray icons in GNOME / XFCE / a tiling WM

The standalone tray refuses to start a second copy. It takes an advisory lock on
`~/.local/share/omniroute-tray/tray.lock` at startup; a second launch prints

```
OmniRoute Tray is already running (pid 12345); focusing the existing instance.
```

and exits with status 0. The lock is held by the kernel, so a crashed or `kill -9`'d tray never
leaves a stale lock behind — the next launch starts normally. If you genuinely see two icons,
they are two different installs; find them with `which -a omniroute-tray` and
`pgrep -af omniroute_tray`.

---

## Contributing

Contributions, bug reports, and suggestions are welcome! Feel free to open an issue or submit a pull request.

---

## License

This project is licensed under the [MIT License](LICENSE).
