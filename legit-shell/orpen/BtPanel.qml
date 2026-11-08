

import Quickshell.Io
import QtQuick

Item {
    id: root
    signal backRequested()
    required property var pill

    property var  pairedDevices:  []
    property bool scanning:       false
    property bool initialLoadDone: false
    property bool btEnabled:      true   

    

    function parsePaired(text) {
        var lines = text.trim().split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var parts = line.split(" ")
            if (parts.length < 3 || parts[0] !== "Device") continue
            result.push({ address: parts[1], name: parts.slice(2).join(" "), connected: false })
        }
        root.pairedDevices = result
        btConnectedCheck.running = true
    }

    function parseConnected(text) {
        var connected = []
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var parts = line.split(" ")
            if (parts.length >= 2 && parts[0] === "Device") connected.push(parts[1])
        }
        var updated = []
        for (var j = 0; j < root.pairedDevices.length; j++) {
            var d = root.pairedDevices[j]
            updated.push({ address: d.address, name: d.name, connected: connected.indexOf(d.address) !== -1 })
        }
        updated.sort(function(a, b) {
            if (a.connected && !b.connected) return -1
            if (!a.connected && b.connected) return 1
            return 0
        })
        root.pairedDevices = updated
        root.initialLoadDone = true
    }

    

    Process {
        id: btPairedGet
        running: false
        command: ["bash", "-c", "bluetoothctl devices 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parsePaired(text) }
    }

    Process {
        id: btConnectedCheck
        running: false
        command: ["bash", "-c", "bluetoothctl devices Connected 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parseConnected(text) }
    }

    Process {
        id: btScan
        running: false
        command: ["bash", "-c",
            "bluetoothctl scan on & BGPID=$!; sleep 8; bluetoothctl scan off; " +
            "wait $BGPID 2>/dev/null; bluetoothctl devices 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                root.parsePaired(text)
            }
        }
    }

    Process {
        id: btDeviceAction
        running: false
        property string pendingAddress: ""
        property bool   pendingConnect: true

        function act(address, connect) {
            pendingAddress = address
            pendingConnect = connect
            command = ["bluetoothctl", connect ? "connect" : "disconnect", address]
            running = true
        }

        onRunningChanged: {
            if (!running) btConnectedCheck.running = true
        }
    }

    
    Process {
        id: btPower
        running: false
        property bool turningOn: true

        function toggle(on) {
            turningOn = on
            command = ["bash", "-c", "bluetoothctl power " + (on ? "on" : "off") + " 2>/dev/null"]
            running = true
        }

        onRunningChanged: {
            if (!running) {
                root.btEnabled = turningOn
                if (turningOn) {
                    root.pairedDevices = []
                    root.initialLoadDone = false
                    btPairedGet.running = true
                } else {
                    
                    root.pairedDevices = []
                }
            }
        }
    }

    

    Component.onCompleted: {
        
        btPowerCheck.running = true
    }

    Process {
        id: btPowerCheck
        running: false
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.btEnabled = text.trim() === "yes"
                if (root.btEnabled) btPairedGet.running = true
            }
        }
    }

    Timer {
        interval: 5000
        running: root.initialLoadDone && root.btEnabled
        repeat: true
        onTriggered: btConnectedCheck.running = true
    }

    
    Item {
        id: btHeader
        anchors.top: parent.top
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 4
        height: 28

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 14; color: pill.t_card
                Text {
                    anchors.centerIn: parent; text: "←"
                    color: pill.t_text; font.pointSize: 12
                    font.family: "JetBrainsMono Nerd Font Mono"
                }
                MouseArea { anchors.fill: parent; onClicked: root.backRequested() }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: pill.t_text; font.pointSize: 11; font.bold: true
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }

        
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            
            Rectangle {
                width: 44; height: 26; radius: 13
                color: root.btEnabled ? pill.t_bg : pill.t_cardHover
                Behavior on color { ColorAnimation { duration: 200 } }
                border.width: 1
                border.color: root.btEnabled ? pill.t_accent : pill.t_border
                Behavior on border.color { ColorAnimation { duration: 200 } }

                
                Rectangle {
                    x: root.btEnabled ? 22 : 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: root.btEnabled ? pill.t_accent : pill.t_textSub
                    Behavior on x     { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation  { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !btPower.running
                    onClicked: btPower.toggle(!root.btEnabled)
                }
            }

            
            Rectangle {
                width: 66; height: 26; radius: 13
                visible: root.btEnabled
                color: root.scanning ? pill.t_bg : pill.t_card
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: root.scanning ? "Scanning…" : "󰑐 Scan"
                    color: root.scanning ? pill.t_textSub : pill.t_accent
                    font.pointSize: 7; font.bold: true
                    font.family: "JetBrainsMono Nerd Font Mono"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.scanning
                    onClicked: {
                        root.scanning = true
                        btScan.running = true
                    }
                }
            }
        }
    }

    
    Item {
        anchors.top: btHeader.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        visible: !root.btEnabled

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰂲"
                color: pill.t_textSub; font.pointSize: 28
                font.family: "JetBrainsMono Nerd Font Mono"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bluetooth is off"
                color: pill.t_textSub; font.pointSize: 9
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }
    }

    
    Item {
        anchors.top: btHeader.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        clip: true
        visible: root.btEnabled

        Text {
            anchors.centerIn: parent
            text: "No paired devices"
            color: pill.t_textSub; font.pointSize: 9
            font.family: "JetBrainsMono Nerd Font Mono"
            visible: root.pairedDevices.length === 0
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: root.pairedDevices

                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 40; radius: 10
                    color: modelData.connected ? pill.t_bg : pill.t_card
                    Behavior on color { ColorAnimation { duration: 150 } }
                    border.width: 1
                    border.color: modelData.connected ? pill.t_accent : pill.t_cardHover
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰂯"
                            color: modelData.connected ? pill.t_accent : pill.t_textSub
                            font.pointSize: 13
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 80

                            Text {
                                text: modelData.name
                                color: modelData.connected ? pill.t_text : pill.t_textSub
                                font.pointSize: 9; font.bold: modelData.connected
                                font.family: "JetBrainsMono Nerd Font Mono"
                                elide: Text.ElideRight; width: parent.width
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                text: modelData.connected ? "Connected" : modelData.address
                                color: modelData.connected ? pill.t_accent : pill.t_textSub
                                font.pointSize: 7
                                font.family: "JetBrainsMono Nerd Font Mono"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 58; height: 24; radius: 12
                            color: modelData.connected ? pill.t_border : pill.t_card
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : "Connect"
                                color: modelData.connected ? "#ff6b6b" : pill.t_accent
                                font.pointSize: 6; font.bold: true
                                font.family: "JetBrainsMono Nerd Font Mono"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: btDeviceAction.act(modelData.address, !modelData.connected)
                            }
                        }
                    }
                }
            }
        }
    }
}


