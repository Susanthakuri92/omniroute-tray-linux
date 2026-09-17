import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import "utils.js" as Utils

Item {
    id: cardRoot

    property var plasmoidItem: null

    implicitWidth: 380
    Layout.minimumWidth: 360
    Layout.preferredWidth: 380
    Layout.maximumWidth: 420

    // Dynamic height matching content of active tab (no scrollbar needed)
    readonly property real headerHeight: (headerRow ? headerRow.implicitHeight : 22) + 
                                         (navRow ? navRow.implicitHeight : 26) + 
                                         1 + (contentCol.spacing * 2)
    readonly property real footerHeight: 1 + (footerRow ? footerRow.implicitHeight : 22) + 
                                         (contentCol.spacing * 2)
    readonly property real marginsHeight: 24

    readonly property real activeTabHeight: {
        if (activeTab === "supervisor") return supervisorTab ? supervisorTab.implicitHeight : 260;
        if (activeTab === "monitor") return Math.min(480, monitorTab ? monitorTab.implicitHeight : 320);
        if (activeTab === "doctor") return Math.min(400, doctorTab ? doctorTab.implicitHeight : 300);
        if (activeTab === "settings") return settingsTab ? settingsTab.implicitHeight : 160;
        return 260;
    }

    readonly property real desiredHeight: headerHeight + activeTabHeight + footerHeight + marginsHeight

    implicitHeight: Math.min(Layout.maximumHeight, Math.max(Layout.minimumHeight, desiredHeight))
    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: 220
    Layout.maximumHeight: 780
    height: Layout.preferredHeight

    // Server on first tab by default
    property string activeTab: "supervisor" // "supervisor", "monitor", "doctor", "settings"

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ====================================================================
        // CARD HEADER & STATUS
        // ====================================================================
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 8

            // Status dot
            Rectangle {
                id: headerDot
                width: 8
                height: 8
                radius: 4
                color: {
                    if (plasmoidItem && plasmoidItem.serverActionState !== "") return "#f59e0b";
                    return (plasmoidItem && plasmoidItem.isRunning) ? "#22c55e" : "#ff2b4d";
                }
                SequentialAnimation on opacity {
                    running: plasmoidItem && plasmoidItem.serverActionState !== ""
                    loops: Animation.Infinite
                    PropertyAnimation { to: 0.3; duration: 350 }
                    PropertyAnimation { to: 1.0; duration: 350 }
                }
            }

            // Title & status
            Text {
                text: "OmniRoute"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: "#fafafa"
            }

            Text {
                text: {
                    if (!plasmoidItem) return "Stopped";
                    if (plasmoidItem.serverActionState === "starting") return "Starting…";
                    if (plasmoidItem.serverActionState === "stopping") return "Stopping…";
                    if (plasmoidItem.serverActionState === "restarting") return "Restarting…";
                    return plasmoidItem.isRunning ? 
                          ("Running (:" + (plasmoidItem.serverPid ? plasmoidItem.serverPid : "20128") + ")") : 
                          "Stopped";
                }
                font.pixelSize: 11
                color: {
                    if (!plasmoidItem) return "#ff8095";
                    if (plasmoidItem.serverActionState !== "") return "#fbbf24";
                    return plasmoidItem.isRunning ? "#22c55e" : "#ff8095";
                }
            }

            Item { Layout.fillWidth: true }

            // Quick restart button
            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: Qt.rgba(255, 255, 255, 0.08)
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    font.pixelSize: 13
                    color: "#fafafa"
                }
                MouseArea {
                    id: restartArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: { if (plasmoidItem) plasmoidItem.restartServer(); }
                }
                QQC2.ToolTip.visible: restartArea.containsMouse
                QQC2.ToolTip.text: "Restart Server"
            }

            // Quick logs button
            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: Qt.rgba(255, 255, 255, 0.08)
                Text {
                    anchors.centerIn: parent
                    text: "📄"
                    font.pixelSize: 11
                    color: "#fafafa"
                }
                MouseArea {
                    id: logsArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: { if (plasmoidItem) plasmoidItem.openLogs(); }
                }
                QQC2.ToolTip.visible: logsArea.containsMouse
                QQC2.ToolTip.text: "Open Logs"
            }

            // Keep Open / Pin button
            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: (plasmoidItem && plasmoidItem.pinned) ? "#ff2b4d" : Qt.rgba(255, 255, 255, 0.08)
                border.color: (plasmoidItem && plasmoidItem.pinned) ? "#ff4d6d" : "transparent"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "📌"
                    font.pixelSize: 11
                    color: (plasmoidItem && plasmoidItem.pinned) ? "#ffffff" : "#a1a1aa"
                }
                MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (plasmoidItem) {
                            plasmoidItem.pinned = !plasmoidItem.pinned;
                        }
                    }
                }
                QQC2.ToolTip.visible: pinArea.containsMouse
                QQC2.ToolTip.text: (plasmoidItem && plasmoidItem.pinned) ? "Unpin (close on outside click)" : "Keep open (pin)"
            }

            Text {
                text: plasmoidItem ? plasmoidItem.serverVersion : "v3.8.50"
                font.pixelSize: 11
                color: "#71717a"
            }
        }

        // ====================================================================
        // TOP NAVIGATION TABS (Server First, Monitor Second)
        // ====================================================================
        RowLayout {
            id: navRow
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { id: "supervisor", label: "🖥️ Server" },
                    { id: "monitor", label: "📊 Monitor" },
                    { id: "doctor", label: "🩺 Doctor & Logs" },
                    { id: "settings", label: "⚙ Settings" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 5
                    color: cardRoot.activeTab === modelData.id ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.03)
                    border.color: cardRoot.activeTab === modelData.id ? Qt.rgba(255, 255, 255, 0.20) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        font.weight: cardRoot.activeTab === modelData.id ? Font.Bold : Font.Normal
                        color: cardRoot.activeTab === modelData.id ? "#fafafa" : "#a1a1aa"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.activeTab = modelData.id
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(255, 255, 255, 0.10)
        }

        // ====================================================================
        // TAB 1: SERVER & SUPERVISOR VIEW
        // ====================================================================
        ColumnLayout {
            id: supervisorTab
            Layout.fillWidth: true
            spacing: 12
            visible: cardRoot.activeTab === "supervisor"

                    Rectangle {
                        Layout.fillWidth: true
                        height: 84
                        radius: 6
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Text {
                                    text: "Supervisor Status: "
                                    font.pixelSize: 11
                                    color: "#a1a1aa"
                                }
                                Text {
                                    text: {
                                        if (!plasmoidItem) return "Offline";
                                        if (plasmoidItem.serverActionState === "starting") return "Starting server...";
                                        if (plasmoidItem.serverActionState === "stopping") return "Stopping server...";
                                        if (plasmoidItem.serverActionState === "restarting") return "Restarting server...";
                                        return plasmoidItem.isRunning ? "Active" : "Offline";
                                    }
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: {
                                        if (!plasmoidItem) return "#ff2b4d";
                                        if (plasmoidItem.serverActionState !== "") return "#f59e0b";
                                        return plasmoidItem.isRunning ? "#22c55e" : "#ff2b4d";
                                    }
                                }
                            }

                            RowLayout {
                                Text {
                                    text: "Server Process: "
                                    font.pixelSize: 11
                                    color: "#a1a1aa"
                                }
                                Text {
                                    text: (plasmoidItem && plasmoidItem.isRunning && plasmoidItem.serverPid) ? ("PID " + plasmoidItem.serverPid + " · Port 20128") : "Port 20128 · Standby"
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                    color: "#fafafa"
                                }
                            }

                            RowLayout {
                                Text {
                                    text: "Mode: "
                                    font.pixelSize: 11
                                    color: "#a1a1aa"
                                }
                                Text {
                                    text: "Local AI Gateway · Background daemon"
                                    font.pixelSize: 11
                                    color: "#a1a1aa"
                                }
                            }
                        }
                    }

                    // Server lifecycle buttons (Primary Start/Stop on LEFT, Restart on RIGHT)
                    RowLayout {
                        id: btnRow
                        Layout.fillWidth: true
                        spacing: 8

                        readonly property bool isBusy: plasmoidItem && plasmoidItem.serverActionState !== ""

                        // 1. PRIMARY ACTION (LEFT): Start / Stop Server
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 6
                            color: {
                                if (!plasmoidItem) return "#1a3a20";
                                if (plasmoidItem.serverActionState === "starting") return "#2e2413";
                                if (plasmoidItem.serverActionState === "stopping") return "#2e1518";
                                if (plasmoidItem.serverActionState === "restarting") return "#2e2413";
                                return plasmoidItem.isRunning ? "#3a1b20" : "#1a3a20";
                            }
                            border.color: {
                                if (!plasmoidItem) return "#22c55e";
                                if (plasmoidItem.serverActionState !== "") return "#f59e0b";
                                return plasmoidItem.isRunning ? "#ff2b4d" : "#22c55e";
                            }
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    visible: btnRow.isBusy
                                    text: "⟳"
                                    font.pixelSize: 13
                                    color: "#fbbf24"
                                    RotationAnimation on rotation {
                                        running: btnRow.isBusy
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 750
                                    }
                                }

                                Text {
                                    text: {
                                        if (!plasmoidItem) return "▶ Start Server";
                                        if (plasmoidItem.serverActionState === "starting") return "Starting...";
                                        if (plasmoidItem.serverActionState === "stopping") return "Stopping...";
                                        if (plasmoidItem.serverActionState === "restarting") return "Stopping...";
                                        return plasmoidItem.isRunning ? "⏹ Stop Server" : "▶ Start Server";
                                    }
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: {
                                        if (!plasmoidItem) return "#4ade80";
                                        if (plasmoidItem.serverActionState !== "") return "#fbbf24";
                                        return plasmoidItem.isRunning ? "#ff8095" : "#4ade80";
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: btnRow.isBusy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                enabled: !btnRow.isBusy
                                onClicked: {
                                    if (!plasmoidItem || btnRow.isBusy) return;
                                    if (plasmoidItem.isRunning) plasmoidItem.stopServer();
                                    else plasmoidItem.startServer();
                                }
                            }
                        }

                        // 2. SECONDARY ACTION (RIGHT): Restart Server
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 6
                            color: (plasmoidItem && plasmoidItem.serverActionState === "restarting") ? 
                                   "#2e2413" : Qt.rgba(255, 255, 255, 0.08)
                            border.color: (plasmoidItem && plasmoidItem.serverActionState === "restarting") ? 
                                          "#f59e0b" : Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    visible: plasmoidItem && plasmoidItem.serverActionState === "restarting"
                                    text: "⟳"
                                    font.pixelSize: 13
                                    color: "#fbbf24"
                                    RotationAnimation on rotation {
                                        running: plasmoidItem && plasmoidItem.serverActionState === "restarting"
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 750
                                    }
                                }

                                Text {
                                    text: (plasmoidItem && plasmoidItem.serverActionState === "restarting") ? 
                                          "Restarting..." : "↻ Restart Server"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: (plasmoidItem && plasmoidItem.serverActionState === "restarting") ? 
                                           "#fbbf24" : "#fafafa"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: btnRow.isBusy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                enabled: !btnRow.isBusy
                                onClicked: {
                                    if (!plasmoidItem || btnRow.isBusy) return;
                                    plasmoidItem.restartServer();
                                }
                            }
                        }
                    }

                    // Start on login
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 6
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            QQC2.CheckBox {
                                text: "Launch OmniRoute automatically on login"
                                checked: plasmoidItem ? plasmoidItem.autostartEnabled : false
                                onClicked: { if (plasmoidItem) plasmoidItem.toggleAutostart(); }
                            }
                        }
                    }

                    // Auto-update
                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: 6
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            ColumnLayout {
                                Text {
                                    text: "Auto-Update"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#fafafa"
                                }
                                Text {
                                    text: plasmoidItem ? plasmoidItem.updateStatus : "v3.8.50"
                                    font.pixelSize: 10
                                    color: "#a1a1aa"
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 84
                                height: 26
                                radius: 4
                                color: Qt.rgba(255, 255, 255, 0.08)
                                border.color: Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Check Now"
                                    font.pixelSize: 10
                                    color: "#fafafa"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (plasmoidItem) plasmoidItem.checkForUpdates(); }
                                }
                            }
                        }
                    }

        }

        // ====================================================================
        // TAB 2: MONITOR VIEW (SCROLLABLE TO PREVENT CLIPPING ON HIGH-DPI/LAPTOPS)
        // ====================================================================
        PlasmaComponents.ScrollView {
            id: monitorScrollView
            Layout.fillWidth: true
            Layout.fillHeight: cardRoot.activeTab === "monitor"
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            visible: cardRoot.activeTab === "monitor"
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            contentWidth: availableWidth
            contentHeight: monitorTab.implicitHeight

            ColumnLayout {
                id: monitorTab
                width: monitorScrollView.availableWidth
                spacing: 12

                    // Health status band
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 5
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            Text {
                                text: (plasmoidItem ? plasmoidItem.healthActiveProviders : 0) + " of " + 
                                      (plasmoidItem ? plasmoidItem.healthConfiguredProviders : 0) + " providers active · " +
                                      (plasmoidItem ? plasmoidItem.healthBreakersOpen : 0) + " breakers open"
                                font.pixelSize: 11
                                color: "#d4d4d8"
                            }
                        }
                    }

                    // 1. Provider Quota Bars
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: (plasmoidItem ? plasmoidItem.providerQuotasModel.length : 0) > 0

                        Text {
                            text: "PROVIDER QUOTAS"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: "#a1a1aa"
                        }

                        Repeater {
                            model: plasmoidItem ? plasmoidItem.providerQuotasModel : []
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: modelData.provider
                                    font.pixelSize: 11
                                    color: "#fafafa"
                                    Layout.preferredWidth: 80
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 6
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.10)
                                    Rectangle {
                                        height: parent.height
                                        radius: 3
                                        width: parent.width * (modelData.remaining / 100)
                                        color: Utils.statusColor(modelData.remaining)
                                    }
                                }

                                Text {
                                    text: Math.round(modelData.remaining) + "%"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.family: "monospace"
                                    color: Utils.statusColor(modelData.remaining)
                                    Layout.preferredWidth: 35
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    text: modelData.state
                                    font.pixelSize: 10
                                    color: "#71717a"
                                    Layout.preferredWidth: 60
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    // 2. Connected Accounts & Rate Limits
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: (plasmoidItem ? plasmoidItem.usageAccountsModel.length : 0) > 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "RATE LIMITS & SESSIONS"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 54
                                height: 20
                                radius: 3
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: (plasmoidItem && plasmoidItem.showUsed) ? "% used" : "% left"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: "#d4d4d8"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (plasmoidItem) plasmoidItem.toggleShowUsed(); }
                                }
                            }
                        }

                        Repeater {
                            model: plasmoidItem ? plasmoidItem.usageAccountsModel : []
                            delegate: ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: modelData.account + " (" + modelData.provider + ")"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#fafafa"
                                }

                                Repeater {
                                    model: modelData.windows
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            width: 30
                                            height: 16
                                            radius: 3
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.shortTag
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                font.family: "monospace"
                                                color: "#a1a1aa"
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 6
                                            radius: 3
                                            color: Qt.rgba(255, 255, 255, 0.10)
                                            Rectangle {
                                                height: parent.height
                                                radius: 3
                                                width: Math.max(0, parent.width * (
                                                    (plasmoidItem && plasmoidItem.showUsed) ? 
                                                    (modelData.usedPct / 100) : 
                                                    (modelData.remainingPct / 100)
                                                ))
                                                color: Utils.statusColor(modelData.remainingPct)
                                            }
                                        }

                                        Text {
                                            text: Math.round(
                                                (plasmoidItem && plasmoidItem.showUsed) ? 
                                                modelData.usedPct : 
                                                modelData.remainingPct
                                            ) + "%"
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            font.family: "monospace"
                                            color: Utils.statusColor(modelData.remainingPct)
                                            Layout.preferredWidth: 35
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Text {
                                            text: modelData.countdown
                                            font.pixelSize: 10
                                            color: "#71717a"
                                            Layout.preferredWidth: 80
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Cost & Spend
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "COST & TOKENS"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                            }
                            Item { Layout.fillWidth: true }
                            Row {
                                spacing: 3
                                Repeater {
                                    model: [
                                        {lbl: "1D", val: "1d"},
                                        {lbl: "7D", val: "7d"},
                                        {lbl: "30D", val: "30d"}
                                    ]
                                    Rectangle {
                                        width: 30
                                        height: 20
                                        radius: 3
                                        color: (plasmoidItem && plasmoidItem.costRange === modelData.val) ? "#ff2b4d" : Qt.rgba(255, 255, 255, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.lbl
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: "#ffffff"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (plasmoidItem) plasmoidItem.setCostRange(modelData.val); }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 24
                                    height: 20
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "%"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: (plasmoidItem && plasmoidItem.showCostPct) ? "#ff2b4d" : "#a1a1aa"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (plasmoidItem) plasmoidItem.toggleShowCostPct(); }
                                    }
                                }
                            }
                        }

                        Text {
                            text: Utils.formatCost(plasmoidItem ? plasmoidItem.costTotalUsd : 0) + " · " + 
                                  Utils.formatTokens(plasmoidItem ? plasmoidItem.costTotalTokens : 0)
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#fafafa"
                        }

                        Repeater {
                            model: plasmoidItem ? plasmoidItem.costRowsModel : []
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: modelData.model
                                    font.pixelSize: 11
                                    color: "#d4d4d8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: (plasmoidItem && plasmoidItem.showCostPct) ?
                                          (Utils.formatCost(modelData.costUsd) + " (" + modelData.costPct.toFixed(1) + "%)") :
                                          (Utils.formatCost(modelData.costUsd) + " · " + Utils.compactTokens(modelData.tokensIn + modelData.tokensOut))
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                    color: "#fafafa"
                                }
                            }
                        }
                    }

                    // 4. Trend sparkline
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "30-DAY USAGE TREND"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Today: " + Utils.formatCost(plasmoidItem ? plasmoidItem.todaySpend : 0)
                                font.pixelSize: 10
                                color: "#a1a1aa"
                            }
                        }

                        TrendChart {
                            Layout.fillWidth: true
                            points: plasmoidItem ? plasmoidItem.trendPointsModel : []
                        }
                    }
                }
        }

        // ====================================================================
        // TAB 3: DOCTOR & LOGS VIEW (SCROLLABLE)
        // ====================================================================
        PlasmaComponents.ScrollView {
            id: doctorScrollView
            Layout.fillWidth: true
            Layout.fillHeight: cardRoot.activeTab === "doctor"
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            visible: cardRoot.activeTab === "doctor"
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            contentWidth: availableWidth
            contentHeight: doctorTab.implicitHeight

            ColumnLayout {
                id: doctorTab
                width: doctorScrollView.availableWidth
                spacing: 10

                    Text {
                        text: "DIAGNOSTICS REPORT"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: "#a1a1aa"
                    }

                    Repeater {
                        model: plasmoidItem ? plasmoidItem.doctorModel : []
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: modelData.status === "ok" ? "✓" : (modelData.status === "warn" ? "⚠" : "✗")
                                font.pixelSize: 12
                                color: modelData.status === "ok" ? "#22c55e" : (modelData.status === "warn" ? "#f59e0b" : "#ff2b4d")
                            }
                            Text {
                                text: modelData.name + ":"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: "#fafafa"
                            }
                            Text {
                                text: modelData.detail
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: "#a1a1aa"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "RECENT SERVER LOGS"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: "#a1a1aa"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Open File ↗"
                            font.pixelSize: 10
                            color: "#ff2b4d"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (plasmoidItem) plasmoidItem.openLogs(); }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 110
                        radius: 5
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            model: plasmoidItem ? plasmoidItem.recentLogsModel : []
                            delegate: Text {
                                width: parent.width
                                text: modelData
                                font.pixelSize: 9
                                font.family: "monospace"
                                color: "#9ca3af"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
        }

        // ====================================================================
        // TAB 4: SETTINGS VIEW (BEAUTIFULLY ALIGNED & STRUCTURED IN CARDS)
        // ====================================================================
        ColumnLayout {
            id: settingsTab
            Layout.fillWidth: true
            spacing: 12
            visible: cardRoot.activeTab === "settings"

            // 1. Section Visibility Card (Matching Server & Monitor card styling)
            Rectangle {
                Layout.fillWidth: true
                height: 180
                radius: 6
                color: Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "MONITOR SECTION VISIBILITY"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: "#a1a1aa"
                    }

                    QQC2.CheckBox {
                        text: "Provider health overview"
                        checked: !plasmoidItem || plasmoidItem.showHealth
                        onCheckedChanged: { if (plasmoidItem) plasmoidItem.setSectionVisible("health", checked); }
                    }
                    QQC2.CheckBox {
                        text: "Usage & quota bars"
                        checked: !plasmoidItem || plasmoidItem.showUsage
                        onCheckedChanged: { if (plasmoidItem) plasmoidItem.setSectionVisible("usage", checked); }
                    }
                    QQC2.CheckBox {
                        text: "Cost & token breakdown"
                        checked: !plasmoidItem || plasmoidItem.showCost
                        onCheckedChanged: { if (plasmoidItem) plasmoidItem.setSectionVisible("cost", checked); }
                    }
                    QQC2.CheckBox {
                        text: "30-Day spend trend chart"
                        checked: !plasmoidItem || plasmoidItem.showTrend
                        onCheckedChanged: { if (plasmoidItem) plasmoidItem.setSectionVisible("trend", checked); }
                    }
                }
            }

            // 2. Preferences & Daemon Card
            Rectangle {
                Layout.fillWidth: true
                height: 60
                radius: 6
                color: Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Text {
                            text: "Start on Login"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#fafafa"
                        }
                        Text {
                            text: "Launch OmniRoute daemon on desktop login"
                            font.pixelSize: 10
                            color: "#a1a1aa"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    QQC2.CheckBox {
                        checked: plasmoidItem ? plasmoidItem.autostartEnabled : false
                        onClicked: { if (plasmoidItem) plasmoidItem.toggleAutostart(); }
                    }
                }
            }
        }

        // ====================================================================
        // CARD FOOTER
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(255, 255, 255, 0.08)
        }

        RowLayout {
            id: footerRow
            Layout.fillWidth: true
            spacing: 8

            // Port badge
            Rectangle {
                height: 22
                width: 115
                radius: 4
                color: Qt.rgba(255, 255, 255, 0.08)
                border.color: Qt.rgba(255, 255, 255, 0.12)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "OmniRoute"
                        font.pixelSize: 10
                        color: "#a1a1aa"
                    }
                    Text {
                        text: ":20128"
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("http://127.0.0.1:20128")
                }
            }

            Item { Layout.fillWidth: true }

            // Reload button
            Text {
                text: "⟳"
                font.pixelSize: 15
                color: "#a1a1aa"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (plasmoidItem) plasmoidItem.refreshAll(); }
                }
            }

            // GitHub button
            Image {
                width: 16
                height: 16
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23a1a1aa'><path d='M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z'/></svg>"
                opacity: githubArea.containsMouse ? 1.0 : 0.7
                MouseArea {
                    id: githubArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Qt.openUrlExternally("https://github.com/diegosouzapw/OmniRoute")
                }
            }
        }
    }
}
