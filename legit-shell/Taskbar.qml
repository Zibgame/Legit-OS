import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Io
import Quickshell.Hyprland

// LEGIT Shell taskbar: modern Windows-like bar docked to the bottom edges.
PanelWindow {
    id: bar

    property var state

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 44
    // Reserve this height on the monitor so maximized windows stop above the
    // bar instead of covering it (Hyprland reports it as reserved space).
    exclusiveZone: implicitHeight
    color: "transparent"
    // Namespace targeted by the Hyprland "glass-bar" layer rule (frosted blur).
    WlrLayershell.namespace: "legit-bar"

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#f0f0f0"
    // Translucent dark blue-tint: matches the right capsule and lets the
    // Hyprland layer blur show through for the frosted-glass premium look.
    readonly property color surface: "#d9161a22"
    readonly property color hover: "#22ffffff"
    readonly property color hairline: "#18ffffff"

    // ---- Running windows (polled via hyprctl, immune to quickshell #1427) --
    // Hyprland.toplevels hands out null handles in this quickshell build, so
    // the previous list never showed anything. `hyprctl -j clients` is the
    // same source the window-snap logic already uses successfully.
    property var openWins: []
    property string activeAddr: ""

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: winsProc.running = true
    }

    Process {
        id: winsProc
        command: ["sh", "-c", "hyprctl -j clients 2>/dev/null; echo; hyprctl -j activewindow 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("\n\n");
                var wins = [];
                try {
                    var list = JSON.parse(parts[0]);
                    for (var i = 0; i < list.length; i++) {
                        var c = list[i];
                        if (!c.mapped || c.hidden) continue;
                        if (!c.class || c.class.length === 0) continue; // xwayland placeholder
                        wins.push({
                            address: c.address,
                            cls: c.class,
                            title: c.title || "",
                            ws: c.workspace && c.workspace.name ? c.workspace.name : "1",
                            floating: c.floating
                        });
                    }
                } catch (e) { }
                bar.openWins = wins;
                try {
                    var act = JSON.parse(parts[1]);
                    bar.activeAddr = act && act.address ? act.address : "";
                } catch (e) { bar.activeAddr = ""; }
            }
        }
    }

    function activateWin(w) {
        var addr = "address:" + w.address;
        if (w.address === bar.activeAddr) {
            // Active -> minimize into the hidden special workspace (like the
            // Windows "minimize on second click" behavior).
            bar.state.luaDispatch('hl.dsp.window.move({ window = "' + addr + '", workspace = "special:min" })');
        } else {
            bar.state.luaDispatch('hl.dsp.focus({ window = "' + addr + '" })');
        }
    }

    function launch(cmd) {
        var safe = cmd.replace(/"/g, "");
        Hyprland.dispatch('hl.dsp.exec_cmd("' + safe + '")');
    }

    // ---- Right-capsule live state (DMS service-style) ---------------------
    // Real NetworkManager state polled through nmcli (same proven source as
    // QuickSettings): connected interface type drives the network icon.
    property string netState: ""       // nmcli general STATE: "fully" = online
    property string netType: ""        // "ethernet" | "wifi" | "" (none connected)
    property bool netAvailable: true   // nmcli present?

    Process {
        id: netStateProc
        command: ["sh", "-c",
            "if command -v nmcli >/dev/null 2>&1; then "
            + "echo STATE=$(nmcli -t -f CONNECTIVITY general 2>/dev/null); "
            + "echo TYPE=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep ':connected' | head -1 | cut -d: -f1); "
            + "else echo NMCli=missing; fi"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.startsWith("STATE=")) bar.netState = line.slice(6);
                else if (line.startsWith("TYPE=")) bar.netType = line.slice(5);
                else if (line.startsWith("NMCli=")) bar.netAvailable = false;
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { netStateProc.running = false; netStateProc.running = true; }
    }

    // Bluetooth state: real BlueZ only. No bluez package in the image -> the
    // button shows the disabled glyph dimmed (honest unavailability).
    property bool btAvailable: false
    property bool btEnabled: false

    Process {
        id: btStateProc
        command: ["sh", "-c",
            "if command -v bluetoothctl >/dev/null 2>&1; then "
            + "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo BT=on || echo BT=off; "
            + "echo BTAVAIL=yes; else echo BTAVAIL=no; fi"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "BT=on") { bar.btEnabled = true; }
                else if (line === "BT=off") { bar.btEnabled = false; }
                else if (line === "BTAVAIL=yes") { bar.btAvailable = true; }
                else if (line === "BTAVAIL=no") { bar.btAvailable = false; }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { btStateProc.running = false; btStateProc.running = true; }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool volMuted: (sink && sink.audio) ? Boolean(sink.audio.muted) : false
    readonly property real volLevel: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property string volIcon: {
        if (!sink) return "audio-volume-muted-symbolic";
        if (volMuted || volLevel === 0) return "audio-volume-muted-symbolic";
        if (volLevel < 0.34) return "audio-volume-low-symbolic";
        if (volLevel < 0.67) return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
    readonly property int batPct: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool batCharging: hasBattery ? UPower.displayDevice.state === UPowerDeviceState.Charging
                                                   || UPower.displayDevice.state === UPowerDeviceState.FullyCharged : false
    readonly property string batIcon: {
        if (!hasBattery) return "";
        var level = batPct >= 80 ? "full" : batPct >= 60 ? "good" : batPct >= 30 ? "good" : batPct >= 15 ? "caution" : "low";
        return "battery-" + level + (batCharging ? "-charging" : "") + "-symbolic";
    }

    // Toggle the Serpantinum dock by flipping dock.enabled in its settings
    // file: the Config singleton watches it (watchChanges) and the dock
    // updates live. python keeps the JSON edit safe.
    Process {
        id: dockToggleProc
        command: ["python3", "-c",
            "import json, os\n"
            + "p = os.path.expanduser('~/.config/serpantinum/settings.json')\n"
            + "d = json.load(open(p))\n"
            + "d.setdefault('dock', {})\n"
            + "d['dock']['enabled'] = not d['dock'].get('enabled', False)\n"
            + "json.dump(d, open(p, 'w'), indent=4)\n"]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.date = new Date()
    }

    property date date: new Date()

    // Frosted background + hairline on top edge
    Rectangle {
        anchors.fill: parent
        color: bar.surface
    }

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 1
        color: bar.hairline
    }

    // ---- Left cluster: start button + running windows only (no pinned
    //      favorites: open apps appear as they launch, like Windows).
    Row {
        id: leftArea
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 2

        // ---- Start button ----
        Item {
            width: 48
            height: 44

            MouseArea {
                id: startBtnMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.toggleStartMenu()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 40
                height: 34
                radius: 8
                color: startBtnMa.pressed ? "#33ffffff" : (startBtnMa.containsMouse ? bar.hover : "transparent")

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 3

                    Rectangle { width: 8; height: 8; radius: 1.5; color: bar.accent }
                    Rectangle { width: 8; height: 8; radius: 1.5; color: bar.accent }
                    Rectangle { width: 8; height: 8; radius: 1.5; color: bar.accent }
                    Rectangle { width: 8; height: 8; radius: 1.5; color: "#7fd6ff" }
                }
            }
        }

        // ---- Separator ----
        Rectangle {
            width: 1
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: bar.hairline
        }

        // ---- Running windows (one button per open client, polled list) ----
        Repeater {
            model: bar.openWins

            Item {
                id: topItem
                required property var modelData
                readonly property bool isActive: modelData.address === bar.activeAddr
                readonly property bool isMinimized: modelData.ws.indexOf("special:") === 0
                readonly property string iconName: modelData.cls

                width: 44
                height: 44

                MouseArea {
                    id: topMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            bar.state.luaDispatch('hl.dsp.window.close({ window = "address:' + topItem.modelData.address + '" })');
                        } else {
                            bar.activateWin(topItem.modelData);
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 34
                    radius: 8
                    color: topMa.pressed ? "#33ffffff" : (topMa.containsMouse ? bar.hover : "transparent")
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 24
                    opacity: topItem.isMinimized ? 0.45 : 1.0
                    source: Quickshell.iconPath(topItem.iconName.length ? topItem.iconName : "application-x-executable", "application-x-executable")
                }

                // Activity indicator: accent bar when active, gray dot otherwise
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 2
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: topItem.isActive ? 18 : 5
                    height: 3
                    radius: 1.5
                    Behavior on width { NumberAnimation { duration: 120 } }
                    color: topItem.isActive ? bar.accent : (topItem.isMinimized ? "#44444444" : "#66888888")
                }
            }
        }
    }

    // ---- Right side: DMS-inspired system capsule ---------------------------
    Row {
        anchors {
            right: parent.right
            rightMargin: 8
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 8

        // ---- Status capsule: network | bluetooth | volume | battery ----
        Rectangle {
            width: capsuleRow.implicitWidth + 20
            height: 34
            anchors.verticalCenter: parent.verticalCenter
            radius: 17
            // More translucent so the frosted layer blur reads through the
            // capsule: the premium glass effect of the reference design.
            color: "#8c161a22"
            border.color: bar.hairline
            border.width: 1

            Row {
                id: capsuleRow
                anchors.centerIn: parent
                spacing: 2

                // Network (real NetworkManager state; the icon reflects the
                // actually connected device type: ethernet or wifi).
                Item {
                    width: 32
                    height: 34

                    MouseArea {
                        id: netMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.state.openQuickSettings(1)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: netMa.pressed ? "#33ffffff" : (netMa.containsMouse ? "#2affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    SystemGlyph {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        opacity: bar.netAvailable ? (bar.netState === "full" ? 1.0 : 0.55) : 0.3
                        name: !bar.netAvailable || bar.netState !== "full" ? "network-off"
                              : (bar.netType === "ethernet" ? "ethernet" : "wifi")
                        glyphColor: bar.netState === "full" ? bar.accent : bar.textColor
                    }
                }

                // Bluetooth (real BlueZ; dimmed when unavailable).
                Item {
                    width: 32
                    height: 34
                    opacity: bar.btAvailable ? 1.0 : 0.35

                    MouseArea {
                        id: btMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.state.openQuickSettings(2)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: btMa.pressed ? "#33ffffff" : (btMa.containsMouse ? "#2affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    SystemGlyph {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: "bluetooth"
                        glyphColor: bar.btEnabled ? bar.accent : bar.textColor
                    }
                }

                // Volume (live PipeWire state).
                Item {
                    width: 32
                    height: 34
                    opacity: bar.sink ? 1.0 : 0.35

                    MouseArea {
                        id: volMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.state.openQuickSettings(0)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: volMa.pressed ? "#33ffffff" : (volMa.containsMouse ? "#2affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    SystemGlyph {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        name: bar.volMuted ? "mute" : "volume"
                        level: bar.volLevel
                        glyphColor: bar.volMuted ? "#9eb2bf" : bar.textColor
                    }
                }

                // Battery (UPower; hidden entirely when the machine has none).
                Item {
                    width: 60
                    height: 34
                    visible: bar.hasBattery

                    MouseArea {
                        id: batMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.state.openQuickSettings(0)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 28
                        radius: 14
                        color: batMa.pressed ? "#33ffffff" : (batMa.containsMouse ? "#2affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        SystemGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            name: "battery"
                            level: bar.batPct / 100
                            glyphColor: bar.batPct <= 15 ? "#ff6b6b" : (bar.batCharging ? bar.accent : bar.textColor)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.batPct + "%"
                            color: bar.textColor
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // ---- Separator ----
        Rectangle {
            width: 1
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: bar.hairline
        }

        // ---- Clock, two lines (click -> calendar) ----
        // Premium styling: bold time on top, dim date below, matching the
        // reference capsule layout.
        Item {
            width: Math.max(clockTime.width, clockDate.width) + 18
            height: 44

            MouseArea {
                id: clockMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.togglePanel("cal")
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(clockTime.width, clockDate.width) + 12
                height: 34
                radius: 8
                color: clockMa.pressed ? "#33ffffff" : (clockMa.containsMouse ? bar.hover : "transparent")
                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            Column {
                id: clockText
                anchors.centerIn: parent
                spacing: 0

                Text {
                    id: clockTime
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: bar.textColor
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.5
                    text: Qt.formatDateTime(bar.date, "HH:mm")
                }

                Text {
                    id: clockDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: bar.textColor
                    opacity: 0.62
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                    text: Qt.formatDateTime(bar.date, "dd/MM/yyyy")
                }
            }
        }

        // ---- Quick settings button (cyan square, sliders glyph) ----
        Item {
            width: 44
            height: 44

            MouseArea {
                id: qsMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.toggleQuickSettings()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: 10
                color: qsMa.pressed ? Qt.darker(bar.accent, 1.2)
                     : qsMa.containsMouse ? Qt.lighter(bar.accent, 1.15) : bar.accent
                border.color: "#66ffffff"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }

                SystemGlyph {
                    anchors.centerIn: parent
                    width: 21
                    height: 21
                    name: "settings"
                    glyphColor: "#0b2633"
                }
            }
        }
    }
}
