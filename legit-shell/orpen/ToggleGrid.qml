


import Quickshell.Io
import QtQuick

Item {
    id: root
    height: currentView === 0 ? 200 : 300
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    required property var pill
    signal wifiToggleRequested(bool turningOn)
    signal btToggleRequested(bool turningOn)
    signal dndToggleRequested(bool turningOn)

    
    property int currentView: 0

    readonly property int tileWidth: (width - 20) / 3

    clip: true

    
    Item {
        id: gridView
        anchors.left: parent.left; anchors.right: parent.right
        height: 200
        opacity: root.currentView === 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        transform: Translate {
            x: root.currentView === 0 ? 0 : -30
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Grid {
            anchors.fill: parent
            columns: 3
            spacing: 10

            
            Rectangle {
                width: root.tileWidth; height: 60; radius: 16
                color: pill.wifiEnabled ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: pill.wifiEnabled ? pill.t_bg : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text {
                            anchors.centerIn: parent
                            text: pill.wifiSignal > 70 ? "󰤨" :
                                  pill.wifiSignal > 40 ? "󰤥" :
                                  pill.wifiSignal > 10 ? "󰤢" :
                                  pill.wifiEnabled     ? "󰤯" : "󰤭"
                            color: pill.t_accent; font.pointSize: 12
                            font.family: "JetBrainsMono Nerd Font Mono"
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Wi-Fi"
                            color: pill.wifiEnabled ? pill.t_bg : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            text: pill.wifiSsid
                            color: pill.wifiEnabled ? pill.t_bg : pill.t_textSub
                            font.pointSize: 7; elide: Text.ElideRight; width: 80
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentView = 1
                    onPressAndHold: root.wifiToggleRequested(!pill.wifiEnabled)
                }
            }

            
            Rectangle {
                width: root.tileWidth; height: 60; radius: 16
                color: pill.volumeLevel > 0 ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: pill.volumeLevel > 0 ? pill.t_bg : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text { anchors.centerIn: parent; text: "󰕾"; color: pill.t_accent; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Audio"
                            color: pill.volumeLevel > 0 ? pill.t_bg : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            text: Math.round(pill.volumeLevel * 100) + "%"
                            color: pill.volumeLevel > 0 ? pill.t_bg : pill.t_textSub
                            font.pointSize: 7
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

            
            Rectangle {
                width: root.tileWidth; height: 60; radius: 16
                color: pill.btPowered ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: pill.btPowered ? pill.t_bg : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text { anchors.centerIn: parent; text: "󰂯"; color: pill.t_accent; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Bluetooth"
                            color: pill.btPowered ? pill.t_bg : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            text: pill.btDevice !== "" ? pill.btDevice :
                                  pill.btPowered       ? "On" : "Off"
                            color: pill.btPowered ? pill.t_bg : pill.t_textSub
                            font.pointSize: 7; elide: Text.ElideRight; width: 80
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentView = 2
                    onPressAndHold: root.btToggleRequested(!pill.btPowered)
                }
            }

            
            Rectangle {
                width: root.tileWidth; height: 60; radius: 16
                color: pill.t_card

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14; color: pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "󰍹"; color: pill.t_accent; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: "Display"; color: pill.t_text; font.pointSize: 9; font.bold: true; font.family: "JetBrainsMono Nerd Font Mono" }
                        Text { text: "Scale 1.25x"; color: pill.t_textSub; font.pointSize: 7; font.family: "JetBrainsMono Nerd Font Mono" }
                    }
                }
            }

            
            Rectangle {
                id: peaceTile
                property bool dndOn: false
                width: root.tileWidth; height: 60; radius: 16
                color: dndOn ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        peaceTile.dndOn = !peaceTile.dndOn
                        root.dndToggleRequested(peaceTile.dndOn)
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: peaceTile.dndOn ? pill.t_bg : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text { anchors.centerIn: parent; text: "󰂛"; color: pill.t_accent; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Peace"
                            color: peaceTile.dndOn ? pill.t_bg : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            text: peaceTile.dndOn ? "On" : "Off"
                            color: peaceTile.dndOn ? pill.t_bg : pill.t_textSub
                            font.pointSize: 7
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

            
            Rectangle {
                id: nightLightTile
                property bool active: false
                width: root.tileWidth; height: 60; radius: 16
                color: active ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        nightLightTile.active = !nightLightTile.active
                        if (nightLightTile.active) nightLightOnProcess.running = true
                        else nightLightOffProcess.running = true
                    }
                }

                Process { id: nightLightOnProcess;  command: ["hyprctl", "hyprsunset", "temperature", "3500"] }
                Process { id: nightLightOffProcess; command: ["hyprctl", "hyprsunset", "temperature", "6500"] }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: nightLightTile.active ? pill.t_bg : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text { anchors.centerIn: parent; text: "󰖔"; color: pill.t_accent; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Night Light"
                            color: nightLightTile.active ? pill.t_bg : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            text: nightLightTile.active ? "On" : "Off"
                            color: nightLightTile.active ? pill.t_bg : pill.t_textSub
                            font.pointSize: 7
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

            
            Rectangle {
                id: micTile
                property bool muted: false

                width: root.tileWidth; height: 60; radius: 16
                color: micTile.muted ? "#ff4444" : pill.t_card
                Behavior on color { ColorAnimation { duration: 180 } }

                
                Component.onCompleted: micStateGet.running = true

                Process {
                    id: micStateGet
                    command: ["bash", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null"]
                    stdout: StdioCollector {
                        onStreamFinished: micTile.muted = text.trim().indexOf("yes") !== -1
                    }
                }

                Process {
                    id: micMuteToggle
                    command: ["bash", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null"]
                    onRunningChanged: if (!running) micStateGet.running = true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: micMuteToggle.running = true
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: micTile.muted ? "#1a0000" : pill.t_bg
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Text {
                            anchors.centerIn: parent
                            text: micTile.muted ? "󰍭" : "󰍬"
                            color: micTile.muted ? "#ff6666" : pill.t_accent
                            font.pointSize: 12
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text {
                            text: "Mic"
                            color: micTile.muted ? pill.t_text : pill.t_text
                            font.pointSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font Mono"
                        }
                        Text {
                            text: micTile.muted ? "Muted" : "Live"
                            color: micTile.muted ? "#ff6666" : pill.t_textSub
                            font.pointSize: 7
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

        }
    }

    
    Item {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        opacity: root.currentView === 1 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        transform: Translate {
            x: root.currentView === 1 ? 0 : 30
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        WifiPanel {
            anchors.fill: parent
            pill: root.pill
            onBackRequested: root.currentView = 0
        }
    }

    
    Item {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        opacity: root.currentView === 2 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        transform: Translate {
            x: root.currentView === 2 ? 0 : 30
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        BtPanel {
            anchors.fill: parent
            pill: root.pill
            onBackRequested: root.currentView = 0
        }
    }
}


