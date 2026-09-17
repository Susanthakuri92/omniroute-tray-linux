import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

Item {
    id: compactRoot

    property var plasmoidItem: null

    readonly property bool isRunning: (plasmoidItem && plasmoidItem.isRunning) || (typeof root !== 'undefined' && root.isRunning)
    readonly property int activeProviders: (plasmoidItem && plasmoidItem.healthActiveProviders) || (typeof root !== 'undefined' && root.healthActiveProviders) || 0
    readonly property real todaySpend: (plasmoidItem && plasmoidItem.todaySpend) || (typeof root !== 'undefined' && root.todaySpend) || 0.0

    Layout.minimumWidth: plasmoid.formFactor === PlasmaCore.Types.Vertical ? 0 : height
    Layout.minimumHeight: plasmoid.formFactor === PlasmaCore.Types.Vertical ? width : 0
    Layout.preferredWidth: plasmoid.formFactor === PlasmaCore.Types.Vertical ? -1 : height
    Layout.preferredHeight: plasmoid.formFactor === PlasmaCore.Types.Vertical ? width : -1

    Canvas {
        id: iconCanvas
        anchors.fill: parent
        anchors.margins: Math.round(Math.min(parent.width, parent.height) * 0.12)
        renderTarget: Canvas.FramebufferObject
        antialiasing: true
        smooth: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var w = width;
            var h = height;
            var cx = w / 2;
            var cy = h / 2;
            var sz = Math.min(w, h);
            var spokeRadius = sz * 0.38;
            var hubRadius = Math.max(2, sz * 0.11);
            var nodeRadius = Math.max(1.8, sz * 0.08);
            var lineWidth = Math.max(1.2, sz * 0.05);

            var angles = [0, 60, 120, 180, 240, 300];

            // 1. Draw connecting spokes in crisp white
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = lineWidth;
            ctx.lineCap = "round";

            for (var i = 0; i < angles.length; i++) {
                var rad = angles[i] * Math.PI / 180;
                var nx = cx + spokeRadius * Math.cos(rad);
                var ny = cy + spokeRadius * Math.sin(rad);

                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(nx, ny);
                ctx.stroke();
            }

            // 2. Draw central hub in crisp white
            ctx.fillStyle = "#ffffff";
            ctx.beginPath();
            ctx.arc(cx, cy, hubRadius, 0, 2 * Math.PI);
            ctx.fill();

            // 3. Draw 6 satellite points:
            // Crimson red (#ff2b4d) when server is running, white (#ffffff) when stopped
            var nodeColor = compactRoot.isRunning ? "#ff2b4d" : "#ffffff";
            ctx.fillStyle = nodeColor;

            for (var j = 0; j < angles.length; j++) {
                var rad2 = angles[j] * Math.PI / 180;
                var px = cx + spokeRadius * Math.cos(rad2);
                var py = cy + spokeRadius * Math.sin(rad2);

                ctx.beginPath();
                ctx.arc(px, py, nodeRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        Connections {
            target: compactRoot
            function onIsRunningChanged() { iconCanvas.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        property bool wasExpanded: false

        onPressed: mouse => {
            if (compactRoot.plasmoidItem) {
                wasExpanded = compactRoot.plasmoidItem.expanded;
            } else if (typeof root !== 'undefined') {
                wasExpanded = root.expanded;
            }
        }

        onClicked: mouse => {
            if (compactRoot.plasmoidItem) {
                compactRoot.plasmoidItem.expanded = !wasExpanded;
            } else if (typeof root !== 'undefined') {
                root.expanded = !wasExpanded;
            }
        }
    }
}
