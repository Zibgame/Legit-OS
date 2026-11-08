import QtQuick

// Theme-independent vector glyphs for the system area. Drawing icons locally
// avoids icon-theme fallbacks (the purple squares seen with the Win11 theme).
Item {
    id: root
    property string name: "settings"
    property color glyphColor: "#f4f8fb"
    property real level: 1.0
    implicitWidth: 20
    implicitHeight: 20
    onNameChanged: canvas.requestPaint()
    onGlyphColorChanged: canvas.requestPaint()
    onLevelChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function line(ctx, x1, y1, x2, y2) {
            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
        }
        function circle(ctx, x, y, r, fill) {
            ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2);
            if (fill) ctx.fill(); else ctx.stroke();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset(); ctx.scale(width / 24, height / 24);
            ctx.strokeStyle = root.glyphColor; ctx.fillStyle = root.glyphColor;
            ctx.lineWidth = 1.9; ctx.lineCap = "round"; ctx.lineJoin = "round";

            if (root.name === "wifi") {
                ctx.beginPath(); ctx.arc(12, 14.5, 8.4, Math.PI * 1.20, Math.PI * 1.80); ctx.stroke();
                ctx.beginPath(); ctx.arc(12, 15.5, 5.4, Math.PI * 1.20, Math.PI * 1.80); ctx.stroke();
                ctx.beginPath(); ctx.arc(12, 16.7, 2.4, Math.PI * 1.20, Math.PI * 1.80); ctx.stroke();
                circle(ctx, 12, 19.1, 1.15, true);
            } else if (root.name === "ethernet") {
                ctx.strokeRect(5, 5, 14, 10); line(ctx, 8, 15, 8, 19); line(ctx, 16, 15, 16, 19); line(ctx, 8, 19, 16, 19); line(ctx, 9, 9, 15, 9);
            } else if (root.name === "network-off") {
                ctx.beginPath(); ctx.arc(12, 14.5, 8.4, Math.PI * 1.20, Math.PI * 1.80); ctx.stroke();
                ctx.beginPath(); ctx.arc(12, 15.5, 4.8, Math.PI * 1.20, Math.PI * 1.80); ctx.stroke(); line(ctx, 5, 5, 19, 19);
            } else if (root.name === "bluetooth") {
                line(ctx, 12, 3, 12, 21); line(ctx, 12, 3, 17, 8); line(ctx, 17, 8, 7, 16); line(ctx, 7, 8, 17, 16); line(ctx, 17, 16, 12, 21);
            } else if (root.name === "volume" || root.name === "mute") {
                ctx.beginPath(); ctx.moveTo(4, 10); ctx.lineTo(8, 10); ctx.lineTo(13, 6); ctx.lineTo(13, 18); ctx.lineTo(8, 14); ctx.lineTo(4, 14); ctx.closePath(); ctx.stroke();
                if (root.name === "mute" || root.level <= 0.001) { line(ctx, 16, 9, 21, 15); line(ctx, 21, 9, 16, 15); }
                else { ctx.beginPath(); ctx.arc(13, 12, 4.7, -0.78, 0.78); ctx.stroke(); if (root.level > 0.55) { ctx.beginPath(); ctx.arc(13, 12, 7.7, -0.72, 0.72); ctx.stroke(); } }
            } else if (root.name === "battery") {
                ctx.beginPath(); ctx.roundedRect(3.5, 7, 16.5, 10, 2.2, 2.2); ctx.stroke(); ctx.fillRect(20.7, 10, 1.8, 4);
                var fillW = Math.max(1.7, 13.5 * Math.max(0, Math.min(1, root.level)));
                ctx.beginPath(); ctx.roundedRect(5.1, 8.7, fillW, 6.6, 1.2, 1.2); ctx.fill();
            } else if (root.name === "settings") {
                line(ctx, 4, 6, 20, 6); line(ctx, 4, 12, 20, 12); line(ctx, 4, 18, 20, 18);
                circle(ctx, 9, 6, 2.1, false); circle(ctx, 16, 12, 2.1, false); circle(ctx, 8, 18, 2.1, false);
            } else if (root.name === "brightness") {
                circle(ctx, 12, 12, 4.1, false);
                for (var i = 0; i < 8; ++i) { var a = i * Math.PI / 4; line(ctx, 12 + Math.cos(a) * 6.8, 12 + Math.sin(a) * 6.8, 12 + Math.cos(a) * 9.2, 12 + Math.sin(a) * 9.2); }
            } else if (root.name === "moon") {
                ctx.beginPath(); ctx.arc(13, 11, 7.5, 0.35, Math.PI * 1.65); ctx.quadraticCurveTo(8, 12, 16.8, 4.7); ctx.stroke();
            } else if (root.name === "leaf") {
                ctx.beginPath(); ctx.moveTo(5, 17); ctx.quadraticCurveTo(5, 6, 19, 5); ctx.quadraticCurveTo(19, 17, 8, 18); ctx.stroke(); line(ctx, 6, 19, 16, 9);
            } else if (root.name === "lock") {
                ctx.beginPath(); ctx.roundedRect(5, 10, 14, 11, 2, 2); ctx.stroke(); ctx.beginPath(); ctx.arc(12, 10, 4.5, Math.PI, 0); ctx.stroke(); circle(ctx, 12, 15, 1.2, true);
            } else if (root.name === "restart") {
                ctx.beginPath(); ctx.arc(12, 12, 7.3, -0.45, Math.PI * 1.55); ctx.stroke(); line(ctx, 18.6, 4.3, 18.8, 9.2); line(ctx, 18.8, 4.3, 14.2, 4.8);
            } else if (root.name === "power") {
                ctx.beginPath(); ctx.arc(12, 13, 7.5, -0.78, Math.PI * 1.78); ctx.stroke(); line(ctx, 12, 3, 12, 12);
            } else if (root.name === "chevron") {
                line(ctx, 9, 6, 15, 12); line(ctx, 15, 12, 9, 18);
            }
        }
    }
}
