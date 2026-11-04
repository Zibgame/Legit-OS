import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland

// LEGIT Shell Start menu: Windows 10 inspired.
PanelWindow {
    id: menu

    property var state

    anchors {
        bottom: true
        left: true
    }

    margins {
        bottom: 44
        left: 4
    }

    exclusiveZone: 0

    implicitWidth: 640
    implicitHeight: 580
    color: "transparent"

    // Take keyboard focus on demand (never exclusive) so Escape reaches the
    // menu; no input is ever grabbed from the rest of the screen.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"

    // ---- Installed applications (parsed from .desktop files) ---------------
    property var allApps: []
    property string filterText: ""

    readonly property var apps: {
        var f = filterText.toLowerCase();
        var out = [];
        for (var i = 0; i < allApps.length; i++) {
            var a = allApps[i];
            if (f.length === 0 || a.name.toLowerCase().indexOf(f) !== -1)
                out.push(a);
        }
        return out;
    }

    Process {
        id: appsLoader
        command: ["sh", "-c", "for f in /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop; do "
            + "[ -f \"$f\" ] || continue; "
            + "grep -q '^NoDisplay=true' \"$f\" && continue; "
            + "name=$(sed -n 's/^Name=//p' \"$f\" | head -n 1); "
            + "exec=$(sed -n 's/^Exec=//p' \"$f\" | head -n 1); "
            + "icon=$(sed -n 's/^Icon=//p' \"$f\" | head -n 1); "
            + "[ -n \"$name\" ] && echo \"$name|$exec|$icon\"; "
            + "done | sort"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|");
                if (parts.length < 2 || !parts[0]) return;
                menu.allApps.push({ name: parts[0], exec: parts[1].replace(/%[fFuUdDnNickvm]/g, "").trim(), icon: parts[2] || "" });
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            filterText = "";
            searchInput.text = "";
            searchInput.focus = true;
        }
    }

    readonly property var favorites: [
        { name: "Terminal", exec: "kgx", icon: "org.gnome.Console" },
        { name: "Chromium", exec: "chromium", icon: "chromium" },
        { name: "Fichiers", exec: "nautilus", icon: "org.gnome.Nautilus" },
        { name: "VS Code", exec: "code", icon: "visual-studio-code" },
        { name: "Ghidra", exec: "ghidraRun", icon: "ghidra" }
    ]

    function launch(cmd) {
        var safe = cmd.replace(/"/g, "");
        Hyprland.dispatch('hl.dsp.exec_cmd("' + safe + '")');
        state.closePopups();
    }

    Rectangle {
        anchors.fill: parent
        color: "#dd1d1d1f"
        radius: 8
        border.color: "#18ffffff"
        border.width: 1

        // Escape closes the menu (the search field keeps its own handler).
        focus: true
        Keys.onEscapePressed: menu.state.closePopups()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ---- Search ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: "#2a2a2a"
                radius: 4

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: menu.textColor
                    font.pixelSize: 13
                    clip: true
                    onTextChanged: {
                        menu.filterText = text;
                        appList.currentIndex = -1;
                    }
                    Keys.onEscapePressed: menu.state.closePopups()
                    Keys.onDownPressed: appList.currentIndex = Math.min(appList.currentIndex + 1, menu.apps.length - 1)
                    Keys.onUpPressed: {
                        if (appList.currentIndex < 0)
                            appList.currentIndex = menu.apps.length - 1;
                        else
                            appList.currentIndex = Math.max(appList.currentIndex - 1, 0);
                    }
                    Keys.onReturnPressed: {
                        if (appList.currentIndex >= 0 && appList.currentIndex < menu.apps.length)
                            menu.launch(menu.apps[appList.currentIndex].exec);
                        else if (menu.apps.length > 0)
                            menu.launch(menu.apps[0].exec);
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: "🔍"
                    font.pixelSize: 13
                    color: menu.subtext
                    visible: searchInput.text.length === 0
                }
            }

            // ---- App list ----
            Text {
                text: filterText.length ? "Applications — " + menu.apps.length + " trouvée(s)" : "Applications"
                color: menu.subtext
                font.pixelSize: 11
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: menu.apps
                currentIndex: -1

                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle {
                    width: appList.width
                    height: 40
                    color: appMa.containsMouse || ListView.isCurrentItem ? "#2d2d2d" : "transparent"

                    required property var modelData

                    MouseArea {
                        id: appMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: menu.launch(modelData.exec)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        IconImage {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(modelData.icon.length ? modelData.icon : "application-x-executable", "application-x-executable")
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: modelData.name
                                color: menu.textColor
                                font.pixelSize: 13
                            }
                            Text {
                                text: modelData.exec
                                color: menu.subtext
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // ---- Favorites ----
            Text {
                text: "Favoris"
                color: menu.subtext
                font.pixelSize: 11
            }

            Row {
                id: favoritesRow
                spacing: 8

                Repeater {
                    model: menu.favorites

                    Rectangle {
                        id: favItem
                        required property var modelData
                        width: 92
                        height: 56
                        radius: 4
                        color: favMa.containsMouse ? "#2d2d2d" : "#262626"

                        MouseArea {
                            id: favMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: menu.launch(modelData.exec)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            IconImage {
                                width: 22
                                height: 22
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Quickshell.iconPath(modelData.icon.length ? modelData.icon : "application-x-executable", "application-x-executable")
                            }

                            Text {
                                text: modelData.name
                                color: menu.textColor
                                font.pixelSize: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }

            // ---- Bottom row: settings, lock, restart, power off ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: "#262626"
                radius: 4

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "⚙", tip: "Paramètres", act: function () { menu.state.closePopups(); menu.state.toggleQuickSettings(); } },
                            { label: "🔒", tip: "Verrouiller", act: function () { Hyprland.dispatch('hl.dsp.exec_cmd("swaylock -f")'); menu.state.closePopups(); } }
                        ]

                        Rectangle {
                            id: sysBtn
                            required property var modelData
                            width: 40
                            height: 36
                            radius: 3
                            color: sysBtnMa.containsMouse ? "#3a3a3a" : "transparent"

                            MouseArea {
                                id: sysBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData.act()
                            }

                            Text {
                                anchors.centerIn: parent
                                text: sysBtn.modelData.label
                                color: menu.textColor
                                font.pixelSize: 15
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "⟳", cmd: "systemctl reboot" },
                            { label: "⏻", cmd: "systemctl poweroff" }
                        ]

                        Rectangle {
                            id: pwrBtn
                            required property var modelData
                            width: 40
                            height: 36
                            radius: 3
                            color: pwrMa.containsMouse ? "#c0392b" : "transparent"

                            MouseArea {
                                id: pwrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Hyprland.dispatch('hl.dsp.exec_cmd("' + modelData.cmd + '")');
                                    menu.state.closePopups();
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: pwrBtn.modelData.label
                                color: menu.textColor
                                font.pixelSize: 15
                            }
                        }
                    }
                }
            }
        }
    }
}