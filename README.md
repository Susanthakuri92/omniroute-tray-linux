# OmniRoute Tray for Linux

<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="OmniRoute Logo" />
</p>

<p align="center">
  <strong>A system tray supervisor, telemetry dashboard, diagnostics tool, and auto-updater for <a href="https://www.npmjs.com/package/omniroute">OmniRoute</a> on Linux.</strong>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/Platform-Linux-blue?logo=linux" alt="Linux" /></a>
  <a href="#desktop-environment-support"><img src="https://img.shields.io/badge/Desktop-KDE%20Plasma%20%7C%20GNOME%20%7C%20XFCE%20%7C%20Wayland-brightgreen" alt="Desktops" /></a>
  <a href="#installation"><img src="https://img.shields.io/badge/Python-3.10%2B-blue?logo=python" alt="Python" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" /></a>
</p>

---

OmniRoute Tray replaces the manual terminal workflow of starting `omniroute`, keeping it alive across
logins, tailing logs, and upgrading by hand. It ships as two interfaces over one shared core:

1. **Native KDE Plasma 6 widget (Plasmoid)** — a tabbed popover built with native QML, integrated
   directly into your panel or system tray. Needs only Python 3 and Git; no PySide6, no Electron.
2. **Universal Qt tray (PySide6)** — a dark popover for **GNOME**, **XFCE**, **Cinnamon**, **MATE**,
   **LXQt**, and tiling Wayland/X11 compositors (**Hyprland**, **Sway**, **i3**).

Inspired by [zoispag/omniroute-tray](https://github.com/zoispag/omniroute-tray) (macOS).

---

## Screenshots

| 🖥️ Server Supervisor | 📊 Telemetry & Quotas | 🩺 Diagnostics & Logs |
| :---: | :---: | :---: |
| ![Server Tab](screenshot/Screenshot_20260917_160202.png) | ![Monitor Tab](screenshot/Screenshot_20260917_160218.png) | ![Doctor & Logs Tab](screenshot/Screenshot_20260917_160230.png) |

---

## Features

- **Process supervision & adoption** — start, stop, and restart the OmniRoute daemon. An already-running
  instance on port `20128` is adopted rather than duplicated.
- **Provider health & breakers** — live badge showing active providers and open circuit breakers.
- **Live quotas** — progress bars for Claude, OpenAI, Gemini, and custom providers, with reset
  countdowns and a `% left` / `% used` toggle.
- **Spend & token analytics** — 24-hour, 7-day, and 30-day aggregation with per-model breakdown,
  token counts, and `% share` toggles.
- **30-day trend sparkline** — daily spend chart with hover tooltips.
- **Doctor diagnostics** — one-click checks for the Node.js runtime, the OmniRoute CLI, SQLite
  database health, and loopback authorization.
- **Live log viewer** — streaming server log with a shortcut to open log files in your editor.
- **Updates center** — separate cards for the server and the tray, live version badges and commit
  hash, a one-click tray self-update from GitHub, and an update banner with a copyable
  `npm i -g omniroute@latest` command when a newer server release exists.
- **Single-instance protection** — kernel file locks and desktop-containment detection prevent
  duplicate tray icons.
- **Desktop autostart** — one-click toggle, implemented via XDG autostart.
- **Dynamic tray icon** — vector-rendered OmniRoute glyph, white when stopped and red when running.

---

## Desktop Environment Support

| Desktop Environment | Interface Mode | Prerequisites |
| :--- | :--- | :--- |
| **KDE Plasma 6** | Native Plasmoid | Python 3, Git (PySide6 **not** required) |
| **Ubuntu GNOME** | Standalone Qt Tray | `python3-pyside6` (AppIndicator support is built in) |
| **Fedora / Arch / Debian GNOME** | Standalone Qt Tray | `python3-pyside6` + AppIndicator extension |
| **XFCE / Cinnamon / MATE / LXQt** | Standalone Qt Tray | `python3-pyside6` |
| **Hyprland / Sway / i3** | Standalone Qt Tray | `python3-pyside6` (shows in Waybar/Polybar/i3bar) |

---

## Installation

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/install.sh | bash
```

The installer is safe to re-run; it updates existing files in place without duplicating applets or
nested folders. It will:

- Clone or update the repository in `~/.local/share/omniroute-tray`
- Symlink the CLI to `~/.local/bin/omniroute-tray`
- Register the Plasma 6 Plasmoid to `~/.local/share/plasma/plasmoids/`
- Create the application menu entry and brand icons, then refresh Plasma Shell if it is running

### Setup by desktop environment

**KDE Plasma 6** — run the quick install, then right-click your panel → **Add Widgets…**, search for
**OmniRoute**, and drag it into your panel or System Tray.

**GNOME, XFCE, Cinnamon, MATE, LXQt, and tiling compositors** — install PySide6:

```bash
sudo apt install python3-pyside6        # Ubuntu / Debian
sudo dnf install python3-pyside6        # Fedora
sudo pacman -S python-pyside6           # Arch / CachyOS / Manjaro
```

GNOME also needs AppIndicator support: it is included on Ubuntu, and available elsewhere via the
`gnome-shell-extension-appindicator` package or the Extensions app. Launch **OmniRoute Tray** from
your application menu, or run `omniroute-tray &`.

For Waybar, ensure `"tray"` is in your modules list; for Hyprland/Sway/i3, autostart with
`exec-once = ~/.local/bin/omniroute-tray`.

### Manual install (from Git)

```bash
git clone https://github.com/Susanthakuri92/omniroute-tray-linux.git ~/.local/share/omniroute-tray
cd ~/.local/share/omniroute-tray && ./install.sh
```

---

## Updating

Use the **Updates** tab in the tray popover: **Check for Tray Updates** pulls the latest code from
GitHub, **Check for Updates** queries npm for newer server releases, and **GitHub ↗** opens either
repository. From a terminal:

```bash
omniroute-tray --update-tray
```

---

## Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/Susanthakuri92/omniroute-tray-linux/main/uninstall.sh | bash
```

Or, from a local installation, `~/.local/share/omniroute-tray/uninstall.sh` (equivalently,
`install.sh --uninstall`).

The uninstaller stops running processes and removes the CLI symlink, the Plasma widget, the menu and
autostart entries, the installed icons, and the cloned repository, then clears the QML cache and
refreshes the desktop databases. Your configuration and logs are kept unless you pass `--purge`.

---

## CLI Reference

| Command | Action |
| :--- | :--- |
| `omniroute-tray --start` | Start the OmniRoute server daemon in the background |
| `omniroute-tray --stop` | Gracefully stop all OmniRoute processes |
| `omniroute-tray --restart` | Restart the OmniRoute server daemon |
| `omniroute-tray --cost --range 1d` | JSON dump of 24-hour spend by model |
| `omniroute-tray --cost --range 7d` | JSON dump of 7-day spend by model |
| `omniroute-tray --cost --range 30d` | JSON dump of 30-day spend by model |
| `omniroute-tray --snapshot` | Full telemetry JSON snapshot (health, quotas, rates, cost) |
| `omniroute-tray --update-tray` | Pull the latest code from GitHub and sync the desktop widgets |
| `omniroute-tray --toggle-autostart` | Toggle start on desktop login |

---

## Configuration

Settings live at `~/.config/omniroute-tray/settings.json`:

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
| `cost_range` | `"30d"` | Active spend range (`1d`, `7d`, `30d`, `today`, `yesterday`) |
| `cost_mode` | `"pct"` | Analytics breakdown (`pct` or `tokens`) |
| `adopt_existing` | `true` | Adopt an existing daemon instead of spawning a duplicate |
| `hidden_sections` | `[]` | Section IDs hidden in the Monitor tab |

---

## Troubleshooting

**GNOME: no tray icon.** GNOME 40+ hides tray icons without an extension. Install and enable
`gnome-shell-extension-appindicator` (pre-installed on Ubuntu).

**KDE Plasma: duplicate tray icon.** One icon is likely a standalone panel applet and the other is
inside your System Tray. Right-click the standalone applet → **Remove from Panel** and keep the
System Tray one. Launching `omniroute-tray` on KDE detects an active Plasmoid and exits rather than
adding a redundant Qt icon.

**KDE Plasma: widget changes do not appear after an update.** Clear the QML cache and restart the
shell:

```bash
rm -rf ~/.cache/plasmashell/qmlcache ~/.cache/qmlcache
kbuildsycoca6 --noincremental
systemctl --user restart plasma-plasmashell
```

---

## Contributing

Bug reports, suggestions, and pull requests are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, or open an issue on
[GitHub](https://github.com/Susanthakuri92/omniroute-tray-linux).

---

## License

Released under the [MIT License](LICENSE).
