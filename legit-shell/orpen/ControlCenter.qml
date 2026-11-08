

import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    // Exposed only so the LEGIT taskbar can open the original upstream
    // WifiPanel/BtPanel directly without duplicating either component.
    property alias currentView: toggleGrid.currentView

    
    required property var pill
    signal closeRequested()
    signal volumeChanged(real value)
    signal brightnessChanged(real value)
    signal wifiToggleRequested(bool turningOn)
    signal btToggleRequested(bool turningOn)

    
    property string powerProfile: "balanced"

    Process {
        id: powerProfileGet
        command: ["bash", "-c", "powerprofilesctl get"]
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = text.trim()
        }
    }

    Process {
        id: powerProfileSet
        property string target: "balanced"
        command: ["bash", "-c", "powerprofilesctl set " + target]
        onRunningChanged: if (!running) powerProfileGet.running = true
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: powerProfileGet.running = true
    }

    
    
Item {
    id: ccHeader
    anchors.top: parent.top
    anchors.left: parent.left; anchors.right: parent.right
    anchors.topMargin: 16; anchors.leftMargin: 16; anchors.rightMargin: 16
    height: 28


    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 28; height: 28; radius: 14
            color: root.pill.t_card
            Text { anchors.centerIn: parent; text: "←"; color: root.pill.t_text; font.pointSize: 12; font.family: "JetBrainsMono Nerd Font Mono" }
            MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Control Center"
            color: root.pill.t_text; font.pointSize: 13; font.bold: true
            font.family: "JetBrainsMono Nerd Font Mono"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        
        Rectangle {
            width: 28; height: 28; radius: 14
            color: root.pill.dnd ? root.pill.t_accent : root.pill.t_card
            Behavior on color { ColorAnimation { duration: 180 } }
            Text {
                anchors.centerIn: parent
                text: "󰂛"
                color: root.pill.dnd ? root.pill.t_bg : root.pill.t_textSub
                font.pointSize: 11
                font.family: "JetBrainsMono Nerd Font Mono"
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pill.dnd = !root.pill.dnd
            }
        }

        
        Rectangle {
            width: 28; height: 28; radius: 14
            color: root.pill.isLightMode ? "#ffcc00" : root.pill.t_card
            Behavior on color { ColorAnimation { duration: 180 } }
            Text {
                anchors.centerIn: parent
                text: root.pill.isLightMode ? "󰖨" : "󰖔" 
                color: root.pill.isLightMode ? root.pill.t_bg : root.pill.t_textSub
                font.pointSize: 11
                font.family: "JetBrainsMono Nerd Font Mono"
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.pill.isLightMode = !root.pill.isLightMode
                    
                }
            }
        }

        Repeater {
            model: ["power-saver", "balanced", "performance"]
            delegate: Rectangle {
                required property string modelData
                width: modelData === "balanced" ? 76 : 60
                height: 26; radius: 13
                color: root.powerProfile === modelData ? root.pill.t_accent : root.pill.t_cardHover
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData === "power-saver"  ? "󰌪 Saver" :
                          modelData === "balanced"      ? "󰛲 Balanced" :
                                                         "󱐌 Perf"
                    color: root.powerProfile === modelData ? root.pill.t_bg : root.pill.t_textSub
                    font.pointSize: 7
                    font.bold: root.powerProfile === modelData
                    font.family: "JetBrainsMono Nerd Font Mono"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        powerProfileSet.target  = modelData
                        powerProfileSet.running = true
                    }
                }
            }
        }
    }
}

    
    ToggleGrid {
        id: toggleGrid
        anchors.top: ccHeader.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 14; anchors.leftMargin: 16; anchors.rightMargin: 16

        pill: root.pill
        onWifiToggleRequested: (on) => root.wifiToggleRequested(on)
        onBtToggleRequested:   (on) => root.btToggleRequested(on)
        onDndToggleRequested:  (on) => root.pill.dnd = on
        onVisibleChanged: if (!visible) currentView = 0

    }

    
    SliderRow {
        id: volumeRow
        anchors.top: toggleGrid.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 10; anchors.leftMargin: 16; anchors.rightMargin: 16

        pill:  root.pill
        icon:  "󰕾"
        value: root.pill.volumeLevel
        onSliderMoved: (v) => root.volumeChanged(v)
    }

    
    SliderRow {
        id: brightnessRow
        anchors.top: volumeRow.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 8; anchors.leftMargin: 16; anchors.rightMargin: 16

        pill:  root.pill
        icon:  "󰃟"
        value: root.pill.brightnessLevel
        onSliderMoved: (v) => root.brightnessChanged(v)
    }

    
    MediaCard {
        id: mediaCard
        anchors.top: brightnessRow.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 8; anchors.leftMargin: 16; anchors.rightMargin: 16

        pill: root.pill
        activePlayer: root.pill.activePlayer
    }
}

