

import Quickshell.Io
import QtQuick
import QtQuick.Controls

Item {
    id: root
    signal backRequested()
    required property var pill

    property var    networks:        []
    property bool   scanning:        false
    property string connectingTo:    ""
    property string passwordInput:   ""
    property string selectedSsid:    ""
    property bool   showPassword:    false
    property string lastError:       ""
    property string connectedSsid:   pill.wifiSsid
    property int    connectedSignal: 0
    property bool   wifiEnabled:     true   

    property bool   showHiddenEntry: false
    property string hiddenSsid:      ""
    property string disconnectTarget: ""
    property int    dotFrame: 0

    

    Timer {
        id: focusTimer
        interval: 50; repeat: false
        onTriggered: passInput.forceActiveFocus()
    }

    Timer {
        id: hiddenFocusTimer
        interval: 50; repeat: false
        onTriggered: hiddenSsidInput.forceActiveFocus()
    }

    Timer {
        id: rescanTimer
        interval: 800; repeat: false
        onTriggered: wifiScan.running = true
    }

    Timer {
        id: watchdogTimer
        interval: 30000; repeat: false
        onTriggered: {
            if (root.connectingTo !== "") {
                root.lastError    = "Connection timed out"
                root.connectingTo = ""
                rescanTimer.restart()
            }
        }
    }

    Timer {
        id: dotTimer
        interval: 400; repeat: true
        running: root.connectingTo !== ""
        onTriggered: root.dotFrame = (root.dotFrame + 1) % 4
    }

    

    function dotAnimation() {
        var frames = ["·  ", "·· ", "···", " ··"]
        return frames[root.dotFrame]
    }

    function parseNetworks(text) {
        var lines  = text.trim().split("\n")
        var result = []
        var seen   = {}
        for (var i = 0; i < lines.length; i++) {
            var parts    = lines[i].split(":")
            if (parts.length < 4) continue
            var active   = parts[0].trim()
            var ssid     = parts[1].trim()
            var signal   = parseInt(parts[2]) || 0
            var security = parts[3].trim()
            if (!ssid || ssid === "--" || seen[ssid]) continue
            seen[ssid] = true
            if (active === "*") root.connectedSignal = signal
            result.push({ ssid: ssid, signal: signal, secured: security !== "", active: active === "*" })
        }
        result.sort(function(a, b) {
            if (a.active) return -1
            if (b.active) return 1
            return b.signal - a.signal
        })
        root.networks = result
        root.scanning = false
    }

    function shellEscape(s) {
        return s.replace(/\\/g, "\\\\")
                .replace(/"/g,  '\\"')
                .replace(/\$/g, "\\$")
                .replace(/`/g,  "\\`")
    }

    function startConnect(ssid, profile, pass, saved) {
        root.connectingTo       = ssid
        root.selectedSsid       = ""
        root.lastError          = ""
        wifiConnect.targetSsid  = ssid
        wifiConnect.profileName = profile
        wifiConnect.pass        = pass
        wifiConnect.isSaved     = saved
        if (!wifiConnect.running) wifiConnect.running = true
        watchdogTimer.restart()
    }

    // ── Processes ──

    Process {
        id: wifiScan
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parseNetworks(text) }
    }

    Process {
        id: wifiRescan
        command: ["bash", "-c",
            "nmcli dev wifi rescan 2>/dev/null; sleep 2; " +
            "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"
        ]
        stdout: StdioCollector { onStreamFinished: root.parseNetworks(text) }
    }

    Process {
        id: savedCheck
        property string ssid: ""
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE con show | grep ':802-11-wireless$' | cut -d: -f1 | " +
            "while IFS= read -r name; do " +
            "  stored=$(nmcli -g 802-11-wireless.ssid con show \"$name\" 2>/dev/null); " +
            "  [ \"$stored\" = \"" + shellEscape(ssid) + "\" ] && echo \"$name\" && break; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var profileName = text.trim()
                if (profileName !== "") {
                    root.startConnect(savedCheck.ssid, profileName, "", true)
                } else {
                    root.selectedSsid  = savedCheck.ssid
                    root.passwordInput = ""
                    passInput.text     = ""
                    focusTimer.restart()
                }
            }
        }
    }

    Process {
        id: wifiConnect
        property string targetSsid:  ""
        property string profileName: ""
        property string pass:        ""
        property bool   isSaved:     false

        command: ["bash", "-c",
            "IFACE=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | grep -v '^lo' | head -1 | cut -d: -f1); " +
            "[ -z \"$IFACE\" ] && echo '__FAIL__ no wifi interface' && exit 1; " +
            "nmcli dev disconnect \"$IFACE\" 2>/dev/null; sleep 0.8; " +
            (isSaved
                ? "nmcli con up \"" + shellEscape(profileName) + "\" ifname \"$IFACE\" 2>&1 && echo __OK__ || echo __FAIL__"
                : "nmcli dev wifi connect \"" + shellEscape(targetSsid) + "\" password \"" + shellEscape(pass) + "\" ifname \"$IFACE\" 2>&1 && echo __OK__ || echo __FAIL__"
            )
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                watchdogTimer.stop()
                if (text.indexOf("__OK__") !== -1) {
                    root.connectedSsid = wifiConnect.targetSsid
                    root.lastError     = ""
                    root.selectedSsid  = ""
                    root.passwordInput = ""
                    passInput.text     = ""
                } else {
                    if (wifiConnect.isSaved) {
                        root.lastError     = "Saved credentials failed, enter password"
                        root.selectedSsid  = wifiConnect.targetSsid
                        root.passwordInput = ""
                        passInput.text     = ""
                        focusTimer.restart()
                    } else {
                        root.lastError = "Wrong password or connection failed"
                    }
                }
                root.connectingTo = ""
                rescanTimer.restart()
            }
        }
    }

    Process {
        id: wifiDisconnect
        command: ["bash", "-c",
            "IFACE=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | grep -v '^lo' | head -1 | cut -d: -f1); " +
            "nmcli dev disconnect \"$IFACE\" 2>/dev/null && echo __OK__ || echo __FAIL__"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.disconnectTarget = ""
                if (text.indexOf("__OK__") !== -1) {
                    root.connectedSsid   = ""
                    root.connectedSignal = 0
                    root.lastError       = ""
                } else {
                    root.lastError = "Failed to disconnect"
                }
                rescanTimer.restart()
            }
        }
    }

    Process {
        id: wifiForget
        property string profileName: ""
        command: ["bash", "-c",
            "nmcli con delete \"" + shellEscape(profileName) + "\" 2>&1 && echo __OK__ || echo __FAIL__"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("__OK__") === -1) root.lastError = "Could not forget network"
                rescanTimer.restart()
            }
        }
    }

    Process {
        id: forgetCheck
        property string ssid: ""
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE con show | grep ':802-11-wireless$' | cut -d: -f1 | " +
            "while IFS= read -r name; do " +
            "  stored=$(nmcli -g 802-11-wireless.ssid con show \"$name\" 2>/dev/null); " +
            "  [ \"$stored\" = \"" + shellEscape(ssid) + "\" ] && echo \"$name\" && break; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var profile = text.trim()
                if (profile !== "") {
                    wifiForget.profileName = profile
                    wifiForget.running     = true
                } else {
                    root.lastError = "No saved profile found"
                }
            }
        }
    }

    
    Process {
        id: wifiRadio
        running: false
        property bool turningOn: true

        function toggle(on) {
            turningOn = on
            command = ["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off") + " 2>/dev/null"]
            running = true
        }

        onRunningChanged: {
            if (!running) {
                root.wifiEnabled = turningOn
                if (turningOn) {
                    root.scanning = true
                    wifiRescan.running = true
                } else {
                    root.networks      = []
                    root.connectedSsid = ""
                    root.connectedSignal = 0
                }
            }
        }
    }

    
    Process {
        id: wifiRadioCheck
        running: false
        command: ["bash", "-c", "nmcli radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled"
                if (root.wifiEnabled) {
                    root.scanning = true
                    wifiScan.running = true
                }
            }
        }
    }

    Component.onCompleted: wifiRadioCheck.running = true

    

    Item {
        id: wifiHeader
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
                text: "Wi-Fi"; color: pill.t_text
                font.pointSize: 11; font.bold: true
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            
            Rectangle {
                width: 44; height: 26; radius: 13
                color: root.wifiEnabled ? pill.t_bg : pill.t_cardHover
                Behavior on color { ColorAnimation { duration: 200 } }
                border.width: 1
                border.color: root.wifiEnabled ? pill.t_accent : pill.t_border
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Rectangle {
                    x: root.wifiEnabled ? 22 : 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: root.wifiEnabled ? pill.t_accent : pill.t_textSub
                    Behavior on x     { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation  { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !wifiRadio.running
                    onClicked: wifiRadio.toggle(!root.wifiEnabled)
                }
            }

            
            Rectangle {
                width: 28; height: 26; radius: 13
                visible: root.wifiEnabled
                color: root.showHiddenEntry ? pill.t_border : pill.t_card
                Behavior on color { ColorAnimation { duration: 150 } }
                border.width: 1
                border.color: root.showHiddenEntry ? pill.t_accent : "transparent"

                Text {
                    anchors.centerIn: parent; text: "+"
                    color: root.showHiddenEntry ? pill.t_accent : pill.t_textSub
                    font.pointSize: 12; font.bold: true
                    font.family: "JetBrainsMono Nerd Font Mono"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.showHiddenEntry = !root.showHiddenEntry
                        root.selectedSsid    = ""
                        root.lastError       = ""
                        passInput.text       = ""
                        if (root.showHiddenEntry) hiddenFocusTimer.restart()
                    }
                }
            }

            
            Rectangle {
                width: 72; height: 26; radius: 13
                visible: root.wifiEnabled
                color: root.scanning ? pill.t_bg : pill.t_card
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: root.scanning ? "Scanning…" : "↻ Rescan"
                    color: root.scanning ? pill.t_textSub : pill.t_accent
                    font.pointSize: 7; font.bold: true
                    font.family: "JetBrainsMono Nerd Font Mono"
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.scanning
                    onClicked: { root.scanning = true; wifiRescan.running = true }
                }
            }
        }
    }

    
    Item {
        anchors.top: wifiHeader.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        visible: !root.wifiEnabled

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰖪"
                color: pill.t_textSub; font.pointSize: 28
                font.family: "JetBrainsMono Nerd Font Mono"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi is off"
                color: pill.t_textSub; font.pointSize: 9
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }
    }

    
    Rectangle {
        id: connectedBar
        anchors.top: wifiHeader.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 4
        height: root.wifiEnabled && root.connectedSsid !== "" && root.connectingTo === "" ? 30 : 0
        radius: 8; color: pill.t_bg
        border.width: 1; border.color: pill.t_border
        clip: true; visible: root.wifiEnabled && height > 0
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectedSignal > 70 ? "󰤨"
                    : root.connectedSignal > 40 ? "󰤥"
                    : root.connectedSignal > 10 ? "󰤢"
                    : "󰤯"
                color: pill.t_accent; font.pointSize: 9
                font.family: "JetBrainsMono Nerd Font Mono"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectedSsid
                color: pill.t_accent; font.pointSize: 8; font.bold: true
                font.family: "JetBrainsMono Nerd Font Mono"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectedSignal + "%"
                color: pill.t_accent; font.pointSize: 7
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            width: 68; height: 20; radius: 10
            color: disconnectMa.containsMouse ? "#2a0a0a" : pill.t_cardHover
            Behavior on color { ColorAnimation { duration: 120 } }
            border.width: 1
            border.color: disconnectMa.containsMouse ? "#ff4444" : pill.t_border
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰖪  Disconnect"
                color: disconnectMa.containsMouse ? "#ff6666" : pill.t_textSub
                font.pointSize: 6; font.bold: true
                font.family: "JetBrainsMono Nerd Font Mono"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: disconnectMa
                anchors.fill: parent; hoverEnabled: true
                onClicked: { if (!wifiDisconnect.running) wifiDisconnect.running = true }
            }
        }
    }

    
    Rectangle {
        id: errorBanner
        anchors.top: connectedBar.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 4
        height: root.lastError !== "" ? 28 : 0
        radius: 8; color: "#2a0a0a"
        border.width: 1; border.color: "#ff4444"
        clip: true; visible: height > 0
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent; spacing: 6
            Text {
                text: "󰅖"; color: "#ff4444"; font.pointSize: 9
                font.family: "JetBrainsMono Nerd Font Mono"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.lastError; color: "#ff6666"; font.pointSize: 8
                font.family: "JetBrainsMono Nerd Font Mono"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { anchors.fill: parent; onClicked: root.lastError = "" }
    }

    
    Rectangle {
        id: passwordBox
        anchors.top: errorBanner.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 4
        height: root.selectedSsid !== "" ? 38 : 0
        radius: 10; color: pill.t_bg; clip: true; visible: height > 0
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        border.width: 1
        border.color: root.lastError !== "" ? "#ff4444" : pill.t_border
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 6
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌆"; color: pill.t_accent; font.pointSize: 10
                font.family: "JetBrainsMono Nerd Font Mono"
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 90; height: 20

                Text {
                    anchors.fill: parent
                    text: "Password for " + root.selectedSsid
                    color: pill.t_textSub; font.pointSize: 9
                    font.family: "JetBrainsMono Nerd Font Mono"
                    visible: passInput.text === ""
                    verticalAlignment: Text.AlignVCenter
                }

                TextInput {
                    id: passInput
                    anchors.fill: parent
                    color: pill.t_text
                    font.pointSize:     root.showPassword ? 9 : 7
                    font.letterSpacing: root.showPassword ? 0 : 3
                    font.family: "JetBrainsMono Nerd Font Mono"
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    focus: root.selectedSsid !== ""
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: { root.passwordInput = text; root.lastError = "" }
                    Keys.onReturnPressed: {
                        if (text.length >= 8 && root.selectedSsid !== "" && !wifiConnect.running)
                            root.startConnect(root.selectedSsid, "", root.passwordInput, false)
                        root.selectedSsid = ""
                    }
                    Keys.onEscapePressed: {
                        root.selectedSsid = ""; root.passwordInput = ""
                        root.lastError = ""; text = ""
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12; color: pill.t_card
                Text {
                    anchors.centerIn: parent
                    text: root.showPassword ? "󰈉" : "󰈈"
                    color: pill.t_textSub; font.pointSize: 9
                    font.family: "JetBrainsMono Nerd Font Mono"
                }
                MouseArea { anchors.fill: parent; onClicked: root.showPassword = !root.showPassword }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: passInput.text.length >= 8 ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "→"
                    color: passInput.text.length >= 8 ? pill.t_bg : pill.t_textSub
                    font.pointSize: 10; font.bold: true
                    font.family: "JetBrainsMono Nerd Font Mono"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: passInput.text.length >= 8 && !wifiConnect.running
                    onClicked: {
                        root.startConnect(root.selectedSsid, "", root.passwordInput, false)
                        root.selectedSsid = ""
                    }
                }
            }
        }
    }

    Text {
        anchors.top: passwordBox.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 2
        text: "↵ connect   esc cancel"
        color: pill.t_textSub; font.pointSize: 6
        font.family: "JetBrainsMono Nerd Font Mono"
        visible: root.selectedSsid !== ""
        opacity: root.selectedSsid !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    
    Rectangle {
        id: hiddenBox
        anchors.top: passwordBox.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: root.selectedSsid !== "" ? 26 : 4
        height: root.showHiddenEntry ? 38 : 0
        radius: 10; color: pill.t_bg; clip: true; visible: height > 0
        Behavior on height           { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        border.width: 1; border.color: pill.t_border

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 6
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰈲"; color: pill.t_accent; font.pointSize: 10
                font.family: "JetBrainsMono Nerd Font Mono"
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 50; height: 20

                Text {
                    anchors.fill: parent
                    text: "Hidden network SSID…"
                    color: pill.t_textSub; font.pointSize: 9
                    font.family: "JetBrainsMono Nerd Font Mono"
                    visible: hiddenSsidInput.text === ""
                    verticalAlignment: Text.AlignVCenter
                }

                TextInput {
                    id: hiddenSsidInput
                    anchors.fill: parent
                    color: pill.t_text; font.pointSize: 9
                    font.family: "JetBrainsMono Nerd Font Mono"
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: root.hiddenSsid = text
                    Keys.onReturnPressed: {
                        if (text.trim().length > 0) {
                            root.showHiddenEntry = false
                            root.selectedSsid    = text.trim()
                            root.passwordInput   = ""
                            passInput.text       = ""
                            hiddenSsidInput.text = ""
                            focusTimer.restart()
                        }
                    }
                    Keys.onEscapePressed: { root.showHiddenEntry = false; text = "" }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: hiddenSsidInput.text.trim().length > 0 ? pill.t_accent : pill.t_card
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "→"
                    color: hiddenSsidInput.text.trim().length > 0 ? pill.t_bg : pill.t_textSub
                    font.pointSize: 10; font.bold: true
                    font.family: "JetBrainsMono Nerd Font Mono"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: hiddenSsidInput.text.trim().length > 0
                    onClicked: {
                        root.showHiddenEntry = false
                        root.selectedSsid    = hiddenSsidInput.text.trim()
                        root.passwordInput   = ""
                        passInput.text       = ""
                        hiddenSsidInput.text = ""
                        focusTimer.restart()
                    }
                }
            }
        }
    }

    
    Flickable {
        id: networkFlick
        anchors.top: hiddenBox.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        clip: true
        visible: root.wifiEnabled
        contentHeight: networkColumn.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 2; radius: 1; color: pill.t_card
            visible: networkFlick.contentHeight > networkFlick.height

            Rectangle {
                width: parent.width; radius: 1; color: pill.t_accent; opacity: 0.5
                height: Math.max(20, networkFlick.height / networkFlick.contentHeight * parent.height)
                y: networkFlick.contentY / networkFlick.contentHeight * parent.height
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.scanning ? "Scanning for networks…" : "No networks found"
            color: pill.t_textSub; font.pointSize: 9
            font.family: "JetBrainsMono Nerd Font Mono"
            visible: root.networks.length === 0
        }

        Column {
            id: networkColumn
            anchors.left: parent.left; anchors.right: parent.right
            anchors.rightMargin: 6
            spacing: 4

            Repeater {
                model: root.networks

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    id: netRow
                    width: networkColumn.width
                    height: showActions ? 66 : 38
                    radius: 10

                    property bool isConnecting: root.connectingTo === modelData.ssid
                    property bool isConnected:  modelData.active || modelData.ssid === root.connectedSsid
                    property bool isSelected:   root.selectedSsid === modelData.ssid
                    property bool showActions:  false

                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    color: isConnected  ? pill.t_bg
                         : isSelected   ? pill.t_bg
                         : isConnecting ? pill.t_cardHover
                         : pill.t_card
                    Behavior on color { ColorAnimation { duration: 150 } }

                    border.width: 1
                    border.color: isConnected  ? pill.t_accent
                                : isSelected   ? pill.t_cardHover
                                : isConnecting ? pill.t_border
                                : showActions  ? pill.t_textSub
                                : pill.t_cardHover
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    clip: true

                    Row {
                        id: mainRow
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 38; spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.signal > 70 ? "󰤨"
                                : modelData.signal > 40 ? "󰤥"
                                : modelData.signal > 10 ? "󰤢"
                                : "󰤯"
                            color: isConnected ? pill.t_accent : pill.t_textSub
                            font.pointSize: 11
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.ssid
                            color: isConnected ? pill.t_text : isSelected ? pill.t_text : pill.t_textSub
                            font.pointSize: 9; font.bold: isConnected
                            font.family: "JetBrainsMono Nerd Font Mono"
                            elide: Text.ElideRight
                            width: parent.width - 70
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isConnecting      ? root.dotAnimation()
                                : isConnected       ? "󰄬"
                                : modelData.secured ? "󰌆"
                                : ""
                            color: isConnected  ? pill.t_accent
                                 : isConnecting ? "#ffaa00"
                                 : pill.t_textSub
                            font.pointSize: isConnecting ? 11 : 10
                            font.family: "JetBrainsMono Nerd Font Mono"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Row {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: mainRow.bottom
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 28; spacing: 6
                        visible: netRow.showActions
                        opacity: netRow.showActions ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64; height: 20; radius: 10
                            color: "#1a1010"; border.width: 1; border.color: "#3a1a1a"

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴  Forget"
                                color: "#cc4444"; font.pointSize: 6.5; font.bold: true
                                font.family: "JetBrainsMono Nerd Font Mono"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    netRow.showActions  = false
                                    forgetCheck.ssid    = modelData.ssid
                                    forgetCheck.running = true
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52; height: 20; radius: 10
                            color: pill.t_card; border.width: 1; border.color: pill.t_border

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: pill.t_textSub; font.pointSize: 6.5
                                font.family: "JetBrainsMono Nerd Font Mono"
                            }
                            MouseArea { anchors.fill: parent; onClicked: netRow.showActions = false }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        pressAndHoldInterval: 600

                        onPressAndHold: netRow.showActions = !netRow.showActions

                        onClicked: {
                            if (netRow.showActions) { netRow.showActions = false; return }
                            if (root.connectingTo !== "" || wifiConnect.running || savedCheck.running) return
                            root.lastError = ""
                            if (root.selectedSsid === modelData.ssid) {
                                root.selectedSsid = ""; root.passwordInput = ""; passInput.text = ""
                                return
                            }
                            if (isConnected) return
                            if (modelData.secured) {
                                savedCheck.ssid    = modelData.ssid
                                savedCheck.running = true
                            } else {
                                root.startConnect(modelData.ssid, "", "", false)
                            }
                        }
                    }
                }
            }
        }
    }
}


