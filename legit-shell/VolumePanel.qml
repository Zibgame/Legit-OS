import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// LEGIT Shell audio panel (Noctalia-style): real PipeWire/WirePlumber state
// via the Quickshell Pipewire service. Slider writes directly to the default
// sink; the icon and value react to every change (no polling, no fake data).
PanelWindow {
    id: panel

    property var state

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "legit-vol-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Keys.onEscapePressed: panel.state.closePopups()

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool muted: sinkAudio ? Boolean(sinkAudio.muted) : false
    readonly property real level: sinkAudio ? sinkAudio.volume : 0

    MouseArea {
        anchors.fill: parent
        onClicked: panel.state.closePopups()
    }

    Rectangle {
        width: 360
        height: 190
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 8
            bottomMargin: 52
        }
        color: "#b31a1d24"
        radius: 12
        border.color: "#18ffffff"
        border.width: 1

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: "Audio"
                color: panel.textColor
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                width: parent.width
                text: panel.sink ? ("Sortie : " + (panel.sink.description || panel.sink.name || "inconnue"))
                                 : "Aucune sortie audio détectée."
                color: panel.subtext
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Slider {
                id: volSlider
                width: parent.width
                from: 0
                to: 1
                value: panel.level
                enabled: panel.sinkAudio !== null

                onMoved: if (panel.sinkAudio) panel.sinkAudio.volume = value;
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: panel.muted ? "Muet" : Math.round(panel.level * 100) + " %"
                    color: panel.muted ? "#e57373" : panel.textColor
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Rectangle {
                    width: 92
                    height: 26
                    radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: panel.muted ? "#66e57373" : "#264bb3e4"

                    Text {
                        anchors.centerIn: parent
                        text: panel.muted ? "Rétablir le son" : "Couper le son"
                        color: panel.textColor
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (panel.sinkAudio) panel.sinkAudio.muted = !panel.sinkAudio.muted;
                    }
                }
            }
        }
    }
}
