import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io

// LEGIT Shell bluetooth panel (Noctalia-style): real BlueZ state via
// Quickshell.Bluetooth. When no adapter exists (typical in VirtualBox) the
// panel says so clearly instead of showing fake data.
PanelWindow {
    id: panel

    property var state

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "legit-bt-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Keys.onEscapePressed: panel.state.closePopups()

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"

    readonly property var adapter: Bluetooth.defaultAdapter || null
    readonly property bool adapterReady: adapter !== null
    readonly property bool btEnabled: adapterReady ? Boolean(adapter.enabled) : false

    // Click outside the card closes the panel.
    MouseArea {
        anchors.fill: parent
        onClicked: panel.state.closePopups()
    }

    Rectangle {
        width: 360
        height: btContent.implicitHeight + 28
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

        MouseArea { anchors.fill: parent } // keep card clicks (no close)

        Column {
            id: btContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "Bluetooth"
                    color: panel.textColor
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 } // spacer

                Rectangle {
                    width: 84
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: panel.adapterReady && panel.btEnabled ? "#264bb3e4" : "#66262a31"

                    Text {
                        anchors.centerIn: parent
                        text: !panel.adapterReady ? "Indisponible"
                                : (panel.btEnabled ? "Activé" : "Désactivé")
                        color: panel.adapterReady && panel.btEnabled ? "#9fd6f5" : panel.subtext
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: panel.adapterReady
                        cursorShape: panel.adapterReady ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.adapter.enabled = !panel.adapter.enabled
                    }
                }
            }

            Text {
                width: parent.width
                text: !panel.adapterReady
                        ? "Aucun adaptateur Bluetooth détecté (indisponible sur cette machine)."
                        : (panel.btEnabled ? "Appareils appairés à proximité :" : "Activez le Bluetooth pour voir les appareils.")
                color: panel.subtext
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // Device list (real BlueZ devices when an adapter exists).
            Repeater {
                model: panel.adapterReady && panel.btEnabled ? panel.adapter.devices.values : []

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 44
                    radius: 8
                    color: devMa.containsMouse ? "#44222730" : "#66262a31"

                    MouseArea {
                        id: devMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (modelData && modelData.connect) modelData.connect()
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            width: 200
                            text: modelData ? (modelData.name || modelData.deviceName || "Appareil inconnu") : ""
                            color: panel.textColor
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData && modelData.state === BluetoothDeviceState.Connected ? "Connecté" : "Non connecté"
                            color: modelData && modelData.state === BluetoothDeviceState.Connected ? panel.accent : panel.subtext
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
