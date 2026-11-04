import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
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

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#f0f0f0"
    readonly property color surface: "#dd1d1d1f"
    readonly property color hover: "#22ffffff"
    readonly property color hairline: "#18ffffff"

    // Pinned launchers (left of running apps)
    readonly property var pinned: [
        { name: "Terminal", exec: "kgx", icon: "org.gnome.Console" },
        { name: "Chromium", exec: "chromium", icon: "chromium" },
        { name: "Fichiers", exec: "nautilus", icon: "org.gnome.Nautilus" }
    ]

    function launch(cmd) {
        var safe = cmd.replace(/"/g, "");
        Hyprland.dispatch('hl.dsp.exec_cmd("' + safe + '")');
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
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

    // Left cluster
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

        // ---- Pinned apps ----
        Repeater {
            model: bar.pinned

            Item {
                id: pinItem
                required property var modelData
                width: 44
                height: 44

                MouseArea {
                    id: pinMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.launch(modelData.exec)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 34
                    radius: 8
                    color: pinMa.pressed ? "#33ffffff" : (pinMa.containsMouse ? bar.hover : "transparent")
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 24
                    source: Quickshell.iconPath(pinItem.modelData.icon, "application-x-executable")
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

        // ---- Running windows (one button per toplevel, icon based) ----
        Repeater {
            model: Hyprland.toplevels

            Item {
                id: topItem
                required property var modelData
                readonly property bool hasHandle: modelData.handle !== null
                readonly property bool isActive: modelData.activated
                readonly property bool isMinimized: {
                    var ipc = modelData.lastIpcObject;
                    return !!(ipc && ipc.workspace && ipc.workspace.name && ipc.workspace.name.indexOf("special:") === 0);
                }
                readonly property string iconName: {
                    var ipc = modelData.lastIpcObject;
                    return ipc && ipc.class ? ipc.class : "";
                }

                width: 44
                height: 44
                visible: hasHandle

                MouseArea {
                    id: topMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            topItem.modelData.handle.close();
                        } else if (topItem.isActive) {
                            bar.state.luaDispatch('hl.dsp.window.move({ window = "address:' + topItem.modelData.address + '", workspace = "special:min" })');
                        } else {
                            topItem.modelData.handle.activate();
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

    // ---- Right side: system area ----
    Row {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 2

        // System tray
        Repeater {
            model: SystemTray.items

            Item {
                id: trayItem
                required property var modelData
                width: 32
                height: 44

                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            trayItem.modelData.secondaryActivate();
                        } else {
                            trayItem.modelData.activate();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 34
                    radius: 8
                    color: trayMa.pressed ? "#33ffffff" : (trayMa.containsMouse ? bar.hover : "transparent")
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: trayItem.modelData.icon
                }
            }
        }

        // Volume (hidden when no audio sink)
        Item {
            width: 34
            height: 44
            visible: Pipewire.defaultAudioSink !== null

            MouseArea {
                id: volMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.toggleQuickSettings()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 34
                radius: 8
                color: volMa.pressed ? "#33ffffff" : (volMa.containsMouse ? bar.hover : "transparent")
            }

            Text {
                anchors.centerIn: parent
                text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "🔇" : "🔊"
                font.pixelSize: 14
            }
        }

        // Battery (hidden when absent, e.g. desktop VM)
        Item {
            width: 36
            height: 44
            visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery

            Text {
                anchors.centerIn: parent
                text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
                color: bar.textColor
                font.pixelSize: 12
            }
        }

        // Clock
        Item {
            width: clockText.width + 18
            height: 44

            MouseArea {
                id: clockMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.toggleQuickSettings()
            }

            Rectangle {
                anchors.centerIn: parent
                width: clockText.width + 12
                height: 34
                radius: 8
                color: clockMa.pressed ? "#33ffffff" : (clockMa.containsMouse ? bar.hover : "transparent")
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                color: bar.textColor
                font.pixelSize: 11
                text: Qt.formatDateTime(bar.date, "HH:mm\ndd/MM/yyyy")
            }
        }

        // Quick settings button
        Item {
            width: 32
            height: 44

            MouseArea {
                id: qsMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: bar.state.toggleQuickSettings()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 34
                radius: 8
                color: qsMa.pressed ? "#33ffffff" : (qsMa.containsMouse ? bar.hover : "transparent")
            }

            Text {
                anchors.centerIn: parent
                text: "⚙"
                font.pixelSize: 15
                color: bar.textColor
            }
        }
    }
}