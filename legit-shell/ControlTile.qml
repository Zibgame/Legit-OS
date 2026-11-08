import QtQuick

// Compact LEGIT styling around DankMaterialShell's CcTile interaction model
// (MIT): active/available state, keyboard-sized hit target and state layer.
Rectangle {
    id: root
    property string icon: "settings"
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool showChevron: false
    signal clicked()
    implicitHeight: 88; radius: 16
    color: active ? "#b5227896" : "#a3182a38"
    border.color: active ? "#49d9ff" : "#42617484"; border.width: active ? 1.4 : 1
    opacity: available ? 1 : 0.48
    Behavior on color { ColorAnimation { duration: 170; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 170; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    MouseArea {
        id: ma; anchors.fill: parent; enabled: root.available; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: root.scale = 0.975; onReleased: root.scale = 1; onCanceled: root.scale = 1; onClicked: root.clicked()
    }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: ma.containsMouse ? "#12ffffff" : "transparent"; Behavior on color { ColorAnimation { duration: 140 } } }
    SystemGlyph {
        anchors { left: parent.left; top: parent.top; leftMargin: 16; topMargin: 13 }
        width: 25; height: 25; name: root.icon
        glyphColor: root.active ? "#62e3ff" : "#f3f8fb"
    }
    SystemGlyph {
        visible: root.showChevron
        anchors { right: parent.right; top: parent.top; rightMargin: 11; topMargin: 15 }
        width: 16; height: 16; name: "chevron"; glyphColor: "#d7e6ee"
    }
    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 10; bottomMargin: 12 }
        spacing: 2
        Text { text: root.title; color: "#f5f9fc"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
        Text { text: root.subtitle; color: root.active ? "#aeeeff" : "#9eb2bf"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
    }
}
