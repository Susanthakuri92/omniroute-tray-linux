import QtQuick
import QtQuick.Controls as QQC2
import "utils.js" as Utils

Item {
    id: chartRoot
    property var points: [] // [{date: "2026-09-01", cost: 1.23, tokens: 1000}, ...]
    implicitHeight: 46
    implicitWidth: 300

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var pts = chartRoot.points || [];
            if (!pts.length) {
                // Draw subtle placeholder line
                ctx.strokeStyle = "#27272a";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, height - 4);
                ctx.lineTo(width, height - 4);
                ctx.stroke();
                return;
            }

            var maxCost = 0.01;
            for (var i = 0; i < pts.length; i++) {
                if (pts[i].cost > maxCost) maxCost = pts[i].cost;
            }

            var n = pts.length;
            var gap = 2;
            var barW = Math.max(2, (width - (n - 1) * gap) / n);
            var maxBarH = height - 6;

            for (var j = 0; j < n; j++) {
                var c = pts[j].cost || 0;
                var h = (c / maxCost) * maxBarH;
                if (c > 0 && h < 2) h = 2;
                var x = j * (barW + gap);
                var y = height - h - 2;

                ctx.fillStyle = "#e05243";
                ctx.fillRect(x, y, barW, h);
            }

            // Baseline
            ctx.strokeStyle = "#27272a";
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, height - 1);
            ctx.lineTo(width, height - 1);
            ctx.stroke();
        }

        Connections {
            target: chartRoot
            function onPointsChanged() { canvas.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
