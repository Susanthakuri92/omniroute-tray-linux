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

    readonly property real headerHeight: (headerRow ? headerRow.implicitHeight : 20) +
                                         (navRow ? navRow.implicitHeight : 24) +
                                         1 + (contentCol.spacing * 2)
    readonly property real footerHeight: 1 + (footerRow ? footerRow.implicitHeight : 20) +
                                         (contentCol.spacing * 2)
    readonly property real marginsHeight: 16

    // Fixed uniform height across all 4 tabs to prevent UI shifting
    readonly property real activeTabHeight: 380

    readonly property real desiredHeight: headerHeight + activeTabHeight + footerHeight + marginsHeight

    implicitHeight: Math.min(Layout.maximumHeight, Math.max(Layout.minimumHeight, desiredHeight))
    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: 220
    Layout.maximumHeight: 780
    height: Layout.preferredHeight

    property string activeTab: "supervisor" // "supervisor", "monitor", "doctor", "updates"

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ====================================================================
        // CARD HEADER & STATUS
        // ====================================================================
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 6

            // Status dot
            Rectangle {
                id: headerDot
                width: 8
                height: 8
                radius: 4
                color: {
                    if (plasmoidItem && plasmoidItem.serverActionState !== "") return "#f59e0b";
                    return (plasmoidItem && plasmoidItem.isRunning) ? "#10b981" : "#ef4444";
                }
                SequentialAnimation on opacity {
                    running: plasmoidItem && plasmoidItem.serverActionState !== ""
                    loops: Animation.Infinite
                    PropertyAnimation { to: 0.3; duration: 350 }
                    PropertyAnimation { to: 1.0; duration: 350 }
                }
            }

            Text {
                text: "OmniRoute"
                font.pixelSize: 13
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
                    if (!plasmoidItem) return "#f87171";
                    if (plasmoidItem.serverActionState !== "") return "#fbbf24";
                    return plasmoidItem.isRunning ? "#34d399" : "#f87171";
                }
            }

            Item { Layout.fillWidth: true }

            // Quick logs icon
            Rectangle {
                width: 24
                height: 22
                radius: 4
                color: logsArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : "transparent"
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

            Text {
                text: plasmoidItem ? plasmoidItem.serverVersion : "unknown"
                font.pixelSize: 10
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
                    { id: "doctor", label: "🩺 Doctor" },
                    { id: "updates", label: "🔄 Updates" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    radius: 5
                    color: cardRoot.activeTab === modelData.id ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.03)
                    border.color: cardRoot.activeTab === modelData.id ? Qt.rgba(255, 255, 255, 0.18) : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 10
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
            color: Qt.rgba(255, 255, 255, 0.08)
        }

        // ====================================================================
        // TAB 1: SERVER & SUPERVISOR VIEW
        // ====================================================================
        ColumnLayout {
            id: supervisorTab
            Layout.fillWidth: true
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            spacing: 8
            visible: cardRoot.activeTab === "supervisor"

            // 1. Status Overview Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 74
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.04)
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
                                if (!plasmoidItem) return "#ef4444";
                                if (plasmoidItem.serverActionState !== "") return "#f59e0b";
                                return plasmoidItem.isRunning ? "#10b981" : "#ef4444";
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
                            text: (plasmoidItem && plasmoidItem.isRunning && plasmoidItem.serverPid) ?
                                  ("PID " + plasmoidItem.serverPid + " · Port 20128") :
                                  "Port 20128 · Standby"
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
                            color: "#71717a"
                        }
                    }
                }
            }

            // 2. Modern & Professional Server Action Buttons
            RowLayout {
                id: btnRow
                Layout.fillWidth: true
                spacing: 8

                readonly property bool isBusy: plasmoidItem && plasmoidItem.serverActionState !== ""
                readonly property bool isRunning: plasmoidItem && plasmoidItem.isRunning

                // PRIMARY ACTION (LEFT): Start / Stop Server
                Rectangle {
                    id: startStopBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10

                    color: {
                        if (btnRow.isBusy) return Qt.rgba(245, 158, 11, 0.12);
                        if (btnRow.isRunning) {
                            return mouseAreaStartStop.containsMouse ?
                                   Qt.rgba(239, 68, 68, 0.16) :
                                   Qt.rgba(239, 68, 68, 0.08);
                        }
                        return mouseAreaStartStop.containsMouse ?
                               Qt.rgba(16, 185, 129, 0.16) :
                               Qt.rgba(16, 185, 129, 0.08);
                    }

                    border.color: {
                        if (btnRow.isBusy) return Qt.rgba(245, 158, 11, 0.45);
                        if (btnRow.isRunning) {
                            return mouseAreaStartStop.containsMouse ?
                                   Qt.rgba(239, 68, 68, 0.50) :
                                   Qt.rgba(239, 68, 68, 0.25);
                        }
                        return mouseAreaStartStop.containsMouse ?
                               Qt.rgba(16, 185, 129, 0.50) :
                               Qt.rgba(16, 185, 129, 0.25);
                    }
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: {
                                if (btnRow.isBusy) return "↻";
                                return btnRow.isRunning ? "■" : "▶";
                            }
                            font.pixelSize: btnRow.isRunning ? 13 : 11
                            color: {
                                if (btnRow.isBusy) return "#fbbf24";
                                return btnRow.isRunning ? "#ef4444" : "#10b981";
                            }
                        }

                        Text {
                            text: {
                                if (!plasmoidItem) return "Start Server";
                                if (btnRow.isBusy) return "Applying...";
                                return btnRow.isRunning ? "Stop Server" : "Start Server";
                            }
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: {
                                if (btnRow.isBusy) return "#fef3c7";
                                return btnRow.isRunning ? "#fee2e2" : "#ecfdf5";
                            }
                        }
                    }

                    MouseArea {
                        id: mouseAreaStartStop
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: btnRow.isBusy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!plasmoidItem || btnRow.isBusy) return;
                            if (plasmoidItem.isRunning) plasmoidItem.stopServer();
                            else plasmoidItem.startServer();
                        }
                    }
                }

                // RESTART BUTTON (RIGHT): Polished Neutral Utility Theme
                Rectangle {
                    id: restartBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10

                    color: {
                        if (plasmoidItem && plasmoidItem.serverActionState === "restarting") {
                            return Qt.rgba(245, 158, 11, 0.12);
                        }
                        return restartArea.containsMouse ?
                               Qt.rgba(255, 255, 255, 0.10) :
                               Qt.rgba(255, 255, 255, 0.04);
                    }

                    border.color: {
                        if (plasmoidItem && plasmoidItem.serverActionState === "restarting") {
                            return Qt.rgba(245, 158, 11, 0.45);
                        }
                        return restartArea.containsMouse ?
                               Qt.rgba(255, 255, 255, 0.22) :
                               Qt.rgba(255, 255, 255, 0.10);
                    }
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "↻"
                            font.pixelSize: 13
                            color: {
                                if (plasmoidItem && plasmoidItem.serverActionState === "restarting") {
                                    return "#fbbf24";
                                }
                                return restartArea.containsMouse ? "#ffffff" : "#a1a1aa";
                            }
                        }
                        Text {
                            text: (plasmoidItem && plasmoidItem.serverActionState === "restarting") ?
                                  "Restarting..." : "Restart"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: {
                                if (plasmoidItem && plasmoidItem.serverActionState === "restarting") {
                                    return "#fbbf24";
                                }
                                return restartArea.containsMouse ? "#ffffff" : "#e4e4e7";
                            }
                        }
                    }
                    MouseArea {
                        id: restartArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: btnRow.isBusy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        enabled: !btnRow.isBusy
                        onClicked: { if (plasmoidItem) plasmoidItem.restartServer(); }
                    }
                }
            }

            // 3. Autostart Preference Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.04)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Text {
                        text: "Launch Omniroute server automatically on login"
                        font.pixelSize: 11
                        color: "#d4d4d8"
                        Layout.fillWidth: true
                    }

                    QQC2.CheckBox {
                        checked: plasmoidItem ? plasmoidItem.autostartEnabled : false
                        onClicked: { if (plasmoidItem) plasmoidItem.toggleAutostart(); }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ====================================================================
        // TAB 2: MONITOR VIEW (SCROLLABLE TO PREVENT CLIPPING ON HIGH-DPI/LAPTOPS)
        // ====================================================================
        PlasmaComponents.ScrollView {
            id: monitorScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            visible: cardRoot.activeTab === "monitor"
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            contentWidth: availableWidth
            contentHeight: monitorTab.implicitHeight + 16

            ColumnLayout {
                id: monitorTab
                width: monitorScrollView.availableWidth
                spacing: 8

                // Section: Health Status
                Rectangle {
                    Layout.fillWidth: true
                    height: 62
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 3

                        Text {
                            text: "SYSTEM HEALTH"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: "#a1a1aa"
                        }

                        Text {
                            text: (plasmoidItem ? plasmoidItem.healthActiveProviders : 0) + " of " +
                                  (plasmoidItem ? plasmoidItem.healthConfiguredProviders : 0) + " providers active · " +
                                  (plasmoidItem ? plasmoidItem.healthBreakersOpen : 0) + " breakers open"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#fafafa"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // 1. Provider Quota Bars
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: quotaLayout.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: quotaLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

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
                            }
                        }
                    }
                }

                // 2. Connected Accounts & Rate Limits
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: rateLimitsLayout.implicitHeight + 16
                    visible: (plasmoidItem ? plasmoidItem.usageAccountsModel.length : 0) > 0
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: rateLimitsLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "RATE LIMITS & SESSIONS"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 54
                                height: 20
                                radius: 4
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
                                            width: 32
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
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Cost & Spend
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: costLayout.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: costLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "COST & TOKENS"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Row {
                                Layout.alignment: Qt.AlignRight
                                spacing: 3
                                Repeater {
                                    model: [
                                        {lbl: "1D", val: "1d"},
                                        {lbl: "7D", val: "7d"},
                                        {lbl: "30D", val: "30d"}
                                    ]
                                    Rectangle {
                                        width: 28
                                        height: 18
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
                                    width: 22
                                    height: 18
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
                            font.pixelSize: 13
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
                }

                // 4. Trend sparkline
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: trendLayout.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: trendLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "30-DAY USAGE TREND"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: "#a1a1aa"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "Today: " + Utils.formatCost(plasmoidItem ? plasmoidItem.todaySpend : 0)
                                font.pixelSize: 10
                                color: "#a1a1aa"
                                Layout.alignment: Qt.AlignRight
                            }
                        }

                        TrendChart {
                            Layout.fillWidth: true
                            points: plasmoidItem ? plasmoidItem.trendPointsModel : []
                        }
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
            Layout.fillHeight: true
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            visible: cardRoot.activeTab === "doctor"
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            contentWidth: availableWidth
            contentHeight: doctorTab.implicitHeight + 16

            ColumnLayout {
                id: doctorTab
                width: doctorScrollView.availableWidth
                spacing: 8

                // Diagnostics Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: diagLayout.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        id: diagLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

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
                                    color: modelData.status === "ok" ? "#10b981" : (modelData.status === "warn" ? "#f59e0b" : "#ef4444")
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
                    }
                }

                // Recent Logs Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: logsHeaderLayout.implicitHeight + 120 + 20
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            id: logsHeaderLayout
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
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.40)
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
            }
        }

        // ====================================================================
        // TAB 4: UPDATES VIEW
        // ====================================================================
        PlasmaComponents.ScrollView {
            id: updatesScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: cardRoot.activeTabHeight
            clip: true
            visible: cardRoot.activeTab === "updates"
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            contentWidth: availableWidth
            contentHeight: updatesTab.implicitHeight + 16

            ColumnLayout {
                id: updatesTab
                width: updatesScrollView.availableWidth
                spacing: 10

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Software & Updates"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#fafafa"
                    }
                    Text {
                        text: {
                            if (!plasmoidItem) return "Last checked: never";
                            if (!plasmoidItem.updateLastChecked && !plasmoidItem.trayUpdateLastChecked) return "Last checked: never";
                            if (plasmoidItem.updateLastChecked) return "Server checked today at " + plasmoidItem.updateLastChecked;
                            return "Checked at " + plasmoidItem.trayUpdateLastChecked;
                        }
                        font.pixelSize: 10
                        color: "#71717a"
                    }
                }

                Item { Layout.fillWidth: true }

                // Status summary badge
                Rectangle {
                    height: 22
                    radius: 11
                    color: {
                        if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return Qt.rgba(56, 189, 248, 0.12);
                        if (plasmoidItem && (plasmoidItem.updateError || plasmoidItem.trayUpdateError)) return Qt.rgba(239, 68, 68, 0.12);
                        if (plasmoidItem && (plasmoidItem.isCheckingUpdate || plasmoidItem.isUpdatingTray)) return Qt.rgba(245, 158, 11, 0.12);
                        return Qt.rgba(16, 185, 129, 0.12);
                    }
                    border.color: {
                        if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return Qt.rgba(56, 189, 248, 0.35);
                        if (plasmoidItem && (plasmoidItem.updateError || plasmoidItem.trayUpdateError)) return Qt.rgba(239, 68, 68, 0.35);
                        if (plasmoidItem && (plasmoidItem.isCheckingUpdate || plasmoidItem.isUpdatingTray)) return Qt.rgba(245, 158, 11, 0.35);
                        return Qt.rgba(16, 185, 129, 0.35);
                    }
                    border.width: 1
                    implicitWidth: channelText.implicitWidth + 18

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: {
                                if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return "#38bdf8";
                                if (plasmoidItem && (plasmoidItem.updateError || plasmoidItem.trayUpdateError)) return "#ef4444";
                                if (plasmoidItem && (plasmoidItem.isCheckingUpdate || plasmoidItem.isUpdatingTray)) return "#f59e0b";
                                return "#10b981";
                            }
                        }
                        Text {
                            id: channelText
                            text: {
                                if (!plasmoidItem) return "Stable";
                                if (plasmoidItem.isCheckingUpdate || plasmoidItem.isUpdatingTray) return "Checking…";
                                if (plasmoidItem.serverUpdateAvailable) return "Update Available";
                                if (plasmoidItem.updateError || plasmoidItem.trayUpdateError) return "Check Failed";
                                return "Up to Date";
                            }
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: {
                                if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return "#38bdf8";
                                if (plasmoidItem && (plasmoidItem.updateError || plasmoidItem.trayUpdateError)) return "#f87171";
                                if (plasmoidItem && (plasmoidItem.isCheckingUpdate || plasmoidItem.isUpdatingTray)) return "#fbbf24";
                                return "#34d399";
                            }
                        }
                    }
                }
            }

            // ================================================================
            // Card 1: OmniRoute Server
            // ================================================================
            Rectangle {
                Layout.fillWidth: true
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.03)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1
                implicitHeight: serverCol.implicitHeight + 20

                ColumnLayout {
                    id: serverCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Title Row: Title + GitHub Icon (side of title with hover effect) + Version Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "OmniRoute Server"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: "#fafafa"
                        }

                        // GitHub Link Icon on side of title with hover effect
                        Rectangle {
                            id: serverGhPill
                            width: 22
                            height: 22
                            radius: 4
                            color: serverGhMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                            border.color: serverGhMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Image {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                source: Qt.resolvedUrl("../icons/github.svg")
                                opacity: serverGhMouse.containsMouse ? 1.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: serverGhMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://github.com/diegosouzapw/OmniRoute")
                            }

                            QQC2.ToolTip.visible: serverGhMouse.containsMouse
                            QQC2.ToolTip.text: "Open diegosouzapw/OmniRoute on GitHub ↗"
                        }

                        Item { Layout.fillWidth: true }

                        // Version badge
                        Rectangle {
                            height: 20
                            radius: 4
                            color: Qt.rgba(255, 255, 255, 0.06)
                            implicitWidth: serverVerText.implicitWidth + 10

                            Text {
                                id: serverVerText
                                anchors.centerIn: parent
                                text: {
                                    var v = (plasmoidItem && plasmoidItem.serverVersion) ? plasmoidItem.serverVersion : "unknown";
                                    return v.startsWith("v") ? v : ("v" + v);
                                }
                                font.pixelSize: 10
                                font.family: "monospace"
                                font.weight: Font.Medium
                                color: "#e4e4e7"
                            }
                        }
                    }

                    // Status & Action Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Status with dot indicator
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: {
                                    if (plasmoidItem && plasmoidItem.isCheckingUpdate) return "#f59e0b";
                                    if (plasmoidItem && plasmoidItem.updateError) return "#ef4444";
                                    if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return "#38bdf8";
                                    return "#10b981";
                                }
                            }

                            Text {
                                text: {
                                    if (!plasmoidItem) return "Ready";
                                    if (plasmoidItem.isCheckingUpdate) return "Checking npm registry…";
                                    if (plasmoidItem.updateError) return plasmoidItem.updateErrorMsg || "Couldn't reach npm";
                                    if (plasmoidItem.serverUpdateAvailable) return "Update available: v" + plasmoidItem.serverLatestVersion;
                                    return "Up to date with latest release";
                                }
                                font.pixelSize: 11
                                color: {
                                    if (plasmoidItem && plasmoidItem.updateError) return "#f87171";
                                    if (plasmoidItem && plasmoidItem.serverUpdateAvailable) return "#38bdf8";
                                    return "#a1a1aa";
                                }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        // Clean Check Updates button
                        Rectangle {
                            height: 26
                            radius: 5
                            color: checkServerMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                            border.color: checkServerMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.10)
                            border.width: 1
                            implicitWidth: checkServerLabel.implicitWidth + 18

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: checkServerLabel
                                anchors.centerIn: parent
                                text: (plasmoidItem && plasmoidItem.isCheckingUpdate) ? "Checking…" : "Check for Updates"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: checkServerMouse.containsMouse ? "#ffffff" : "#d4d4d8"
                            }

                            MouseArea {
                                id: checkServerMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: { if (plasmoidItem) plasmoidItem.checkForUpdates(); }
                            }
                        }
                    }

                    // Update Available Command Bar (only appears when an update exists)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 5
                        color: Qt.rgba(56, 189, 248, 0.08)
                        border.color: Qt.rgba(56, 189, 248, 0.25)
                        border.width: 1
                        visible: plasmoidItem && plasmoidItem.serverUpdateAvailable

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 4
                            spacing: 6

                            TextInput {
                                id: serverCmdText
                                Layout.fillWidth: true
                                text: "npm i -g omniroute@" + (plasmoidItem ? plasmoidItem.serverLatestVersion : "latest")
                                font.family: "monospace"
                                font.pixelSize: 10
                                color: "#e4e4e7"
                                readOnly: true
                                selectByMouse: true
                            }

                            Rectangle {
                                id: serverCopyBtn
                                height: 22
                                radius: 4
                                property bool copied: false
                                color: serverCopyMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                                implicitWidth: serverCopyLabel.implicitWidth + 12

                                Text {
                                    id: serverCopyLabel
                                    anchors.centerIn: parent
                                    text: serverCopyBtn.copied ? "✓ Copied" : "Copy"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: serverCopyBtn.copied ? "#34d399" : "#ffffff"
                                }

                                MouseArea {
                                    id: serverCopyMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        serverCmdText.selectAll();
                                        serverCmdText.copy();
                                        serverCopyBtn.copied = true;
                                        serverCopyTimer.restart();
                                    }
                                }

                                Timer {
                                    id: serverCopyTimer
                                    interval: 1800
                                    onTriggered: serverCopyBtn.copied = false
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // Card 2: OmniRoute Tray
            // ================================================================
            Rectangle {
                Layout.fillWidth: true
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.03)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1
                implicitHeight: trayCol.implicitHeight + 20

                ColumnLayout {
                    id: trayCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Title Row: Title + GitHub Icon (side of title with hover effect) + Version & Commit Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "OmniRoute Tray"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: "#fafafa"
                        }

                        // GitHub Link Icon on side of title with hover effect
                        Rectangle {
                            id: trayGhPill
                            width: 22
                            height: 22
                            radius: 4
                            color: trayGhMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                            border.color: trayGhMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Image {
                                anchors.centerIn: parent
                                width: 13
                                height: 13
                                source: Qt.resolvedUrl("../icons/github.svg")
                                opacity: trayGhMouse.containsMouse ? 1.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: trayGhMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://github.com/Susanthakuri92/omniroute-tray-linux")
                            }

                            QQC2.ToolTip.visible: trayGhMouse.containsMouse
                            QQC2.ToolTip.text: "Open Susanthakuri92/omniroute-tray-linux on GitHub ↗"
                        }

                        Item { Layout.fillWidth: true }

                        // Version & Commit badge
                        Rectangle {
                            height: 20
                            radius: 4
                            color: Qt.rgba(255, 255, 255, 0.06)
                            implicitWidth: trayVerText.implicitWidth + 10

                            Text {
                                id: trayVerText
                                anchors.centerIn: parent
                                text: {
                                    var v = (plasmoidItem && plasmoidItem.trayVersion) ? ("v" + plasmoidItem.trayVersion) : "v1.1.0";
                                    var c = (plasmoidItem && plasmoidItem.trayCommit && plasmoidItem.trayCommit !== "unknown") ? ("#" + plasmoidItem.trayCommit) : "";
                                    return c ? (v + " · " + c) : v;
                                }
                                font.pixelSize: 10
                                font.family: "monospace"
                                font.weight: Font.Medium
                                color: "#e4e4e7"
                            }
                        }
                    }

                    // Status & Action Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Status with dot indicator
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: {
                                    if (plasmoidItem && plasmoidItem.isUpdatingTray) return "#f59e0b";
                                    if (plasmoidItem && plasmoidItem.trayUpdateError) return "#ef4444";
                                    return "#10b981";
                                }
                            }

                            Text {
                                text: {
                                    if (!plasmoidItem) return "Ready";
                                    if (plasmoidItem.isUpdatingTray) return "Pulling latest git changes…";
                                    if (plasmoidItem.trayUpdateError) return plasmoidItem.trayUpdateErrorMsg || "Git pull failed";
                                    return plasmoidItem.trayUpdateStatus || "Up to date with GitHub main";
                                }
                                font.pixelSize: 11
                                color: {
                                    if (plasmoidItem && plasmoidItem.trayUpdateError) return "#f87171";
                                    return "#a1a1aa";
                                }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        // Clean Update Tray button
                        Rectangle {
                            height: 26
                            radius: 5
                            color: checkTrayMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                            border.color: checkTrayMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.10)
                            border.width: 1
                            implicitWidth: checkTrayLabel.implicitWidth + 18

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: checkTrayLabel
                                anchors.centerIn: parent
                                text: (plasmoidItem && plasmoidItem.isUpdatingTray) ? "Updating…" : "Update Tray"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: checkTrayMouse.containsMouse ? "#ffffff" : "#d4d4d8"
                            }

                            MouseArea {
                                id: checkTrayMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: { if (plasmoidItem) plasmoidItem.updateTray(); }
                            }
                        }
                    }
                }
            }

            // Clean CLI Shortcut text
            Text {
                Layout.fillWidth: true
                text: "CLI shortcut: omniroute-tray --update-tray"
                font.pixelSize: 10
                font.family: "monospace"
                color: "#52525b"
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.preferredHeight: 4 }
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

            // Port badge (with tooltip)
            Rectangle {
                id: portRect
                height: 22
                width: 115
                radius: 5
                color: portMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06)
                border.color: portMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.10)
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
                    id: portMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Qt.openUrlExternally("http://127.0.0.1:20128")
                }
                QQC2.ToolTip.visible: portMouseArea.containsMouse
                QQC2.ToolTip.text: "Open OmniRoute Dashboard"
            }

            Item { Layout.fillWidth: true }

            // Reload button (wrapped for hover)
            Rectangle {
                width: 26
                height: 26
                radius: 5
                color: refreshMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "⟳"
                    font.pixelSize: 16
                    color: "#a1a1aa"
                }
                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (plasmoidItem) {
                            plasmoidItem.refreshAll();
                        }
                    }
                }
                QQC2.ToolTip.visible: refreshMouseArea.containsMouse
                QQC2.ToolTip.text: "Refresh Dashboard"
            }

            // GitHub button (wrapped for hover)
            Rectangle {
                width: 26
                height: 26
                radius: 5
                color: githubArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : "transparent"
                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='%23a1a1aa'><path d='M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z'/></svg>"
                }
                MouseArea {
                    id: githubArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Qt.openUrlExternally("https://github.com/diegosouzapw/OmniRoute")
                }
                QQC2.ToolTip.visible: githubArea.containsMouse
                QQC2.ToolTip.text: "View on GitHub"
            }
        }
    }
}
