# OmniRoute Tray (Linux/KDE)

A Linux system-tray app and KDE Plasma 6 widget that supervises, monitors, and auto-updates the [OmniRoute](https://www.npmjs.com/package/omniroute). It replaces the manual workflow of starting `omniroute serve`, keeping it running across reboots, and updating it by hand.

Inspired by [zoispag/omniroute-tray](https://github.com/zoispag/omniroute-tray) (macOS).

## Screenshots

| | |
|---|---|
| ![Server View](screenshot/Screenshot_20260917_160202.png) | ![Monitor View](screenshot/Screenshot_20260917_160218.png) |
| ![Doctor & Logs](screenshot/Screenshot_20260917_160230.png) | ![Settings](screenshot/Screenshot_20260917_160239.png) |

## Features

- **Tray-only** — a rich popover card from the system tray, no extra windows.
- **KDE Plasma 6 widget** — native QML plasmoid with tabbed Server, Monitor, Doctor & Logs, and Settings views.
- **Supervised server** — spawns and keeps `omniroute serve` running, adopting an already-running instance instead of spawning a duplicate.
- **Live usage** — provider quota bars, Claude/Gemini/OpenAI session limits with reset countdowns (`% left` / `% used` toggle), and a 30-day cost breakdown.
- **Spend analytics** — 1D, 7D, 30D cost ranges with per-model breakdown and `%` vs `in/out` token toggle.
- **30-day trend** — interactive sparkline bar chart with hover tooltips.
- **Auto-update** — detects new OmniRoute releases via npm registry.
- **Start on login** — optional XDG autostart desktop entry.
- **Doctor & logs** — one-click diagnostics (Node, CLI, DB, loopback auth, server status) and server log viewer.
- **Flat vector icon** — crisp white hub & spokes with 6 color-changing outer points (red when running, white when stopped).

## Components

| Component | Description |
|---|---|
| `omniroute_tray.py` | PySide6 system-tray app with glassmorphic dark popover |
| `org.omniroute.plasmoid/` | KDE Plasma 6 QML widget (plasmoid) |
| `omniroute.svg` | App icon (white) |
| `omniroute_red.svg` | App icon (red, running state) |

> **Note**: This project was ported by [[Susanthakuri92]] to Linux. The tray app uses a native PySide6 system-tray icon and a QML-integrated popover card; the plasmoid is a native KDE Plasma 6 widget wrapper.

## Install

### System Tray App (PySide6)

**Requirements:** Python 3.10+, PySide6, OmniRoute CLI

```sh
# Ensure dependencies
pip install PySide6

# Install to user bin
install -m 755 omniroute_tray.py ~/.local/bin/omniroute-tray

# Run
omniroute-tray
```

### KDE Plasma 6 Widget

```sh
# Install the plasmoid
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r org.omniroute.plasmoid ~/.local/share/plasma/plasmoids/

# Reload the desktop shell to detect the widget
kquitapp6 plasmashell || killall plasmashell
plasmashell --replace &
```

Then add the "OmniRoute" widget to your panel: Right-click panel → **Add Widgets** → Search "OmniRoute".

### CLI Shortcuts

The tray app doubles as a CLI tool for external automation:

```sh
omniroute-tray --start       # Start server daemon
omniroute-tray --stop        # Stop all server processes
omniroute-tray --restart     # Restart daemon
omniroute-tray --snapshot    # JSON telemetry dump
omniroute-tray --toggle-autostart  # Toggle launch-on-login
```

## How it works

- The supervisor adopts `omniroute serve` if running on port 20128, or launches it.
- **Loopback**: Authenticated via `/etc/machine-id` HMAC-SHA256.
- **Plasmoid**: A thin frontend that invokes `omniroute-tray --snapshot` every 30s.

## Configuration

Settings live in `~/.config/omniroute-tray/settings.json`. The tray manages these internally via its Settings view.

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

## License

MIT
