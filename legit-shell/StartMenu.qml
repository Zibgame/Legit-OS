import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland

// LEGIT Shell Start menu: Windows 11 inspired.
// Pinned grid (6x3 pages + dots), "Toutes les applications" A-Z list,
// integrated search, user chip + power row. Glass comes from the Hyprland
// layer rule on the "legit-start-menu" namespace.
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
    WlrLayershell.namespace: "legit-start-menu"

    // Take keyboard focus on demand so Escape reaches the menu; the menu is
    // modal enough while open but nothing is grabbed once it is hidden.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"
    readonly property color hoverBg: "#33070b12"
    readonly property color tileHover: "#29070b12"

    // ---- Installed applications (parsed from .desktop files) ---------------
    property var allApps: []
    property string filterText: ""
    property bool allAppsMode: false
    property int pinnedPage: 0

    // A-Z sorted view used by both the pinned fill and the "all apps" list.
    readonly property var sortedApps: {
        var arr = allApps.slice();
        arr.sort(function (a, b) {
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1;
        });
        return arr;
    }

    // Pinned layout: user favorites first, then every installed app A-Z.
    readonly property var pinnedApps: {
        var out = [];
        var seen = {};
        for (var i = 0; i < favorites.length; i++) {
            var f = favorites[i];
            seen[(f.name || "").toLowerCase()] = true;
            out.push(f);
        }
        for (var j = 0; j < sortedApps.length; j++) {
            var a = sortedApps[j];
            var k = a.name.toLowerCase();
            if (!seen[k]) {
                seen[k] = true;
                out.push(a);
            }
        }
        return out;
    }

    readonly property int pinnedPageSize: 18 // 6 x 3, like Windows 11
    readonly property int pageCount: Math.max(1, Math.ceil(pinnedApps.length / pinnedPageSize))

    readonly property var pageApps: {
        var start = pinnedPage * pinnedPageSize;
        return pinnedApps.slice(start, start + pinnedPageSize);
    }

    // Search results (best behavior: alphabetical, like the list view).
    readonly property var apps: {
        var f = filterText.toLowerCase();
        var out = [];
        if (f.length === 0) return out;
        for (var i = 0; i < sortedApps.length; i++) {
            var a = sortedApps[i];
            if (a.name.toLowerCase().indexOf(f) !== -1)
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
            + "done | LC_ALL=C sort -f"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|");
                if (parts.length < 2 || !parts[0]) return;
                // Reassign (not push) so every view rebinds as apps stream in.
                menu.allApps = menu.allApps.concat([{
                    name: parts[0],
                    exec: parts[1].replace(/%[fFuUdDnNickvm]/g, "").trim(),
                    icon: parts[2] || ""
                }]);
            }
        }
    }

    // Same favorites the old menu pinned, now seeded at the top of the grid.
    readonly property var favorites: [
        { name: "Terminal", exec: "legit-terminal", icon: "org.gnome.Console" },
        { name: "Chromium", exec: "chromium", icon: "chromium" },
        { name: "Fichiers", exec: "nautilus", icon: "org.gnome.Nautilus" },
        { name: "VS Code", exec: "code", icon: "visual-studio-code" },
        { name: "Ghidra", exec: "ghidraRun", icon: "ghidra" }
    ]

    // Hyprland >= 0.57 evaluates dispatch requests through its Lua engine:
    // the working form is exactly the one hyprland.lua uses, hl.dsp.*.
    function launch(cmd) {
        var safe = cmd.replace(/"/g, "");
        menu.state.luaDispatch('hl.dsp.exec_cmd("' + safe + '")');
        menu.state.closePopups();
    }

    function openAppAt(list, index) {
        if (index >= 0 && index < list.length)
            menu.launch(list[index].exec);
    }

    onVisibleChanged: {
        if (visible) {
            filterText = "";
            allAppsMode = false;
            pinnedPage = 0;
            searchInput.text = "";
            searchInput.focus = true;
        } else {
            searchInput.focus = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#b31a1d24"
        radius: 10
        border.color: "#18ffffff"
        border.width: 1

        // Escape closes the menu (the search field keeps its own handler).
        focus: true
        Keys.onEscapePressed: menu.state.closePopups()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6

            // ---- Search (top pill, like Win11) ----
            Rectangle {
                id: searchBox
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: "#8f262a31"
                radius: 19
                border.color: searchInput.activeFocus ? "#4d4bb3e4" : "#22ffffff"
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🔍"
                        font.pixelSize: 13
                        color: menu.subtext
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 40
                        height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: menu.textColor
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: {
                            menu.filterText = text;
                            if (menu.filterText.length)
                                menu.allAppsMode = false;
                            appList.currentIndex = -1;
                        }
                        Keys.onEscapePressed: menu.state.closePopups()
                        // Tab / Shift+Tab cycle the selection through the
                        // results wrapped around; Return launches it.
                        Keys.onTabPressed: {
                            if (menu.apps.length === 0) return;
                            appList.currentIndex =
                                appList.currentIndex >= menu.apps.length - 1 ? 0 : appList.currentIndex + 1;
                        }
                        Keys.onBacktabPressed: {
                            if (menu.apps.length === 0) return;
                            appList.currentIndex = appList.currentIndex <= 0
                                ? menu.apps.length - 1 : appList.currentIndex - 1;
                        }
                        Keys.onDownPressed: appList.currentIndex = Math.min(appList.currentIndex + 1, menu.apps.length - 1)
                        Keys.onUpPressed: {
                            if (appList.currentIndex < 0)
                                appList.currentIndex = menu.apps.length - 1;
                            else
                                appList.currentIndex = Math.max(appList.currentIndex - 1, 0);
                        }
                        Keys.onReturnPressed: {
                            if (appList.currentIndex >= 0)
                                menu.openAppAt(menu.apps, appList.currentIndex);
                            else if (menu.apps.length > 0)
                                menu.openAppAt(menu.apps, 0);
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 38
                    text: "Rechercher des applications"
                    font.pixelSize: 13
                    color: menu.subtext
                    visible: searchInput.text.length === 0
                }
            }

            // ---- Section header (pin view / back button in list view) ----
            Item {
                Layout.fillWidth: true
                height: 30

                // "Épinglées" + "Toutes les applications ›" (pin view).
                Item {
                    width: parent.width
                    height: parent.height
                    visible: menu.allAppsMode ? false : menu.filterText.length === 0

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Épinglées"
                        color: menu.textColor
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Rectangle {
                        id: allAppsBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: allAppsRow.width + 20
                        height: 30
                        radius: 15
                        color: allAppsMa.containsMouse ? menu.hoverBg : "transparent"

                        MouseArea {
                            id: allAppsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.allAppsMode = true;
                                allSortList.currentIndex = -1;
                                allSortList.positionViewAtBeginning();
                            }
                        }

                        Row {
                            id: allAppsRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Toutes les applications"
                                color: menu.textColor
                                font.pixelSize: 12
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: menu.textColor
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // "‹ Toutes les applications" back button (list view).
                Item {
                    width: parent.width
                    height: parent.height
                    visible: menu.allAppsMode && menu.filterText.length === 0

                    Rectangle {
                        id: backBtn
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: backRow.width + 20
                        height: 30
                        radius: 15
                        color: backMa.containsMouse ? menu.hoverBg : "transparent"

                        MouseArea {
                            id: backMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.allAppsMode = false;
                                menu.pinnedPage = 0;
                            }
                        }

                        Row {
                            id: backRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                color: menu.textColor
                                font.pixelSize: 13
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Toutes les applications"
                                color: menu.textColor
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ---- Pinned grid: 6 x 3 pages with dots ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: menu.filterText.length === 0 && !menu.allAppsMode

                Loader {
                    anchors.fill: parent
                    sourceComponent: pinnedGridPage
                }
            }

            Component {
                id: pinnedGridPage

                Item {
                    width: parent ? parent.width : 0
                    height: parent ? parent.height : 0

                    Grid {
                        id: pinGrid
                        anchors.fill: parent
                        columns: 6
                        rows: 3
                        spacing: 2

                        Repeater {
                            model: menu.pageApps

                            Rectangle {
                                id: pinTile
                                required property var modelData
                                required property int index
                                width: (pinGrid.width - 2 * (pinGrid.columns - 1)) / pinGrid.columns
                                height: (pinGrid.height - 2 * (pinGrid.rows - 1)) / pinGrid.rows
                                radius: 6
                                color: tileMa.containsMouse ? menu.tileHover : "transparent"

                                MouseArea {
                                    id: tileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: menu.launch(pinTile.modelData.exec)
                                }

                                Column {
                                    spacing: 8
                                    anchors.centerIn: parent

                                    IconImage {
                                        width: 32
                                        height: 32
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        source: Quickshell.iconPath(
                                            pinTile.modelData.icon.length ? pinTile.modelData.icon : "application-x-executable",
                                            "application-x-executable")
                                    }

                                    Text {
                                        width: pinTile.width - 10
                                        text: pinTile.modelData.name
                                        color: menu.textColor
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Wheel pages through the pinned grid, like Win11.
                    // WheelHandler only handles the wheel; it never steals the
                    // clicks that must reach the tiles underneath.
                    WheelHandler {
                        onWheel: function (ev) {
                            if (menu.pageCount < 2) return;
                            if (ev.angleDelta.y < 0)
                                menu.pinnedPage = Math.min(menu.pinnedPage + 1, menu.pageCount - 1);
                            else
                                menu.pinnedPage = Math.max(menu.pinnedPage - 1, 0);
                            ev.accepted = true;
                        }
                    }

                    // Page dots, centered under the grid.
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        visible: menu.pageCount > 1

                        Repeater {
                            model: menu.pageCount

                            Rectangle {
                                required property int index
                                width: index === menu.pinnedPage ? 16 : 6
                                height: 6
                                radius: 3
                                Behavior on width { NumberAnimation { duration: 120 } }
                                color: index === menu.pinnedPage ? menu.accent : "#55ffffff"

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: menu.pinnedPage = index
                                }
                            }
                        }
                    }
                }
            }

            // ---- All apps: alphabetical list with letter sections ----
            ListView {
                id: allSortList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: menu.filterText.length === 0 && menu.allAppsMode
                clip: true
                model: menu.sortedApps
                currentIndex: -1
                spacing: 2

                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                ScrollBar.vertical: ScrollBar { }

                section.property: "name"
                section.criteria: ViewSection.FirstCharacter
                section.delegate: Text {
                    required property string section
                    text: section.toUpperCase()
                    color: menu.subtext
                    font.pixelSize: 12
                    font.bold: true
                    topPadding: 8
                    leftPadding: 4
                }

                delegate: Rectangle {
                    width: allSortList.width
                    height: 40
                    radius: 4
                    color: appRowMa.containsMouse || ListView.isCurrentItem ? menu.hoverBg : "transparent"

                    required property var modelData

                    MouseArea {
                        id: appRowMa
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: menu.textColor
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // ---- Search results ----
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: menu.filterText.length > 0
                clip: true
                model: menu.apps
                currentIndex: -1
                spacing: 2

                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                Text {
                    anchors.centerIn: parent
                    visible: menu.apps.length === 0
                    text: "Aucune application trouvée"
                    color: menu.subtext
                    font.pixelSize: 12
                }

                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle {
                    width: appList.width
                    height: 40
                    radius: 4
                    color: resultRowMa.containsMouse || ListView.isCurrentItem ? menu.hoverBg : "transparent"

                    required property var modelData

                    MouseArea {
                        id: resultRowMa
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

            // ---- Bottom bar: user chip + settings/lock/restart/power ----
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 4

                // User chip (display only, like Win11).
                Rectangle {
                    width: userRow.width + 16
                    height: 34
                    radius: 17
                    color: "transparent"

                    Row {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: menu.accent

                            Text {
                                anchors.centerIn: parent
                                text: "L"
                                color: "#12141d"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "legit"
                            color: menu.textColor
                            font.pixelSize: 12
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Settings / lock / restart / power — same actions as before.
                Row {
                    spacing: 2

                    Repeater {
                        model: [
                            { label: "⚙", tip: "Paramètres", act: function () { menu.state.closePopups(); menu.state.toggleQuickSettings(); } },
                            { label: "🔒", tip: "Verrouiller", act: function () { menu.state.luaDispatch('hl.dsp.exec_cmd("swaylock -f")'); menu.state.closePopups(); } },
                            { label: "⟳", tip: "Redémarrer", act: function () { menu.state.luaDispatch('hl.dsp.exec_cmd("systemctl reboot")'); menu.state.closePopups(); } },
                            { label: "⏻", tip: "Éteindre", act: function () { menu.state.luaDispatch('hl.dsp.exec_cmd("systemctl poweroff")'); menu.state.closePopups(); } }
                        ]

                        Rectangle {
                            id: sysBtn
                            required property var modelData
                            width: 40
                            height: 36
                            radius: 18
                            color: sysBtnMa.containsMouse
                                    ? (modelData.tip === "Redémarrer" || modelData.tip === "Éteindre" ? "#63c0392b" : menu.hoverBg)
                                    : "transparent"

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
            }
        }
    }
}
