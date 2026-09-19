import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import "utils.js" as Utils

PlasmoidItem {
    id: root

    Plasmoid.icon: "omniroute"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    toolTipMainText: "OmniRoute"
    toolTipSubText: isRunning ? ("Running · " + healthActiveProviders + " active providers · Port 20128") : "Stopped"

    // Pinning / Keep Open support
    property bool pinned: false
    hideOnWindowDeactivate: !pinned

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
    }
    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }

    // ========================================================================
    // CONFIGURATION PROPERTIES
    // ========================================================================
    property bool showHealth: plasmoid.configuration.showHealth !== false
    property bool showUsage: plasmoid.configuration.showUsage !== false
    property bool showCost: plasmoid.configuration.showCost !== false
    property bool showTrend: plasmoid.configuration.showTrend !== false
    property bool showUsed: plasmoid.configuration.showUsed === true
    property string costRange: plasmoid.configuration.costRange || "30d"
    property bool showCostPct: plasmoid.configuration.showCostPct !== false

    function toggleShowUsed() {
        showUsed = !showUsed;
        plasmoid.configuration.showUsed = showUsed;
    }

    function setCostRange(r) {
        costRange = r;
        plasmoid.configuration.costRange = r;
        fetchCost(r);
    }

    function toggleShowCostPct() {
        showCostPct = !showCostPct;
        plasmoid.configuration.showCostPct = showCostPct;
    }

    function setSectionVisible(sec, val) {
        if (sec === "health") { showHealth = val; plasmoid.configuration.showHealth = val; }
        if (sec === "usage") { showUsage = val; plasmoid.configuration.showUsage = val; }
        if (sec === "cost") { showCost = val; plasmoid.configuration.showCost = val; }
        if (sec === "trend") { showTrend = val; plasmoid.configuration.showTrend = val; }
    }

    // ========================================================================
    // STATE PROPERTIES
    // ========================================================================
    property bool isRunning: false
    property string serverVersion: "unknown"
    property int serverPid: 0
    property string serverActionState: "" // "", "starting", "stopping", "restarting"

    // Health
    property int healthActiveProviders: 0
    property int healthConfiguredProviders: 0
    property int healthBreakersOpen: 0

    // Usage & Quotas
    property var usageAccountsModel: []
    property var providerQuotasModel: []

    // Cost
    property real costTotalUsd: 0.0
    property real costTotalTokens: 0
    property var costRowsModel: []

    // Trend
    property var trendPointsModel: []
    property real todaySpend: 0.0
    property real yesterdaySpend: 0.0

    // Doctor & System
    property var doctorModel: []
    property var recentLogsModel: []
    property bool autostartEnabled: false
    property string updateStatus: "Up to date (unknown)"
    property string trayUpdateStatus: "unknown"
    property bool isUpdatingTray: false
    property bool isCheckingUpdate: false
    // New state for updates
    property string trayVersion: "unknown"
    property string trayCommit: "unknown"
    property bool serverUpdateAvailable: false
    property string serverLatestVersion: ""
    property string updateLastChecked: ""
    property string trayUpdateLastChecked: ""
    property bool updateError: false
    property string updateErrorMsg: ""
    property bool isFetchingSnapshot: false
    property bool trayUpdateError: false
    property string trayUpdateErrorMsg: ""


    // ========================================================================
    // DATA SOURCE (FOR EXECUTING CLI COMMANDS)
    // ========================================================================
    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || "";
            disconnectSource(sourceName);

            if (sourceName.indexOf("--update-tray") !== -1) {
                root.isUpdatingTray = false;
                root.trayUpdateLastChecked = new Date().toLocaleTimeString();
                var stderr = data["stderr"] || "";
                try {
                    var start = stdout.indexOf("{");
                    var end = stdout.lastIndexOf("}");
                    if (start !== -1 && end !== -1) {
                        var parsed = JSON.parse(stdout.substring(start, end + 1));
                        root.trayUpdateStatus = parsed.message || (parsed.success ? "Updated!" : "Update failed");
                        root.trayUpdateError = !parsed.success;
                        root.trayUpdateErrorMsg = parsed.success ? "" : (parsed.message || "Update failed");
                        if (parsed.success) {
                            if (typeof parsed.tray_version === "string" && parsed.tray_version)
                                root.trayVersion = parsed.tray_version;
                            if (typeof parsed.tray_commit === "string" && parsed.tray_commit)
                                root.trayCommit = parsed.tray_commit;
                        }
                    } else if (stdout.trim()) {
                        root.trayUpdateStatus = stdout.trim();
                        root.trayUpdateError = false;
                    } else if (stderr.trim()) {
                        root.trayUpdateStatus = stderr.trim();
                        root.trayUpdateError = true;
                        root.trayUpdateErrorMsg = stderr.trim();
                    } else {
                        root.trayUpdateStatus = "Update finished";
                        root.trayUpdateError = false;
                    }
                } catch(e) {
                    root.trayUpdateStatus = "Updated!";
                    root.trayUpdateError = false;
                }
            } else if (sourceName.indexOf("--cost") !== -1) {
                applyCost(stdout);
            } else if (sourceName.indexOf("omniroute_snapshot") !== -1 || sourceName.indexOf("--snapshot") !== -1) {
                root.isFetchingSnapshot = false;
                snapshotTimeoutTimer.stop();
                applySnapshot(stdout);
            } else if (sourceName.indexOf("--stop") !== -1) {
                root.isRunning = false;
                root.serverPid = 0;
                pollTimer.restart();
            } else if (sourceName.indexOf("--start") !== -1 || sourceName.indexOf("--restart") !== -1) {
                pollTimer.restart();
                refreshAll();
            } else if (sourceName.indexOf("npm view omniroute") !== -1) {
                root.isCheckingUpdate = false;
                root.updateLastChecked = new Date().toLocaleTimeString();
                var ver = stdout.trim();
                var curVer = root.serverVersion.replace(/^v/, "");
                if (curVer === "unknown") {
                    root.updateStatus = "Could not determine installed version";
                    root.updateError = true;
                    root.updateErrorMsg = "Installed version unknown";
                } else if (!ver) {
                    root.updateStatus = "Couldn't reach npm registry";
                    root.updateError = true;
                    root.updateErrorMsg = "Empty response";
                } else if (ver === curVer) {
                    root.updateStatus = "Up to date (v" + curVer + ")";
                    root.updateError = false;
                    root.serverUpdateAvailable = false;
                    root.serverLatestVersion = "";
                } else {
                    root.updateStatus = "Update available: v" + ver;
                    root.updateError = false;
                    root.serverUpdateAvailable = true;
                    root.serverLatestVersion = ver;
                }
            }
        }
    }

    function runCmd(cmd) {
        execSource.connectSource(cmd);
    }

    function applyCost(stdout) {
        if (!stdout || stdout.length === 0) return;
        var start = stdout.indexOf("{");
        var end = stdout.lastIndexOf("}");
        if (start === -1 || end === -1 || end <= start) return;
        try {
            var parsed = JSON.parse(stdout.substring(start, end + 1));
            if (!parsed) return;
            root.costTotalUsd = parsed.total_cost_usd || 0.0;
            root.costTotalTokens = parsed.total_tokens || 0;
            var rawRows = parsed.rows || [];
            var rList = [];
            for (var r = 0; r < rawRows.length; r++) {
                rList.push({
                    model: rawRows[r].model,
                    costUsd: rawRows[r].cost_usd,
                    costPct: rawRows[r].cost_pct,
                    tokensIn: rawRows[r].tokens_in,
                    tokensOut: rawRows[r].tokens_out
                });
            }
            root.costRowsModel = rList.slice(0, 5);
        } catch(e) {}
    }

    function applySnapshot(stdout) {
        if (!stdout || stdout.length === 0) return;
        for (var i = 0; i < stdout.length; i++) {
            if (stdout[i] === "{" || stdout[i] === "[") {
                try {
                    var parsed = JSON.parse(stdout.substring(i));
                    if (!parsed || !parsed.health) continue;

                    root.isRunning = parsed.server_running || (parsed.health && parsed.health.active_providers > 0);
                    root.serverPid = parsed.server_pid || 0;
                    root.autostartEnabled = parsed.autostart_enabled || false;

                    root.healthActiveProviders = parsed.health.active_providers || 0;
                    root.healthConfiguredProviders = parsed.health.configured_providers || 0;
                    root.healthBreakersOpen = parsed.health.breakers_open || 0;

                    root.providerQuotasModel = parsed.provider_quotas || [];
                    root.doctorModel = parsed.doctor || [];
                    root.recentLogsModel = parsed.recent_logs || [];

                    // New version fields
                    if (typeof parsed.server_version === "string") {
                        root.serverVersion = parsed.server_version;
                        if (root.serverVersion === "") root.serverVersion = "unknown";
                    }
                    if (typeof parsed.tray_version === "string") {
                        root.trayVersion = parsed.tray_version;
                        if (root.trayVersion === "") root.trayVersion = "unknown";
                    }
                    if (typeof parsed.tray_commit === "string") {
                        root.trayCommit = parsed.tray_commit;
                        if (root.trayCommit === "") root.trayCommit = "unknown";
                    }

                    if (parsed.cost) {
                        var snapRange = parsed.cost.range_label ? parsed.cost.range_label.toLowerCase() : "";
                        var curRange = root.costRange ? root.costRange.toLowerCase() : "30d";
                        if (!snapRange || snapRange === curRange) {
                            root.costTotalUsd = parsed.cost.total_cost_usd || 0.0;
                            root.costTotalTokens = parsed.cost.total_tokens || 0;
                            var rawRows = parsed.cost.rows || [];
                            var rList = [];
                            for (var r = 0; r < rawRows.length; r++) {
                                rList.push({
                                    model: rawRows[r].model,
                                    costUsd: rawRows[r].cost_usd,
                                    costPct: rawRows[r].cost_pct,
                                    tokensIn: rawRows[r].tokens_in,
                                    tokensOut: rawRows[r].tokens_out
                                });
                            }
                            root.costRowsModel = rList.slice(0, 5);
                        }
                    }

                    if (parsed.trend) {
                        root.trendPointsModel = parsed.trend.points || [];
                        root.todaySpend = parsed.trend.today_cost || 0.0;
                        root.yesterdaySpend = parsed.trend.yesterday_cost || 0.0;
                    }

                    if (parsed.accounts) {
                        var aList = [];
                        for (var a = 0; a < parsed.accounts.length; a++) {
                            var acc = parsed.accounts[a];
                            var wList = [];
                            for (var w = 0; w < (acc.windows || []).length; w++) {
                                var win = acc.windows[w];
                                wList.push({
                                    key: win.key,
                                    shortTag: win.short_tag,
                                    usedPct: win.used_pct,
                                    remainingPct: win.remaining_pct,
                                    countdown: win.reset_countdown
                                });
                            }
                            aList.push({
                                id: acc.account_name,
                                account: acc.account_name,
                                provider: acc.provider,
                                windows: wList
                            });
                        }
                        root.usageAccountsModel = aList;
                    }
                    return;
                } catch (e) {}
            }
        }
    }

    // ========================================================================
    // TELEMETRY & NETWORK FETCHING
    // ========================================================================
    readonly property string baseUrl: plasmoid.configuration.serverUrl || "http://127.0.0.1:20128"

    function fetchFastPing() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", baseUrl + "/api/monitoring/health");
        xhr.timeout = 1500;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    root.isRunning = true;
                } else {
                    root.isRunning = false;
                }
            }
        };
        xhr.onerror = function() { root.isRunning = false; };
        xhr.ontimeout = function() { root.isRunning = false; };
        xhr.send();
    }

    function loadCachedSnapshot() {
        runCmd("cat /tmp/omniroute_snapshot.json 2>/dev/null || true");
    }

    Timer {
        id: snapshotTimeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            root.isFetchingSnapshot = false;
        }
    }

    function fetchFullSnapshot(period) {
        if (root.isFetchingSnapshot) return;
        root.isFetchingSnapshot = true;
        snapshotTimeoutTimer.restart();
        var p = period || root.costRange || "30d";
        runCmd("~/.local/bin/omniroute-tray --snapshot --period " + p + " > /tmp/omniroute_snapshot.json.tmp && mv /tmp/omniroute_snapshot.json.tmp /tmp/omniroute_snapshot.json && cat /tmp/omniroute_snapshot.json # " + Date.now());
    }

    function fetchCost(period) {
        var p = period || root.costRange || "30d";
        runCmd("~/.local/bin/omniroute-tray --cost --range " + p + " # " + Date.now());
    }

    function updateTray() {
        root.isUpdatingTray = true;
        root.trayUpdateError = false;
        root.trayUpdateErrorMsg = "";
        root.trayUpdateStatus = "Pulling latest code…";
        runCmd("~/.local/bin/omniroute-tray --update-tray # " + Date.now());
    }

    function checkForUpdates() {
        root.isCheckingUpdate = true;
        root.updateError = false;
        root.updateErrorMsg = "";
        root.updateStatus = "Checking npm registry…";
        runCmd("npm view omniroute version");
    }

    function toggleAutostart() {
        runCmd("~/.local/bin/omniroute-tray --toggle-autostart");
        root.autostartEnabled = !root.autostartEnabled;
    }

    function refreshAll() {
        fetchFastPing();
        fetchFullSnapshot(root.costRange);
    }

    // ========================================================================
    // SERVER SUPERVISOR ACTIONS & FAST TRANSITIONS
    // ========================================================================
    Timer {
        id: transitionTimer
        interval: 250
        repeat: true
        running: root.serverActionState !== ""
        property int ticks: 0
        onRunningChanged: { ticks = 0; }
        onTriggered: {
            ticks++;
            var xhr = new XMLHttpRequest();
            xhr.open("GET", baseUrl + "/api/monitoring/health");
            xhr.timeout = 450;
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        if (root.serverActionState === "starting" || root.serverActionState === "restarting") {
                            root.isRunning = true;
                            root.serverActionState = "";
                            refreshAll();
                        }
                    } else {
                        if (root.serverActionState === "stopping") {
                            root.isRunning = false;
                            root.serverPid = 0;
                            root.serverActionState = "";
                            refreshAll();
                        }
                    }
                }
            };
            xhr.onerror = function() {
                if (root.serverActionState === "stopping") {
                    root.isRunning = false;
                    root.serverPid = 0;
                    root.serverActionState = "";
                    refreshAll();
                }
            };
            xhr.send();

            // Fallback timeout after 6 seconds
            if (ticks > 24) {
                root.serverActionState = "";
                refreshAll();
            }
        }
    }

    function restartServer() {
        root.serverActionState = "restarting";
        runCmd("~/.local/bin/omniroute-tray --restart # " + Date.now());
        pollTimer.restart();
    }

    function startServer() {
        root.serverActionState = "starting";
        runCmd("~/.local/bin/omniroute-tray --start # " + Date.now());
        pollTimer.restart();
    }

    function stopServer() {
        root.serverActionState = "stopping";
        runCmd("~/.local/bin/omniroute-tray --stop # " + Date.now());
        pollTimer.restart();
    }

    function openLogs() {
        runCmd("xdg-open ~/.omniroute/logs/application/app.log || xdg-open ~/.omniroute/logs");
    }

    // ========================================================================
    // POLLING TIMER & LIFECYCLE
    // ========================================================================
    Timer {
        id: pollTimer
        interval: (plasmoid.configuration.refreshIntervalSec || 10) * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: refreshAll()
    }

    Component.onCompleted: {
        loadCachedSnapshot();
        refreshAll();
    }
}
