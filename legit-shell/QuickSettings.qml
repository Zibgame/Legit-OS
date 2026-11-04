import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Hyprland

// LEGIT Shell quick settings panel (volume, network, session controls).
PanelWindow {
    id: panel

    property var state

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: 44
        right: 4
    }

    exclusiveZone: -1

    implicitWidth: 320
    implicitHeight: 360
    color: "transparent"

    // Keyboard focus on demand so Escape closes the panel (no grab).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"

    // Network state via NetworkManager (real values, refreshed every 3s)
    property string netState: "?"
    property string netConns: ""
    property string volText: "-"

    Process {
        id: netProbe
        command: ["sh", "-c", "echo NETSTATE=$(nmcli -t -f STATE general 2>/dev/null); echo CONNS=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -c ':connected')"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.startsWith("NETSTATE=")) panel.netState = line.slice(9);
                else if (line.startsWith("CONNS=")) panel.netConns = line.slice(6);
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            netProbe.running = false;
            netProbe.running = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#dd1d1d1f"
        radius: 8
        border.color: "#18ffffff"
        border.width: 1

        // Escape closes the panel.
        focus: true
        Keys.onEscapePressed: panel.state.closePopups()

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: "Paramètres rapides"
                color: panel.textColor
                font.pixelSize: 13
                font.bold: true
            }

            // ---- Volume ----
            Rectangle {
                width: parent.width
                height: 74
                radius: 4
                color: "#262626"
                visible: Pipewire.defaultAudioSink !== null

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Row {
                        spacing: 8

                        Text {
                            text: "🔊"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: panel.volText
                            color: panel.textColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 54
                            height: 22
                            radius: 3
                            color: muteMa.containsMouse ? "#3a3a3a" : "#333333"
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                id: muteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: panel.state.luaDispatch('hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")')
                            }

                            Text {
                                anchors.centerIn: parent
                                text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "Rétablir" : "Couper"
                                color: panel.textColor
                                font.pixelSize: 10
                            }
                        }
                    }

                    Slider {
                        id: volSlider
                        width: parent.width
                        from: 0
                        to: 1
                        value: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0

                        onMoved: {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                Pipewire.defaultAudioSink.audio.volume = value;
                            }
                        }
                    }
                }
            }

            // ---- Network ----
            Rectangle {
                width: parent.width
                height: 52
                radius: 4
                color: "#262626"

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: panel.netState === "fully" ? "🌐" : "📴"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Réseau"
                            color: panel.textColor
                            font.pixelSize: 12
                        }
                        Text {
                            text: panel.netState === "fully" ? (panel.netConns + " interface(s) connectée(s)") : "déconnecté"
                            color: panel.subtext
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ---- Battery ----
            Rectangle {
                width: parent.width
                height: 40
                radius: 4
                color: "#262626"
                visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "🔋"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
                        color: panel.textColor
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ---- Session controls ----
            Row {
                spacing: 8

                Repeater {
                    model: [
                        { label: "🔒 Verrouiller", cmd: "swaylock -f" },
                        { label: "⟳ Redémarrer", cmd: "systemctl reboot" },
                        { label: "⏻ Éteindre", cmd: "systemctl poweroff" }
                    ]

                    Rectangle {
                        id: sessBtn
                        required property var modelData
                        width: 92
                        height: 34
                        radius: 4
                        color: sessMa.containsMouse ? "#3a3a3a" : "#262626"

                        MouseArea {
                            id: sessMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Hyprland.dispatch('hl.dsp.exec_cmd("' + modelData.cmd + '")');
                                panel.state.closePopups();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: sessBtn.modelData.label
                            color: panel.textColor
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // ---- Version ----
            Text {
                text: "LEGIT Shell — LEGIT OS live"
                color: panel.subtext
                font.pixelSize: 9
            }
        }
    }

    // Keep volume label fresh
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                panel.volText = Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%";
            }
        }
    }
}