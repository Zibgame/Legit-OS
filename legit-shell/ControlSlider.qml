import QtQuick

// Interaction model adapted from DankMaterialShell CcSliderRow (MIT): the
// service owns the value and dragging emits normalized changes without
// replacing the service binding.
Item {
    id: root
    property real value: 0
    property bool available: true
    property color accent: "#49d9ff"
    property color trackColor: "#405466"
    signal moved(real value)
    implicitHeight: 26

    Rectangle {
        id: track
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        height: 6; radius: 3; color: root.trackColor; opacity: root.available ? 1 : 0.35
        Rectangle { width: Math.max(0, Math.min(parent.width, parent.width * root.value)); height: parent.height; radius: parent.radius; color: root.accent; Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } } }
        Rectangle {
            x: Math.max(-width / 2, Math.min(track.width - width / 2, track.width * root.value - width / 2))
            anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: "#f7fbff"; border.color: "#80a8bed0"; opacity: root.available ? 1 : 0.45
            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent; enabled: root.available; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        function updateValue(mouse) { root.moved(Math.max(0, Math.min(1, mouse.x / width))); }
        onPressed: mouse => updateValue(mouse)
        onPositionChanged: mouse => { if (pressed) updateValue(mouse); }
    }
}
