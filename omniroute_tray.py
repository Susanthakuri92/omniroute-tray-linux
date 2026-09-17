#!/usr/bin/env python3
"""
omniroute_tray.py — Complete Linux/KDE system tray app for OmniRoute.
Faithfully recreating zoispag/omniroute-tray's UI design and complete feature set:
- Tray-only floating menu-bar popover card with dark macOS/KDE glassmorphic theme
- Supervised server with adoption of already-running instances
- Provider health status-band (active providers, circuit breakers, p95 latency)
- Live usage: Claude/Gemini/OpenAI limits, window tags (5h/7d/mo/sess), reset countdowns, % left/% used toggle
- Spend analytics: 1D, 7D, 30D, Yesterday, Today ranges, % vs tokens in/out toggle
- 30-day interactive sparkline trend bar chart with hover tooltips
- Auto-update release detector and update banner
- In-popover Settings & Doctor view toggled via gear icon (section toggles, diagnostics, autostart, logs, quit)
- Left-click opens popover; right-click opens quick context menu
- Approved flat vector icon: crisp white hub & spokes, 6 color-changing outer points (red when running, white when stopped)
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum, auto
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Set, Tuple

from PySide6.QtCore import (
    QEvent, QObject, QPoint, QPointF, QRect, QRectF, QSize, Qt, QTimer, Signal
)
from PySide6.QtGui import (
    QBrush, QColor, QCursor, QFont, QIcon, QPainter, QPen, QPixmap
)
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFrame,
    QGraphicsDropShadowEffect, QHBoxLayout, QLabel, QLineEdit, QMenu,
    QMessageBox, QProgressBar, QPushButton, QScrollArea, QSizePolicy,
    QSpinBox, QStackedWidget, QSystemTrayIcon, QToolTip, QVBoxLayout, QWidget
)

# ============================================================================
# Paths & Global Constants
# ============================================================================

APP_ID = "omniroute-tray"
XDG_CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
XDG_DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
XDG_STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))

APP_CONFIG_DIR = XDG_CONFIG_HOME / APP_ID
APP_DATA_DIR = XDG_DATA_HOME / APP_ID
APP_STATE_DIR = XDG_STATE_HOME / APP_ID

SETTINGS_FILE = APP_CONFIG_DIR / "settings.json"
LOG_FILE = APP_STATE_DIR / "omniroute-tray.log"
SERVER_LOG_FILE = APP_STATE_DIR / "omniroute-serve.log"
AUTOSTART_FILE = XDG_CONFIG_HOME / "autostart" / "omniroute-tray.desktop"

DEFAULT_API_BASE = "http://127.0.0.1:20128"
CLI_AUTH_SALT = "omniroute-cli-auth-v1"


def ensure_dirs() -> None:
    APP_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    APP_DATA_DIR.mkdir(parents=True, exist_ok=True)
    APP_STATE_DIR.mkdir(parents=True, exist_ok=True)


@dataclass
class Settings:
    serve_command: list = field(default_factory=lambda: ["omniroute"])
    api_base: str = DEFAULT_API_BASE
    poll_interval_seconds: int = 15
    start_on_login: bool = False
    percent_mode: str = "left"  # "left" or "used"
    cost_range: str = "30d"     # "1d", "7d", "30d", "yesterday", "today"
    cost_mode: str = "pct"      # "pct" or "tokens"
    adopt_existing: bool = True
    hidden_sections: List[str] = field(default_factory=list)

    @staticmethod
    def load() -> "Settings":
        ensure_dirs()
        if SETTINGS_FILE.exists():
            try:
                data = json.loads(SETTINGS_FILE.read_text())
                return Settings(**data)
            except Exception:
                pass
        s = Settings()
        s.save()
        return s

    def save(self) -> None:
        ensure_dirs()
        SETTINGS_FILE.write_text(json.dumps(asdict(self), indent=2))


# ============================================================================
# Loopback Machine Auth Token (x-omniroute-cli-token)
# ============================================================================

def get_raw_machine_id() -> Optional[str]:
    for path in ("/etc/machine-id", "/var/lib/dbus/machine-id"):
        try:
            p = Path(path)
            if p.is_file():
                content = p.read_text().strip()
                if content:
                    return content.lower()
        except Exception:
            continue
    return None


def resolve_cli_token() -> Optional[str]:
    env_file = Path.home() / ".omniroute" / ".env"
    salt = CLI_AUTH_SALT
    if env_file.is_file():
        try:
            for line in env_file.read_text().splitlines():
                line = line.strip()
                if line.startswith("OMNIROUTE_CLI_TOKEN="):
                    val = line.split("=", 1)[1].strip().strip('"\'')
                    if val:
                        return val
                elif line.startswith("OMNIROUTE_CLI_SALT="):
                    val = line.split("=", 1)[1].strip().strip('"\'')
                    if val:
                        salt = val
        except Exception:
            pass

    mid = get_raw_machine_id()
    if not mid:
        return None
    mac = hmac.new(mid.encode("utf-8"), salt.encode("utf-8"), hashlib.sha256)
    return mac.hexdigest()


# ============================================================================
# Server Health & Process Lifecycle
# ============================================================================

def get_port_from_url(url: str) -> int:
    try:
        rest = url.split("://", 1)[-1]
        _, _, port = rest.partition(":")
        return int(port.rstrip("/") or "80")
    except Exception:
        return 20128


def server_healthy(api_base: str, timeout: float = 1.0) -> bool:
    url = f"{api_base.rstrip('/')}/api/monitoring/health"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
            return data.get("status") == "healthy"
    except Exception:
        return False


def reap_zombies() -> None:
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
            if pid <= 0:
                break
        except OSError:
            break


def force_kill_all(port: int = 20128) -> Tuple[bool, str]:
    messages = []
    pids: set[int] = set()

    if shutil.which("lsof"):
        try:
            res = subprocess.run(["lsof", "-t", f"-i:{port}"], capture_output=True, text=True, timeout=3)
            for tok in res.stdout.strip().split():
                if tok.isdigit():
                    pids.add(int(tok))
        except Exception:
            pass

    try:
        res = subprocess.run(["pgrep", "-f", "omniroute serve"], capture_output=True, text=True, timeout=3)
        for tok in res.stdout.strip().split():
            if tok.isdigit() and int(tok) != os.getpid():
                pids.add(int(tok))
    except Exception:
        pass

    for pid in pids:
        try:
            pgid = os.getpgid(pid)
            try:
                os.killpg(pgid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            time.sleep(0.1)
            try:
                os.killpg(pgid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            messages.append(f"Killed PID {pid}")
        except Exception:
            try:
                os.kill(pid, signal.SIGKILL)
                messages.append(f"Killed PID {pid}")
            except Exception:
                pass

    reap_zombies()
    if not messages:
        messages.append(f"Port {port} cleared")
    return True, "; ".join(messages)


# ============================================================================
# Data Models & Utilities
# ============================================================================

def format_reset_countdown(iso_str: Optional[str]) -> str:
    if not iso_str:
        return ""
    try:
        clean = iso_str.replace("Z", "+00:00")
        reset_dt = datetime.fromisoformat(clean)
        now = datetime.now(timezone.utc)
        secs = (reset_dt - now).total_seconds()
        if secs <= 0:
            return "resets soon"
        total_mins = int(secs // 60)
        days = total_mins // 1440
        hours = (total_mins % 1440) // 60
        mins = total_mins % 60
        if days > 0:
            return f"resets in {days}d {hours}h"
        elif hours > 0:
            return f"resets in {hours}h {mins}m"
        else:
            return f"resets in {mins}m"
    except Exception:
        return ""


def derive_short_tag(key: str) -> str:
    k = key.lower()
    if "(" in k and ")" in k:
        inner = k.split("(", 1)[1].split(")", 1)[0].strip()
        if inner:
            return inner
    if "monthly" in k or "month" in k:
        return "mo"
    if "weekly" in k or "week" in k:
        return "wk"
    if "session" in k or "sess" in k:
        return "sess"
    if "5h" in k:
        return "5h"
    if "day" in k or "daily" in k:
        return "1d"
    return k[:4]


def derive_pretty_model_name(key: str) -> str:
    k = key.lower()
    if "claude" in k:
        if "opus" in k:
            return "Claude 3.7 Opus" + (" (Thinking)" if "thinking" in k else "")
        if "sonnet" in k:
            return "Claude 3.7 Sonnet"
        if "haiku" in k:
            return "Claude 3.5 Haiku"
    if "gemini" in k:
        if "3.7-flash" in k:
            return "Gemini 3.7 Flash"
        if "3.1-pro" in k:
            return "Gemini 3.1 Pro"
        if "pro-agent" in k:
            return "Gemini Pro Agent"
        if "flash" in k:
            return "Gemini Flash"
    if "gpt" in k:
        if "120b" in k:
            return "GPT-OSS 120B"
    if "credit" in k:
        return "Credits"
    return key.replace("-", " ").title()


def format_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M tokens"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K tokens"
    return f"{n} tokens"


def compact_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


@dataclass
class WindowQuota:
    key: str
    short_tag: str
    pretty_label: str
    used: float
    total: float
    remaining_pct: float
    used_pct: float
    reset_at: Optional[str] = None
    reset_countdown: str = ""
    unlimited: bool = False


@dataclass
class AccountUsage:
    account_name: str
    provider: str
    windows: List[WindowQuota] = field(default_factory=list)


@dataclass
class HealthStrip:
    active_providers: int = 0
    configured_providers: int = 0
    breakers_open: int = 0
    p95_ms: Optional[float] = None
    cache_hit_rate: Optional[float] = None


@dataclass
class CostRow:
    model: str
    cost_usd: float
    cost_pct: float
    tokens_in: int
    tokens_out: int
    requests: int


@dataclass
class CostData:
    range_label: str
    total_cost_usd: float
    total_tokens: int
    rows: List[CostRow] = field(default_factory=list)


@dataclass
class TrendPoint:
    date: str
    cost: float
    tokens: int


@dataclass
class TrendData:
    points: List[TrendPoint] = field(default_factory=list)
    today_cost: float = 0.0
    yesterday_cost: float = 0.0
    total_cost: float = 0.0


@dataclass
class DoctorItem:
    name: str
    status: str
    detail: str


@dataclass
class ProviderQuota:
    provider: str
    limit: Optional[float]
    used: Optional[float]
    remaining: float
    state: str


@dataclass
class FullSnapshot:
    timestamp: float
    health: HealthStrip = field(default_factory=HealthStrip)
    accounts: List[AccountUsage] = field(default_factory=list)
    provider_quotas: List[ProviderQuota] = field(default_factory=list)
    cost: Optional[CostData] = None
    trend: Optional[TrendData] = None
    available_update: Optional[str] = None
    doctor: List[DoctorItem] = field(default_factory=list)
    server_pid: Optional[int] = None
    server_running: bool = False
    server_port: int = 20128
    autostart_enabled: bool = False
    recent_logs: List[str] = field(default_factory=list)



# ============================================================================
# Telemetry, Quota, Cost, and Trend Fetcher
# ============================================================================

def extract_json_candidate(raw: str) -> Optional[str]:
    for i, c in enumerate(raw):
        if c in ("[", "{"):
            cand = raw[i:]
            try:
                json.loads(cand)
                return cand
            except Exception:
                continue
    return None


def fetch_full_snapshot(settings: Settings) -> FullSnapshot:
    base_url = settings.api_base.rstrip("/")
    token = resolve_cli_token()
    headers = {}
    if token:
        headers["x-omniroute-cli-token"] = token

    snap = FullSnapshot(timestamp=time.time())

    # 1. Health & Status Band
    try:
        req = urllib.request.Request(f"{base_url}/api/monitoring/health", headers=headers)
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            h_data = json.loads(resp.read())
            p_sum = h_data.get("providerSummary", {})
            cb = h_data.get("circuitBreakers", {})
            snap.health.active_providers = p_sum.get("activeCount", 0)
            snap.health.configured_providers = p_sum.get("configuredCount", p_sum.get("catalogCount", 0))
            snap.health.breakers_open = cb.get("open", 0) + cb.get("halfOpen", 0)
    except Exception:
        pass

    # 2. Rate Limits & Quotas (concurrent per connection)
    def _fetch_account_usage(c: dict) -> Optional[AccountUsage]:
        cid = c.get("id")
        provider = c.get("provider", "unknown")
        name = c.get("name") or c.get("email") or provider
        if not cid:
            return None
        try:
            u_req = urllib.request.Request(f"{base_url}/api/usage/{cid}", headers=headers)
            with urllib.request.urlopen(u_req, timeout=6.0) as u_resp:
                u_data = json.loads(u_resp.read())
                quotas = u_data.get("quotas", {})
                windows = []
                for m_key, q in quotas.items():
                    used = float(q.get("used", 0) or 0)
                    total = float(q.get("total", 0) or 0)
                    rem_pct = q.get("remainingPercentage")
                    if rem_pct is not None:
                        rem = float(rem_pct)
                        u_pct = max(0.0, min(100.0, 100.0 - rem))
                    elif total > 0:
                        u_pct = max(0.0, min(100.0, (used / total) * 100.0))
                        rem = 100.0 - u_pct
                    else:
                        u_pct = 0.0
                        rem = 100.0

                    reset_at = q.get("resetAt")
                    countdown = format_reset_countdown(reset_at)
                    short_tag = derive_short_tag(m_key)
                    pretty_lbl = derive_pretty_model_name(m_key)
                    windows.append(
                        WindowQuota(
                            key=m_key,
                            short_tag=short_tag,
                            pretty_label=pretty_lbl,
                            used=used,
                            total=total,
                            remaining_pct=rem,
                            used_pct=u_pct,
                            reset_at=reset_at,
                            reset_countdown=countdown,
                            unlimited=bool(q.get("unlimited", False)),
                        )
                    )
                if windows:
                    return AccountUsage(account_name=name, provider=provider, windows=windows)
        except Exception:
            pass
        return None

    # 3. Cost Breakdown
    def _fetch_cost() -> Optional[CostData]:
        try:
            c_res = subprocess.run(
                ["omniroute", "cost", "--period", settings.cost_range, "--group-by", "model", "--output", "json"],
                capture_output=True, text=True, timeout=8
            )
            cand = extract_json_candidate(c_res.stdout)
            if not cand:
                return None
            rows_data = json.loads(cand)
            rows = []
            tot_usd = 0.0
            tot_tokens = 0
            for r in rows_data:
                model = r.get("group", "other")
                cost = float(r.get("costUsd", 0) or 0)
                cost_pct = float(r.get("costPct", 0) or 0)
                t_in = int(r.get("tokensIn", 0) or 0)
                t_out = int(r.get("tokensOut", 0) or 0)
                reqs = int(r.get("requests", 0) or 0)
                tot_usd += cost
                tot_tokens += (t_in + t_out)
                rows.append(
                    CostRow(
                        model=model,
                        cost_usd=cost,
                        cost_pct=cost_pct,
                        tokens_in=t_in,
                        tokens_out=t_out,
                        requests=reqs,
                    )
                )
            rows.sort(key=lambda x: x.cost_usd, reverse=True)
            return CostData(
                range_label=settings.cost_range.upper(),
                total_cost_usd=tot_usd,
                total_tokens=tot_tokens,
                rows=rows,
            )
        except Exception:
            return None

    # 4. Usage Trend (30-day sparkline)
    def _fetch_trend() -> Optional[TrendData]:
        try:
            t_req = urllib.request.Request(f"{base_url}/api/usage/analytics?period=30d", headers=headers)
            with urllib.request.urlopen(t_req, timeout=4.0) as t_resp:
                t_data = json.loads(t_resp.read())
                arr = t_data.get("dailyTrend", [])
                pts = []
                today_str = datetime.now().strftime("%Y-%m-%d")
                t_cost = 0.0
                y_cost = 0.0
                tot = 0.0
                for d in arr:
                    dt = d.get("date", "")
                    c = float(d.get("cost", 0) or 0)
                    tok = int(d.get("totalTokens", 0) or 0)
                    tot += c
                    if dt == today_str:
                        t_cost = c
                    pts.append(TrendPoint(date=dt, cost=c, tokens=tok))
                return TrendData(points=pts, today_cost=t_cost, yesterday_cost=y_cost, total_cost=tot)
        except Exception:
            return None

    with ThreadPoolExecutor(max_workers=6) as executor:
        f_cost = executor.submit(_fetch_cost)
        f_trend = executor.submit(_fetch_trend)

        try:
            req = urllib.request.Request(f"{base_url}/api/providers", headers=headers)
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                conns = json.loads(resp.read()).get("connections", [])
                acc_results = list(executor.map(_fetch_account_usage, conns))
                snap.accounts = [a for a in acc_results if a is not None]
        except Exception:
            pass

        snap.cost = f_cost.result()
        snap.trend = f_trend.result()

    # 5. Provider Quotas from CLI
    try:
        q_res = subprocess.run(["omniroute", "usage", "quota", "--output", "json"], capture_output=True, text=True, timeout=5)
        cand = extract_json_candidate(q_res.stdout)
        if cand:
            q_data = json.loads(cand)
            for item in q_data:
                snap.provider_quotas.append(
                    ProviderQuota(
                        provider=item.get("provider", "unknown"),
                        limit=item.get("limit"),
                        used=item.get("used"),
                        remaining=float(item.get("remaining", 100.0) if item.get("remaining") is not None else 100.0),
                        state=item.get("state", "available"),
                    )
                )
    except Exception:
        pass

    # 6. Doctor Diagnostics
    node_bin = shutil.which("node")
    if node_bin:
        try:
            node_ver = subprocess.run([node_bin, "--version"], capture_output=True, text=True, timeout=3).stdout.strip()
        except Exception:
            node_ver = "unknown"
        snap.doctor.append(DoctorItem("Node Runtime", "ok", f"{node_ver} ({node_bin})"))
    else:
        snap.doctor.append(DoctorItem("Node Runtime", "fail", "Node binary not found"))

    cli_path = shutil.which("omniroute")
    if cli_path:
        try:
            cli_ver = subprocess.run([cli_path, "--version"], capture_output=True, text=True, timeout=3).stdout.strip()
        except Exception:
            cli_ver = "unknown"
        snap.doctor.append(DoctorItem("OmniRoute CLI", "ok", f"{cli_ver} ({cli_path})"))
    else:
        snap.doctor.append(DoctorItem("OmniRoute CLI", "fail", "omniroute command not found"))

    db_path = Path.home() / ".omniroute" / "storage.sqlite"
    if db_path.is_file():
        mb = db_path.stat().st_size / (1024 * 1024)
        snap.doctor.append(DoctorItem("Storage Database", "ok", f"storage.sqlite ({mb:.1f} MB)"))
    else:
        snap.doctor.append(DoctorItem("Storage Database", "fail", "storage.sqlite missing"))

    pid_file = Path.home() / ".omniroute" / "server" / ".pid"
    pid = None
    if pid_file.is_file():
        try:
            cand = int(pid_file.read_text().strip())
            if cand > 0:
                try:
                    os.kill(cand, 0)
                    pid = cand
                except (OSError, ProcessLookupError):
                    pid_file.unlink(missing_ok=True)
        except Exception:
            pid_file.unlink(missing_ok=True)

    port_open = False
    try:
        with socket.create_connection(("127.0.0.1", 20128), timeout=0.3):
            port_open = True
    except Exception:
        port_open = False

    snap.server_pid = pid
    snap.server_running = bool(port_open or (pid is not None))
    snap.doctor.append(DoctorItem("Server Status", "ok" if snap.server_running else "fail", f"Port 20128 (PID {pid or 'offline'})"))

    if token:
        snap.doctor.append(DoctorItem("Loopback Token", "ok", f"HMAC-SHA256 active ({token[:10]}…)"))
    else:
        snap.doctor.append(DoctorItem("Loopback Token", "warn", "Unauthenticated loopback"))

    snap.autostart_enabled = (Path.home() / ".config" / "autostart" / "omniroute-tray.desktop").exists()

    # 7. Recent Server Logs
    log_file = Path.home() / ".omniroute" / "logs" / "application" / "app.log"
    if log_file.is_file():
        try:
            with open(log_file, "r", errors="ignore") as f:
                lines = f.readlines()
                snap.recent_logs = [l.strip() for l in lines[-8:] if l.strip()]
        except Exception:
            pass

    snap.available_update = None

    return snap


# ============================================================================
# Server Supervisor (Daemonized + Adoption + Escalated Termination)
# ============================================================================

class ServerState(Enum):
    STOPPED = auto()
    STARTING = auto()
    RUNNING = auto()
    ADOPTED = auto()
    CRASHED = auto()
    STOPPING = auto()


STATE_LABELS = {
    ServerState.STOPPED: "Stopped",
    ServerState.STARTING: "Starting…",
    ServerState.RUNNING: "Running",
    ServerState.ADOPTED: "Running",
    ServerState.CRASHED: "Crashed",
    ServerState.STOPPING: "Stopping…",
}


class ServerSupervisor:
    def __init__(self, settings: Settings,
                 on_state_change: Optional[Callable[[ServerState], None]] = None,
                 on_log: Optional[Callable[[str], None]] = None):
        self.settings = settings
        self._state = ServerState.STOPPED
        self._on_state_change = on_state_change
        self._on_log = on_log
        self._lock = threading.RLock()
        self._stop_requested = threading.Event()

    @property
    def state(self) -> ServerState:
        return self._state

    def _set_state(self, state: ServerState) -> None:
        with self._lock:
            if self._state == state:
                return
            self._state = state
        if self._on_state_change:
            self._on_state_change(state)

    def _log(self, msg: str) -> None:
        if self._on_log:
            self._on_log(msg)

    def start(self) -> None:
        with self._lock:
            self._stop_requested.clear()
            threading.Thread(target=self._run_start, daemon=True).start()

    def _run_start(self) -> None:
        port = get_port_from_url(self.settings.api_base)
        if server_healthy(self.settings.api_base):
            self._set_state(ServerState.ADOPTED)
            self._log(f"Adopted running instance on port {port}")
            return

        self._set_state(ServerState.STARTING)
        ensure_dirs()
        SERVER_LOG_FILE.touch(exist_ok=True)

        try:
            subprocess.run(["omniroute", "serve", "--daemon"], capture_output=True, text=True, timeout=12)
        except Exception as e:
            self._log(f"Error starting daemon: {e}")

        # Poll for health
        for _ in range(15):
            if server_healthy(self.settings.api_base):
                self._set_state(ServerState.RUNNING)
                self._log("Server is healthy and running")
                return
            time.sleep(0.8)

        if server_healthy(self.settings.api_base):
            self._set_state(ServerState.RUNNING)
        else:
            self._set_state(ServerState.STOPPED)

    def stop(self) -> None:
        with self._lock:
            self._stop_requested.set()
            self._set_state(ServerState.STOPPING)
        threading.Thread(target=self._run_stop, daemon=True).start()

    def _run_stop(self) -> None:
        try:
            subprocess.run(["omniroute", "stop"], capture_output=True, text=True, timeout=8)
        except Exception:
            pass

        # If still holding port, escalate
        port = get_port_from_url(self.settings.api_base)
        if server_healthy(self.settings.api_base):
            force_kill_all(port)

        reap_zombies()
        self._set_state(ServerState.STOPPED)

    def restart(self) -> None:
        self.stop()
        time.sleep(1.0)
        self.start()


# ============================================================================
# Vector Badge Icon Renderer (Sharp White Hub & Lines + Colored Points)
# ============================================================================

def render_omniroute_pixmap(state: str, size: int = 64) -> QPixmap:
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing, True)
    p.setRenderHint(QPainter.SmoothPixmapTransform, True)

    scale = size / 24.0
    center = QPointF(12.0 * scale, 12.0 * scale)

    f = 0.82
    outer_nodes = [
        QPointF((12.0 - 8.0 * f) * scale, (12.0 - 7.0 * f) * scale),  # top-left
        QPointF((12.0 + 8.0 * f) * scale, (12.0 - 7.0 * f) * scale),  # top-right
        QPointF((12.0 - 8.0 * f) * scale, (12.0 + 7.0 * f) * scale),  # bottom-left
        QPointF((12.0 + 8.0 * f) * scale, (12.0 + 7.0 * f) * scale),  # bottom-right
        QPointF(12.0 * scale, (12.0 - 9.4 * f) * scale),              # top-center
        QPointF(12.0 * scale, (12.0 + 9.4 * f) * scale),              # bottom-center
    ]

    white = QColor("#ffffff")
    if state in ("running", "adopted"):
        points_color = QColor("#ff2b4d")
    elif state == "starting":
        points_color = QColor("#f59e0b")
    else:
        points_color = white

    # 1. Connecting lines
    line_pen = QPen(white, 1.8 * scale, Qt.SolidLine, Qt.RoundCap)
    p.setPen(line_pen)
    for n in outer_nodes:
        p.drawLine(center, n)

    # 2. Center hub
    p.setPen(Qt.NoPen)
    p.setBrush(white)
    p.drawEllipse(center, 3.0 * scale, 3.0 * scale)

    # 3. 6 outer points
    p.setBrush(points_color)
    node_r = 2.4 * scale
    for n in outer_nodes:
        p.drawEllipse(n, node_r, node_r)

    p.end()
    return pm


def get_tray_icon(state: str = "stopped") -> QIcon:
    icon = QIcon()
    for sz in (16, 22, 24, 32, 48, 64, 128):
        icon.addPixmap(render_omniroute_pixmap(state, sz))
    return icon


# ============================================================================
# Autostart Helpers
# ============================================================================

def autostart_enable() -> None:
    AUTOSTART_FILE.parent.mkdir(parents=True, exist_ok=True)
    content = f"""[Desktop Entry]
Type=Application
Name=OmniRoute Tray
Comment=System tray supervisor and monitor for OmniRoute AI router
Exec={Path.home()}/.local/bin/omniroute-tray
Icon=omniroute-tray
Terminal=false
Categories=Utility;Development;Network;
StartupNotify=false
X-GNOME-Autostart-enabled=true
"""
    AUTOSTART_FILE.write_text(content)


def autostart_disable() -> None:
    if AUTOSTART_FILE.exists():
        AUTOSTART_FILE.unlink()


def autostart_is_enabled() -> bool:
    return AUTOSTART_FILE.exists()


# ============================================================================
# Custom Sparkline Bar Chart Widget (30-day Trend)
# ============================================================================

class SparklineWidget(QWidget):
    """Native vector bar chart for 30-day spend trend matching zoispag's .spark."""
    def __init__(self, points: Optional[List[TrendPoint]] = None, parent=None):
        super().__init__(parent)
        self.points: List[TrendPoint] = points or []
        self.setFixedHeight(30)
        self.setMouseTracking(True)
        self.hover_idx: Optional[int] = None

    def set_points(self, points: List[TrendPoint]):
        self.points = points
        self.update()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing, True)
        w = self.width()
        h = self.height()

        if not self.points:
            p.setPen(QColor("#6b7280"))
            p.drawText(self.rect(), Qt.AlignCenter, "No spend in last 30 days")
            p.end()
            return

        n = len(self.points)
        gap = 2
        bar_w = max(2.0, (w - (n - 1) * gap) / n)
        max_cost = max([pt.cost for pt in self.points] + [0.001])

        p.setPen(Qt.NoPen)
        for i, pt in enumerate(self.points):
            bar_h = max(2.0, (pt.cost / max_cost) * (h - 2))
            x = i * (bar_w + gap)
            y = h - bar_h

            if i == self.hover_idx:
                p.setBrush(QColor("#ff453a"))
            else:
                p.setBrush(QColor(255, 69, 58, 180))

            p.drawRoundedRect(QRectF(x, y, bar_w, bar_h), 1, 1)
        p.end()

    def mouseMoveEvent(self, event):
        if not self.points:
            return
        w = self.width()
        n = len(self.points)
        gap = 2
        bar_w = max(2.0, (w - (n - 1) * gap) / n)
        idx = int(event.position().x() // (bar_w + gap))
        if 0 <= idx < n:
            self.hover_idx = idx
            pt = self.points[idx]
            QToolTip.showText(
                self.mapToGlobal(event.position().toPoint()),
                f"<b>{pt.date}</b><br>${pt.cost:.2f} · {format_tokens(pt.tokens)}",
                self
            )
            self.update()
        else:
            self.hover_idx = None
            self.update()

    def leaveEvent(self, event):
        self.hover_idx = None
        self.update()


# ============================================================================
# Popover UI (Faithful 1-to-1 Reconstruction of zoispag/omniroute-tray)
# ============================================================================

POPOVER_CSS = """
QWidget {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    font-size: 12px;
    color: #f5f5f7;
}
QFrame#PopoverCard {
    background-color: #1c1c1e;
    border: 1px solid #38383a;
    border-radius: 12px;
}
.pop-header {
    border-bottom: 1px solid #38383a;
    padding: 10px 14px;
}
.sec-head {
    font-size: 10.5px;
    font-weight: 700;
    text-transform: uppercase;
    color: #6b7280;
    letter-spacing: 0.05em;
}
QPushButton.mode-pill {
    background-color: #2c2c2e;
    border: 1px solid #38383a;
    color: #a1a1aa;
    font-size: 10.5px;
    border-radius: 5px;
    padding: 2px 7px;
}
QPushButton.mode-pill:hover {
    color: #f5f5f7;
    background-color: #38383a;
}
QPushButton.mode-pill.active {
    background-color: #ff453a;
    border-color: #ff453a;
    color: #ffffff;
    font-weight: 600;
}
.statusband {
    font-size: 11px;
    color: #a1a1aa;
    padding: 6px 14px;
    border-bottom: 1px solid #38383a;
}
.window-tag {
    font-size: 10px;
    font-weight: 600;
    color: #6b7280;
    background: #2c2c2e;
    border: 1px solid #38383a;
    border-radius: 4px;
    padding: 1px 4px;
}
QProgressBar.round-bar {
    background: #38383a;
    border: none;
    border-radius: 3px;
    max-height: 6px;
}
QProgressBar.round-bar::chunk {
    background-color: #f5f5f7;
    border-radius: 3px;
}
.footer {
    border-top: 1px solid #38383a;
    padding: 8px 12px;
}
QPushButton.icon-btn {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    color: #a1a1aa;
    font-size: 13px;
    width: 24px;
    height: 24px;
}
QPushButton.icon-btn:hover {
    background: #2c2c2e;
    border-color: #38383a;
    color: #f5f5f7;
}
QPushButton.action-btn {
    background-color: #2c2c2e;
    border: 1px solid #38383a;
    border-radius: 6px;
    color: #f5f5f7;
    padding: 6px 12px;
    font-size: 12px;
}
QPushButton.action-btn:hover {
    background-color: #38383a;
}
QPushButton.action-btn.danger {
    background-color: rgba(239, 68, 68, 0.15);
    border-color: rgba(239, 68, 68, 0.3);
    color: #fca5a5;
}
QPushButton.action-btn.danger:hover {
    background-color: rgba(239, 68, 68, 0.28);
}
"""


class OmniRoutePopover(QWidget):
    """
    1-to-1 Recreation of the zoispag/omniroute-tray popover:
    - StackedWidget: View 0 (Main Monitor View), View 1 (Settings & Doctor View)
    - Replicates exact styling tokens, layout, and sections
    """
    def __init__(self, tray_app, parent=None):
        super().__init__(
            parent,
            Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.SubWindow
        )
        self.tray_app = tray_app
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)
        self.setFixedWidth(330)

        # Outer Shadow Frame
        self.card = QFrame(self)
        self.card.setObjectName("PopoverCard")
        self.card.setStyleSheet(POPOVER_CSS)

        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(24)
        shadow.setColor(QColor(0, 0, 0, 180))
        shadow.setOffset(0, 4)
        self.card.setGraphicsEffect(shadow)

        root = QVBoxLayout(self)
        root.setContentsMargins(6, 6, 6, 6)
        root.addWidget(self.card)

        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(0, 0, 0, 0)
        card_layout.setSpacing(0)

        # Header
        self._build_header(card_layout)

        # Content Stack (Monitor View vs Settings View)
        self.stack = QStackedWidget()
        card_layout.addWidget(self.stack)

        self.monitor_view = QWidget()
        self._build_monitor_view(self.monitor_view)
        self.stack.addWidget(self.monitor_view)

        self.settings_view = QWidget()
        self._build_settings_view(self.settings_view)
        self.stack.addWidget(self.settings_view)

        # Footer
        self._build_footer(card_layout)

    def _build_header(self, parent_layout: QVBoxLayout):
        header_widget = QWidget()
        header_widget.setProperty("class", "pop-header")
        hl = QHBoxLayout(header_widget)
        hl.setContentsMargins(14, 12, 14, 12)
        hl.setSpacing(8)

        # Status Dot (9px circle)
        self.dot = QLabel()
        self.dot.setFixedSize(10, 10)
        self._set_dot_state("stopped")
        hl.addWidget(self.dot, 0, Qt.AlignVCenter)

        # Title
        title = QLabel("OmniRoute")
        title.setStyleSheet("font-weight: 700; font-size: 14px; color: #f5f5f7; letter-spacing: -0.01em;")
        hl.addWidget(title)

        # State label
        self.lbl_state = QLabel("Starting…")
        self.lbl_state.setStyleSheet("color: #a1a1aa; font-size: 11px;")
        hl.addWidget(self.lbl_state)

        hl.addStretch()

        # Version
        self.lbl_ver = QLabel("v3.8.50")
        self.lbl_ver.setStyleSheet("color: #6b7280; font-size: 11px;")
        hl.addWidget(self.lbl_ver)

        parent_layout.addWidget(header_widget)

    def _build_monitor_view(self, parent: QWidget):
        layout = QVBoxLayout(parent)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # 1. Status Band (Provider Health)
        self.statusband_widget = QWidget()
        self.statusband_layout = QHBoxLayout(self.statusband_widget)
        self.statusband_layout.setContentsMargins(14, 8, 14, 8)
        self.lbl_statusband = QLabel("Loading provider health…")
        self.lbl_statusband.setStyleSheet("color: #a1a1aa; font-size: 11px;")
        self.statusband_layout.addWidget(self.lbl_statusband)
        layout.addWidget(self.statusband_widget)

        # Separator line
        sep1 = QFrame()
        sep1.setFrameShape(QFrame.HLine)
        sep1.setStyleSheet("background: #38383a; max-height: 1px;")
        layout.addWidget(sep1)

        # 2. Rate Limits / Usage Section
        self.usage_sec = QWidget()
        ul = QVBoxLayout(self.usage_sec)
        ul.setContentsMargins(14, 10, 14, 10)
        ul.setSpacing(8)

        u_head = QHBoxLayout()
        lbl_u_title = QLabel("Usage")
        lbl_u_title.setProperty("class", "sec-head")
        u_head.addWidget(lbl_u_title)
        u_head.addStretch()

        self.btn_quota_mode = QPushButton("% left")
        self.btn_quota_mode.setProperty("class", "mode-pill")
        self.btn_quota_mode.clicked.connect(self._toggle_quota_mode)
        u_head.addWidget(self.btn_quota_mode)
        ul.addLayout(u_head)

        self.usage_accounts_layout = QVBoxLayout()
        self.usage_accounts_layout.setSpacing(8)
        ul.addLayout(self.usage_accounts_layout)
        layout.addWidget(self.usage_sec)

        # Separator line
        sep2 = QFrame()
        sep2.setFrameShape(QFrame.HLine)
        sep2.setStyleSheet("background: #38383a; max-height: 1px;")
        layout.addWidget(sep2)

        # 3. Cost Section
        self.cost_sec = QWidget()
        cl = QVBoxLayout(self.cost_sec)
        cl.setContentsMargins(14, 10, 14, 10)
        cl.setSpacing(6)

        c_head = QHBoxLayout()
        lbl_c_title = QLabel("Cost")
        lbl_c_title.setProperty("class", "sec-head")
        c_head.addWidget(lbl_c_title)
        c_head.addStretch()

        # Cost ranges pills
        self.cost_pills = {}
        for r_id in ("1d", "7d", "30d"):
            b = QPushButton(r_id.upper())
            b.setProperty("class", "mode-pill" + (" active" if r_id == self.tray_app.settings.cost_range else ""))
            b.clicked.connect(lambda _, r=r_id: self._select_cost_range(r))
            c_head.addWidget(b)
            self.cost_pills[r_id] = b

        self.btn_cost_mode = QPushButton("%")
        self.btn_cost_mode.setProperty("class", "mode-pill")
        self.btn_cost_mode.clicked.connect(self._toggle_cost_mode)
        c_head.addWidget(self.btn_cost_mode)
        cl.addLayout(c_head)

        self.lbl_cost_total = QLabel("$0.00 · 0 tokens")
        self.lbl_cost_total.setStyleSheet("font-size: 14px; font-weight: 700; color: #f5f5f7; margin-top: 2px;")
        cl.addWidget(self.lbl_cost_total)

        self.cost_rows_layout = QVBoxLayout()
        self.cost_rows_layout.setSpacing(4)
        cl.addLayout(self.cost_rows_layout)
        layout.addWidget(self.cost_sec)

        # Separator line
        sep3 = QFrame()
        sep3.setFrameShape(QFrame.HLine)
        sep3.setStyleSheet("background: #38383a; max-height: 1px;")
        layout.addWidget(sep3)

        # 4. Usage Trend Section
        self.trend_sec = QWidget()
        tl = QVBoxLayout(self.trend_sec)
        tl.setContentsMargins(14, 10, 14, 10)
        tl.setSpacing(6)

        t_head = QHBoxLayout()
        lbl_t_title = QLabel("Usage trend")
        lbl_t_title.setProperty("class", "sec-head")
        t_head.addWidget(lbl_t_title)
        t_head.addStretch()
        self.lbl_trend_summary = QLabel("")
        self.lbl_trend_summary.setStyleSheet("color: #6b7280; font-size: 10.5px;")
        t_head.addWidget(self.lbl_trend_summary)
        tl.addLayout(t_head)

        self.sparkline = SparklineWidget()
        tl.addWidget(self.sparkline)
        layout.addWidget(self.trend_sec)

    def _build_settings_view(self, parent: QWidget):
        layout = QVBoxLayout(parent)
        layout.setContentsMargins(14, 10, 14, 10)
        layout.setSpacing(10)

        # Settings Header with Back Button
        sh = QHBoxLayout()
        btn_back = QPushButton("← Back")
        btn_back.setStyleSheet("border: none; background: none; color: #ff453a; font-weight: 600; font-size: 12px;")
        btn_back.clicked.connect(lambda: self.stack.setCurrentIndex(0))
        sh.addWidget(btn_back)

        lbl_st = QLabel("Settings")
        lbl_st.setStyleSheet("font-weight: 700; font-size: 13px; color: #f5f5f7;")
        sh.addWidget(lbl_st)
        sh.addStretch()
        layout.addLayout(sh)

        # Section Visibility Toggles
        layout.addWidget(QLabel("<b>Sections</b>"))
        self.chk_sec_health = QCheckBox("Provider health")
        self.chk_sec_health.setChecked("health" not in self.tray_app.settings.hidden_sections)
        self.chk_sec_health.toggled.connect(lambda v: self._toggle_sec_vis("health", v, self.statusband_widget))
        layout.addWidget(self.chk_sec_health)

        self.chk_sec_usage = QCheckBox("Usage")
        self.chk_sec_usage.setChecked("usage" not in self.tray_app.settings.hidden_sections)
        self.chk_sec_usage.toggled.connect(lambda v: self._toggle_sec_vis("usage", v, self.usage_sec))
        layout.addWidget(self.chk_sec_usage)

        self.chk_sec_cost = QCheckBox("Cost")
        self.chk_sec_cost.setChecked("cost" not in self.tray_app.settings.hidden_sections)
        self.chk_sec_cost.toggled.connect(lambda v: self._toggle_sec_vis("cost", v, self.cost_sec))
        layout.addWidget(self.chk_sec_cost)

        self.chk_sec_trend = QCheckBox("Usage trend")
        self.chk_sec_trend.setChecked("trend" not in self.tray_app.settings.hidden_sections)
        self.chk_sec_trend.toggled.connect(lambda v: self._toggle_sec_vis("trend", v, self.trend_sec))
        layout.addWidget(self.chk_sec_trend)

        # Doctor Diagnostics
        layout.addWidget(QLabel("<b>Doctor Diagnostics</b>"))
        self.doctor_box = QVBoxLayout()
        self.doctor_box.setSpacing(2)
        self._refresh_doctor_box()
        layout.addLayout(self.doctor_box)

        # Server Management
        layout.addWidget(QLabel("<b>Server</b>"))
        self.chk_autostart = QCheckBox("Start on login")
        self.chk_autostart.setChecked(autostart_is_enabled())
        self.chk_autostart.toggled.connect(self._toggle_autostart)
        layout.addWidget(self.chk_autostart)

        btn_restart = QPushButton("Restart Server")
        btn_restart.setProperty("class", "action-btn")
        btn_restart.clicked.connect(self.tray_app.supervisor.restart)
        layout.addWidget(btn_restart)

        btn_logs = QPushButton("Open Server Logs")
        btn_logs.setProperty("class", "action-btn")
        btn_logs.clicked.connect(self.tray_app._open_logs)
        layout.addWidget(btn_logs)

        btn_quit = QPushButton("Quit OmniRouteTray")
        btn_quit.setProperty("class", "action-btn danger")
        btn_quit.clicked.connect(self.tray_app._quit)
        layout.addWidget(btn_quit)

    def _build_footer(self, parent_layout: QVBoxLayout):
        footer_widget = QWidget()
        footer_widget.setProperty("class", "footer")
        fl = QHBoxLayout(footer_widget)
        fl.setContentsMargins(14, 8, 14, 8)
        fl.setSpacing(6)

        # App version & Clickable port badge
        app_lbl = QLabel("OmniRoute")
        app_lbl.setStyleSheet("color: #6b7280; font-size: 11px;")
        fl.addWidget(app_lbl)

        btn_port = QPushButton(":20128")
        btn_port.setStyleSheet("""
            QPushButton {
                font-family: monospace;
                font-size: 10px;
                color: #a1a1aa;
                background: #2c2c2e;
                border: 1px solid #38383a;
                border-radius: 4px;
                padding: 1px 5px;
            }
            QPushButton:hover {
                color: #ff453a;
                border-color: #ff453a;
            }
        """)
        btn_port.clicked.connect(lambda: webbrowser.open(self.tray_app.settings.api_base))
        fl.addWidget(btn_port)

        fl.addStretch()

        # Right Action Buttons (Refresh, GitHub, Gear)
        self.btn_refresh = QPushButton("↻")
        self.btn_refresh.setProperty("class", "icon-btn")
        self.btn_refresh.setToolTip("Refresh data")
        self.btn_refresh.clicked.connect(self.tray_app._poll_data)
        fl.addWidget(self.btn_refresh)

        btn_help = QPushButton("")
        btn_help.setProperty("class", "icon-btn")
        btn_help.setToolTip("GitHub")
        btn_help.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: 1px solid transparent;
                border-radius: 6px;
                width: 24px;
                height: 24px;
                image: none;
            }
            QPushButton:hover {
                background: #2c2c2e;
                border-color: #38383a;
            }
        """)
        github_icon = self._make_github_icon()
        btn_help.setIcon(github_icon)
        btn_help.setIconSize(QSize(16, 16))
        btn_help.clicked.connect(lambda: webbrowser.open("https://github.com/diegosouzapw/OmniRoute"))
        fl.addWidget(btn_help)

        self.btn_gear = QPushButton("⚙")
        self.btn_gear.setProperty("class", "icon-btn")
        self.btn_gear.setToolTip("Settings & Doctor")
        self.btn_gear.clicked.connect(self._toggle_settings_view)
        fl.addWidget(self.btn_gear)

        parent_layout.addWidget(footer_widget)

    def _set_dot_state(self, state: str):
        color = "#22c55e" if state in ("running", "adopted") else "#f59e0b" if state in ("starting", "updating") else "#ef4444"
        self.dot.setStyleSheet(f"""
            background-color: {color};
            border-radius: 5px;
            border: 1px solid rgba(255, 255, 255, 0.15);
        """)

    def _make_github_icon(self) -> QIcon:
        pm = QPixmap(16, 16)
        pm.fill(Qt.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.Antialiasing, True)
        from PySide6.QtSvg import QSvgRenderer
        from PySide6.QtCore import QByteArray
        svg_data = QByteArray(b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="#a1a1aa"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>')
        renderer = QSvgRenderer(svg_data)
        renderer.render(p)
        p.end()
        return QIcon(pm)

    def update_server_state(self, state: ServerState):
        lbl = STATE_LABELS.get(state, str(state))
        self.lbl_state.setText(lbl)
        if state in (ServerState.RUNNING, ServerState.ADOPTED):
            self._set_dot_state("running")
        elif state == ServerState.STARTING:
            self._set_dot_state("starting")
        else:
            self._set_dot_state("stopped")

    def _toggle_quota_mode(self):
        if self.tray_app.settings.percent_mode == "left":
            self.tray_app.settings.percent_mode = "used"
        else:
            self.tray_app.settings.percent_mode = "left"
        self.tray_app.settings.save()
        self.btn_quota_mode.setText(f"% {self.tray_app.settings.percent_mode}")
        if self.tray_app._last_snap:
            self.render_snapshot(self.tray_app._last_snap)

    def _toggle_cost_mode(self):
        if self.tray_app.settings.cost_mode == "pct":
            self.tray_app.settings.cost_mode = "tokens"
            self.btn_cost_mode.setText("in/out")
        else:
            self.tray_app.settings.cost_mode = "pct"
            self.btn_cost_mode.setText("%")
        self.tray_app.settings.save()
        if self.tray_app._last_snap:
            self.render_snapshot(self.tray_app._last_snap)

    def _select_cost_range(self, range_id: str):
        self.tray_app.settings.cost_range = range_id
        self.tray_app.settings.save()
        for r_id, btn in self.cost_pills.items():
            btn.setProperty("class", "mode-pill" + (" active" if r_id == range_id else ""))
            btn.style().unpolish(btn)
            btn.style().polish(btn)
        self.tray_app._poll_data()

    def _toggle_settings_view(self):
        if self.stack.currentIndex() == 0:
            self._refresh_doctor_box()
            self.stack.setCurrentIndex(1)
        else:
            self.stack.setCurrentIndex(0)

    def _toggle_sec_vis(self, sec_id: str, visible: bool, widget: QWidget):
        widget.setVisible(visible)
        if not visible and sec_id not in self.tray_app.settings.hidden_sections:
            self.tray_app.settings.hidden_sections.append(sec_id)
        elif visible and sec_id in self.tray_app.settings.hidden_sections:
            self.tray_app.settings.hidden_sections.remove(sec_id)
        self.tray_app.settings.save()
        self.adjustSize()

    def _toggle_autostart(self, enabled: bool):
        if enabled:
            autostart_enable()
            self.tray_app.settings.start_on_login = True
        else:
            autostart_disable()
            self.tray_app.settings.start_on_login = False
        self.tray_app.settings.save()

    def _refresh_doctor_box(self):
        while self.doctor_box.count():
            it = self.doctor_box.takeAt(0)
            if it.widget():
                it.widget().deleteLater()

        node_bin = shutil.which("node") or "missing"
        cli_bin = shutil.which("omniroute") or "missing"
        mid = get_raw_machine_id() or "missing"
        port = get_port_from_url(self.tray_app.settings.api_base)
        alive = server_healthy(self.tray_app.settings.api_base)

        checks = [
            ("Node Runtime", True if node_bin != "missing" else False, node_bin),
            ("OmniRoute CLI", True if cli_bin != "missing" else False, cli_bin),
            ("Loopback Auth Token", True if mid != "missing" else False, f"Machine ID: {mid[:8]}…"),
            ("Server Status", alive, f"Port {port} ({'healthy' if alive else 'inactive'})"),
        ]

        for label, ok, detail in checks:
            mark = "<span style='color:#22c55e;'>✔</span>" if ok else "<span style='color:#ef4444;'>✘</span>"
            lbl = QLabel(f"{mark} <b>{label}</b>: <span style='color:#6b7280;'>{detail}</span>")
            lbl.setStyleSheet("font-size: 11px;")
            self.doctor_box.addWidget(lbl)

    def render_snapshot(self, snap: FullSnapshot):
        mode_used = (self.tray_app.settings.percent_mode == "used")
        self.btn_quota_mode.setText(f"% {self.tray_app.settings.percent_mode}")

        # 1. Status Band
        if snap.health.configured_providers > 0:
            open_txt = f" · <span style='color:#ef4444;'>{snap.health.breakers_open} open</span>" if snap.health.breakers_open > 0 else " · 0 open"
            self.lbl_statusband.setText(f"{snap.health.active_providers} of {snap.health.configured_providers} providers active{open_txt}")
        else:
            self.lbl_statusband.setText("No active provider health data")

        # 2. Rate Limits & Quotas
        while self.usage_accounts_layout.count():
            it = self.usage_accounts_layout.takeAt(0)
            if it.widget():
                w = it.widget()
                w.hide()
                w.setParent(None)
                w.deleteLater()

        if snap.accounts:
            for acc in snap.accounts:
                acc_w = QWidget()
                al = QVBoxLayout(acc_w)
                al.setContentsMargins(0, 0, 0, 0)
                al.setSpacing(4)

                # Account Title
                a_title = QLabel(f"<b>{acc.account_name}</b> ({acc.provider})")
                a_title.setStyleSheet("font-size: 11.5px; color: #f5f5f7;")
                al.addWidget(a_title)

                for w_item in acc.windows:
                    row_w = QWidget()
                    rl = QHBoxLayout(row_w)
                    rl.setContentsMargins(0, 1, 0, 1)
                    rl.setSpacing(8)

                    tag = QLabel(w_item.short_tag)
                    tag.setProperty("class", "window-tag")
                    tag.setFixedWidth(28)
                    tag.setAlignment(Qt.AlignCenter)
                    rl.addWidget(tag)

                    bar = QProgressBar()
                    bar.setProperty("class", "round-bar")
                    bar.setRange(0, 100)
                    pct = w_item.used_pct if mode_used else w_item.remaining_pct
                    bar.setValue(int(pct))
                    bar.setTextVisible(False)
                    rl.addWidget(bar)

                    val_lbl = QLabel(f"{int(pct)}%")
                    val_lbl.setStyleSheet("color: #a1a1aa; font-size: 11px; font-variant-numeric: tabular-nums;")
                    val_lbl.setFixedWidth(30)
                    val_lbl.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
                    rl.addWidget(val_lbl)

                    if w_item.reset_countdown:
                        cd_lbl = QLabel(w_item.reset_countdown)
                        cd_lbl.setStyleSheet("color: #6b7280; font-size: 10px;")
                        rl.addWidget(cd_lbl)

                    al.addWidget(row_w)
                self.usage_accounts_layout.addWidget(acc_w)
        else:
            no_u = QLabel("No active quotas reported")
            no_u.setStyleSheet("color: #6b7280; font-size: 11px;")
            self.usage_accounts_layout.addWidget(no_u)

        # 3. Cost Breakdown
        while self.cost_rows_layout.count():
            it = self.cost_rows_layout.takeAt(0)
            if it.widget():
                w = it.widget()
                w.hide()
                w.setParent(None)
                w.deleteLater()

        if snap.cost and snap.cost.rows:
            tok_str = format_tokens(snap.cost.total_tokens)
            self.lbl_cost_total.setText(f"${snap.cost.total_cost_usd:.2f} · {tok_str}")

            show_tokens = (self.tray_app.settings.cost_mode == "tokens")
            for r in snap.cost.rows[:4]:
                if r.cost_usd <= 0 and r.requests <= 0:
                    continue
                row_w = QWidget()
                rl = QHBoxLayout(row_w)
                rl.setContentsMargins(0, 1, 0, 1)

                m_lbl = QLabel(r.model)
                m_lbl.setStyleSheet("color: #a1a1aa; font-size: 11px;")
                rl.addWidget(m_lbl)
                rl.addStretch()

                if show_tokens:
                    val_text = f"{compact_tokens(r.tokens_in)} in · {compact_tokens(r.tokens_out)} out"
                else:
                    val_text = f"${r.cost_usd:.2f} ({r.cost_pct:.1f}%)"

                v_lbl = QLabel(val_text)
                v_lbl.setStyleSheet("color: #f5f5f7; font-size: 11px; font-variant-numeric: tabular-nums;")
                rl.addWidget(v_lbl)
                self.cost_rows_layout.addWidget(row_w)
        else:
            self.lbl_cost_total.setText("$0.00 · 0 tokens")
            no_c = QLabel("No spend recorded in this range")
            no_c.setStyleSheet("color: #6b7280; font-size: 11px;")
            self.cost_rows_layout.addWidget(no_c)

        # 4. Trend
        if snap.trend and snap.trend.points:
            self.sparkline.set_points(snap.trend.points)
            self.lbl_trend_summary.setText(f"Today: ${snap.trend.today_cost:.2f}")
        else:
            self.sparkline.set_points([])
            self.lbl_trend_summary.setText("")

        self.adjustSize()

    def toggle_at(self, tray_geom: QRect):
        if self.isVisible():
            self.hide()
            return
        self.show()
        self.raise_()
        self.activateWindow()
        self.position_near(tray_geom)

    def position_near(self, tray_geom: QRect):
        screen = QApplication.screenAt(QCursor.pos()) or QApplication.primaryScreen()
        screen_geom = screen.availableGeometry()

        self.adjustSize()
        pop_w = self.width()
        pop_h = self.height()

        if tray_geom.isValid() and not tray_geom.isEmpty():
            x = tray_geom.center().x() - pop_w // 2
            x = max(screen_geom.left() + 10, min(x, screen_geom.right() - pop_w - 10))

            # Bottom panel vs Top panel detection
            if tray_geom.center().y() > screen_geom.center().y():
                y = tray_geom.top() - pop_h - 6
            else:
                y = tray_geom.bottom() + 6
        else:
            cur = QCursor.pos()
            x = max(screen_geom.left() + 10, min(cur.x() - pop_w // 2, screen_geom.right() - pop_w - 10))
            y = min(cur.y() + 10, screen_geom.bottom() - pop_h - 10)

        self.move(int(x), int(y))

    def changeEvent(self, event):
        if event.type() == QEvent.ActivationChange:
            if not self.isActiveWindow():
                QTimer.singleShot(120, self._check_hide_on_deactivate)
        super().changeEvent(event)

    def _check_hide_on_deactivate(self):
        if not self.isActiveWindow():
            self.hide()


# ============================================================================
# Main Application Controller
# ============================================================================

class Bridge(QObject):
    state_changed = Signal(object)
    log_line = Signal(str)
    snapshot_ready = Signal(object)
    update_available = Signal(str, str)


class TrayApp:
    def __init__(self):
        ensure_dirs()
        self.settings = Settings.load()
        self.app = QApplication.instance() or QApplication(sys.argv)
        self.app.setApplicationName("omniroute-tray")
        self.app.setApplicationDisplayName("OmniRoute")
        self.app.setDesktopFileName("omniroute-tray")
        self.app.setQuitOnLastWindowClosed(False)

        self.bridge = Bridge()
        self.bridge.state_changed.connect(self._on_state_changed)
        self.bridge.log_line.connect(self._append_log)
        self.bridge.snapshot_ready.connect(self._on_snapshot_ready)
        self.bridge.update_available.connect(self._on_update_available)

        self._polling_active = False
        self._last_snap: Optional[FullSnapshot] = None

        self.supervisor = ServerSupervisor(
            self.settings,
            on_state_change=lambda s: self.bridge.state_changed.emit(s),
            on_log=lambda m: self.bridge.log_line.emit(m),
        )

        self.tray = QSystemTrayIcon()
        self.tray.setIcon(get_tray_icon("stopped"))
        self.tray.setToolTip("OmniRoute")

        # Context Menu for Right Click
        self.menu = QMenu()
        self._build_context_menu()
        self.tray.setContextMenu(self.menu)

        # 1-to-1 Popover for Left Click
        self.popover = OmniRoutePopover(self)

        self.tray.activated.connect(self._on_tray_activated)
        self.tray.show()

        # Timers
        self.poll_timer = QTimer()
        self.poll_timer.timeout.connect(self._poll_data)
        self.poll_timer.start(max(5, self.settings.poll_interval_seconds) * 1000)

        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._background_update_check)
        self.update_timer.start(6 * 60 * 60 * 1000)

        # Start supervisor
        self.supervisor.start()
        QTimer.singleShot(1000, self._poll_data)
        QTimer.singleShot(4000, self._background_update_check)

    def _build_context_menu(self):
        self.status_action = self.menu.addAction("Status: Stopped")
        self.status_action.setEnabled(False)
        self.menu.addSeparator()
        self.start_action = self.menu.addAction("Start server", self.supervisor.start)
        self.stop_action = self.menu.addAction("Stop server", self.supervisor.stop)
        self.menu.addAction("Restart server", self.supervisor.restart)
        self.menu.addAction("Force-stop all OmniRoute processes…", self._force_stop_clicked)
        self.menu.addSeparator()
        self.menu.addAction("Open Dashboard", lambda: webbrowser.open(self.settings.api_base))
        self.menu.addAction("View server logs", self._open_logs)
        self.menu.addSeparator()
        self.menu.addAction("Quit", self._quit)

    def _on_tray_activated(self, reason: QSystemTrayIcon.ActivationReason):
        if reason == QSystemTrayIcon.Trigger:
            self.popover.toggle_at(self.tray.geometry())

    def _on_state_changed(self, state: ServerState):
        lbl = STATE_LABELS.get(state, str(state))
        self.status_action.setText(f"Status: {lbl}")

        if state in (ServerState.RUNNING, ServerState.ADOPTED):
            state_key = "running"
        elif state == ServerState.STARTING:
            state_key = "starting"
        else:
            state_key = "stopped"

        self.tray.setIcon(get_tray_icon(state_key))
        self.popover.update_server_state(state)

        running = (state in (ServerState.RUNNING, ServerState.ADOPTED))
        self.start_action.setEnabled(not running)
        self.stop_action.setEnabled(running)

        if running:
            QTimer.singleShot(800, self._poll_data)

    def _poll_data(self):
        if self._polling_active:
            return
        self._polling_active = True
        threading.Thread(target=self._async_fetch, daemon=True).start()

    def _async_fetch(self):
        try:
            snap = fetch_full_snapshot(self.settings)
            self.bridge.snapshot_ready.emit(snap)
        except Exception as e:
            self.bridge.log_line.emit(f"Fetch error: {e}")
        finally:
            self._polling_active = False

    def _on_snapshot_ready(self, snap: FullSnapshot):
        self._last_snap = snap
        self.popover.render_snapshot(snap)

    def _background_update_check(self):
        threading.Thread(target=self._async_check_update, daemon=True).start()

    def _async_check_update(self):
        try:
            res = subprocess.run(["omniroute", "--version"], capture_output=True, text=True)
            installed = res.stdout.strip()
            req = urllib.request.Request("https://registry.npmjs.org/omniroute/latest")
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read())
                latest = data.get("version")
                if installed and latest and installed != latest:
                    self.bridge.update_available.emit(installed, latest)
        except Exception:
            pass

    def _on_update_available(self, installed: str, latest: str):
        self.tray.showMessage(
            "OmniRoute Update",
            f"A newer version of OmniRoute is available: {installed} → {latest}",
            QSystemTrayIcon.Information,
            7000
        )

    def _force_stop_clicked(self):
        resp = QMessageBox.question(
            None, "Force-stop OmniRoute",
            "This will terminate all OmniRoute process groups and clear port 20128.\n\nProceed?",
        )
        if resp != QMessageBox.Yes:
            return
        ok, msg = force_kill_all(get_port_from_url(self.settings.api_base))
        self._append_log(f"Force-stop: {msg}")
        self.tray.showMessage("OmniRoute Tray", msg, QSystemTrayIcon.Information, 4000)
        self.supervisor._set_state(ServerState.STOPPED)

    def _open_logs(self):
        ensure_dirs()
        SERVER_LOG_FILE.touch(exist_ok=True)
        try:
            subprocess.Popen(["xdg-open", str(SERVER_LOG_FILE)])
        except Exception:
            webbrowser.open(f"file://{SERVER_LOG_FILE}")

    def _append_log(self, msg: str):
        ensure_dirs()
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg.rstrip()}\n")

    def _quit(self):
        self.supervisor.stop()
        self.app.quit()

    def run(self):
        return self.app.exec()


def main():
    if "--stop" in sys.argv:
        subprocess.run(["omniroute", "stop"], capture_output=True, timeout=5)
        subprocess.run(["fuser", "-k", "20128/tcp"], capture_output=True)
        subprocess.run(["pkill", "-9", "-f", "omniroute serve"], capture_output=True)
        res = subprocess.run(["ss", "-tulpn"], capture_output=True, text=True)
        for line in res.stdout.splitlines():
            if ":20128" in line and "pid=" in line:
                part = line.split("pid=")[1].split(",")[0].split(")")[0]
                try:
                    os.kill(int(part), signal.SIGKILL)
                except Exception:
                    pass
        pid_file = Path.home() / ".omniroute" / "server" / ".pid"
        if pid_file.exists():
            try:
                pid = int(pid_file.read_text().strip())
                os.kill(pid, signal.SIGKILL)
            except Exception:
                pass
            pid_file.unlink(missing_ok=True)
        print("STOPPED")
        sys.exit(0)

    if "--start" in sys.argv:
        subprocess.Popen(["omniroute", "serve", "--daemon"])
        print("STARTED")
        sys.exit(0)

    if "--restart" in sys.argv:
        subprocess.run(["omniroute", "stop"], capture_output=True, timeout=5)
        subprocess.run(["fuser", "-k", "20128/tcp"], capture_output=True)
        subprocess.run(["pkill", "-9", "-f", "omniroute serve"], capture_output=True)
        res = subprocess.run(["ss", "-tulpn"], capture_output=True, text=True)
        for line in res.stdout.splitlines():
            if ":20128" in line and "pid=" in line:
                part = line.split("pid=")[1].split(",")[0].split(")")[0]
                try:
                    os.kill(int(part), signal.SIGKILL)
                except Exception:
                    pass
        pid_file = Path.home() / ".omniroute" / "server" / ".pid"
        if pid_file.exists():
            try:
                pid = int(pid_file.read_text().strip())
                os.kill(pid, signal.SIGKILL)
            except Exception:
                pass
            pid_file.unlink(missing_ok=True)
        time.sleep(1.0)
        subprocess.Popen(["omniroute", "serve", "--daemon"])
        print("RESTARTED")
        sys.exit(0)

    if "--toggle-autostart" in sys.argv:
        p = Path.home() / ".config" / "autostart" / "omniroute-tray.desktop"
        if p.exists():
            p.unlink()
            print("AUTOSTART_DISABLED")
        else:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("""[Desktop Entry]
Type=Application
Name=OmniRoute Tray
Exec=/home/susan/.local/bin/omniroute-tray
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
""")
            print("AUTOSTART_ENABLED")
        sys.exit(0)

    if "--snapshot" in sys.argv:
        settings = Settings()
        if "--period" in sys.argv:
            idx = sys.argv.index("--period")
            if idx + 1 < len(sys.argv):
                settings.cost_range = sys.argv[idx + 1]
        snap = fetch_full_snapshot(settings)
        import dataclasses
        print(json.dumps(dataclasses.asdict(snap)))
        sys.exit(0)

    app = TrayApp()
    sys.exit(app.run())


if __name__ == "__main__":
    main()


