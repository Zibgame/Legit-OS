import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "."

ShellRoot {
    id: root

    // ---- Shared shell state + helpers --------------------------------------
    QtObject {
        id: shellState

        property bool startMenuOpen: false
        property bool quickSettingsOpen: false
        // 0 = main controls, 1 = upstream WifiPanel, 2 = upstream BtPanel.
        property int quickSettingsView: 0
        // Serpantinum panels (vendored under ./serpantinum, see NOTICE.md).
        property bool serpSettingsOpen: false
        property bool serpWallpaperOpen: false
        property bool serpMusicOpen: false
        // Noctalia-style system popups opened from the right taskbar capsule.
        property bool netPanelOpen: false
        property bool btPanelOpen: false
        property bool volPanelOpen: false
        property bool calPanelOpen: false

        function closePopups(except) {
            if (except !== "startmenu") shellState.startMenuOpen = false;
            if (except !== "qs") shellState.quickSettingsOpen = false;
            if (except !== "serpsettings") shellState.serpSettingsOpen = false;
            if (except !== "serpwallpaper") shellState.serpWallpaperOpen = false;
            if (except !== "serpmusic") shellState.serpMusicOpen = false;
            if (except !== "net") shellState.netPanelOpen = false;
            if (except !== "bt") shellState.btPanelOpen = false;
            if (except !== "vol") shellState.volPanelOpen = false;
            if (except !== "cal") shellState.calPanelOpen = false;
        }

        function toggleStartMenu() {
            shellState.closePopups("startmenu");
            shellState.startMenuOpen = !shellState.startMenuOpen;
        }

        function toggleQuickSettings() {
            shellState.closePopups("qs");
            shellState.quickSettingsView = 0;
            shellState.quickSettingsOpen = !shellState.quickSettingsOpen;
        }

        function openQuickSettings(view) {
            shellState.closePopups("qs");
            shellState.quickSettingsView = view === undefined ? 0 : view;
            shellState.quickSettingsOpen = true;
        }

        function toggleSerp(kind) {
            // kind: "settings" | "wallpaper" | "music"
            var prop = kind === "serpsettings" ? "serpSettingsOpen"
                     : kind === "serpwallpaper" ? "serpWallpaperOpen"
                     : "serpMusicOpen";
            shellState.closePopups(kind);
            shellState[prop] = !shellState[prop];
        }

        function togglePanel(kind) {
            // kind: "net" | "bt" | "vol" | "cal" — right-capsule system popups.
            var prop = kind === "net" ? "netPanelOpen"
                     : kind === "bt" ? "btPanelOpen"
                     : kind === "vol" ? "volPanelOpen"
                     : "calPanelOpen";
            shellState.closePopups(kind);
            shellState[prop] = !shellState[prop];
        }

        function luaDispatch(expr) {
            Hyprland.dispatch(expr);
        }

        function snapWindow(win, dir) {
            var addr = "address:" + win.address;
            var half = Math.floor((win.monitorWidth || 1280) / 2);
            var height = (win.monitorHeight || 800) - 44;
            var tx = dir === "left" ? 0 : half;
            if (win.fullscreen > 0) {
                var mode = win.fullscreen === 2 ? "fullscreen" : "maximized";
                shellState.luaDispatch('hl.dsp.window.fullscreen({ window = "' + addr + '", mode = "' + mode + '", action = "unset" })');
            }
            shellState.luaDispatch('hl.dsp.window.move({ window = "' + addr + '", x = ' + tx + ', y = 0 })');
            shellState.luaDispatch('hl.dsp.window.resize({ window = "' + addr + '", x = ' + half + ', y = ' + height + ' })');
        }

        function superDown(win) {
            var addr = "address:" + win.address;
            if (win.fullscreen > 0) {
                var mode = win.fullscreen === 2 ? "fullscreen" : "maximized";
                shellState.luaDispatch('hl.dsp.window.fullscreen({ window = "' + addr + '", mode = "' + mode + '", action = "unset" })');
            } else if (win.floating) {
                shellState.luaDispatch('hl.dsp.window.move({ window = "' + addr + '", workspace = "special:min" })');
            } else {
                shellState.luaDispatch('hl.dsp.window.fullscreen({ window = "' + addr + '", mode = "maximized" })');
            }
        }
    }

    // ---- Command channel (legit-shell-ctl appends one command per line) -----
    property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/0"
    property string eventsFile: runtimeDir + "/legit-shell.events"
    property string pendingCmd: ""

    Process {
        // Create the file *before* tailing it: a bare `tail -F` races the
        // `touch` and exits with "No such file", after which no command
        // (startmenu, snap, superdown) is ever received.
        command: ["sh", "-c", "touch '" + root.eventsFile + "'; exec tail -F -n 0 '" + root.eventsFile + "'"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var cmd = data.trim();
                if (cmd.length === 0) return;
                console.log("CTL recv:", cmd);
                if (cmd === "startmenu") {
                    shellState.toggleStartMenu();
                } else if (cmd === "qs") {
                    shellState.toggleQuickSettings();
                } else if (cmd === "settings") {
                    shellState.toggleSerp("serpsettings");
                } else if (cmd === "wallpaper") {
                    shellState.toggleSerp("serpwallpaper");
                } else if (cmd === "music") {
                    shellState.toggleSerp("serpmusic");
                } else if (cmd === "net") {
                    shellState.openQuickSettings(1);
                } else if (cmd === "bt") {
                    shellState.openQuickSettings(2);
                } else if (cmd === "vol") {
                    shellState.openQuickSettings(0);
                } else if (cmd === "cal") {
                    shellState.togglePanel("cal");
                } else if (cmd === "superdown" || cmd.startsWith("snap ")) {
                    root.pendingCmd = cmd;
                    activeWinProc.running = false;
                    activeWinProc.running = true;
                }
            }
        }
    }

    // Active window lookup via hyprctl IPC (immune to quickshell #1427)
    Process {
        id: activeWinProc
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                var win;
                try { win = JSON.parse(this.text); } catch (e) { return; }
                if (!win || !win.address) return;
                win.monitorWidth = 1280;
                win.monitorHeight = 800;
                var cmd = root.pendingCmd;
                if (cmd === "superdown") {
                    shellState.superDown(win);
                } else if (cmd.startsWith("snap ")) {
                    shellState.snapWindow(win, cmd.slice(5).trim());
                }
            }
        }
    }

    // ---- Windows-like dismissal -------------------------------------------
    // While a menu is open its panel holds the keyboard (WlrKeyboardFocus.
    // Exclusive), so Hyprland reports no active toplevel. As soon as a *window*
    // takes focus again -- you clicked it, even if it was the same window --
    // activeToplevel becomes non-null and we close. Nothing is intercepted:
    // the click is delivered to that window normally.
    // The transition caused by opening the panel itself is ignored (grace).
    Timer { id: armTimer; interval: 500; repeat: false }
    property bool popupsOpen: shellState.startMenuOpen || shellState.quickSettingsOpen
        || shellState.serpSettingsOpen || shellState.serpWallpaperOpen || shellState.serpMusicOpen
        || shellState.netPanelOpen || shellState.btPanelOpen || shellState.volPanelOpen || shellState.calPanelOpen
    onPopupsOpenChanged: armTimer.restart()

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (!root.popupsOpen) return;
            if (armTimer.running) return;                 // opening transition
            if (Hyprland.activeToplevel) shellState.closePopups();
        }
    }

    // ---- UI ---------------------------------------------------------------
    Taskbar {
        state: shellState
    }

    StartMenu {
        state: shellState
        visible: shellState.startMenuOpen
    }

    QuickSettings {
        state: shellState
        visible: shellState.quickSettingsOpen
    }

    // ---- Vendored Serpantinum panels (see legit-shell/serpantinum/NOTICE.md).
    // Serpantinum ships its components as bare Item trees; the parent window
    // geometry is the host's business. Settings slides in on the right side,
    // wallpaper picker and music+EQ cover the whole screen. Each host is lazy:
    // the vendored tree is only instantiated on first open, so the plain
    // shell's startup stays cheap and nothing outside these three parts is
    // ever loaded (no upstream bar, dock, launcher, ...).
    PanelWindow {
        anchors { top: true; bottom: true; right: true }
        exclusiveZone: -1
        implicitWidth: 480
        color: "transparent"
        WlrLayershell.namespace: "legit-serp-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        visible: shellState.serpSettingsOpen

        Loader {
            anchors.fill: parent
            active: shellState.serpSettingsOpen
            source: "serpantinum/quickshell/syspanel/SystemPanel.qml"
            onLoaded: if (item) item.visible = true
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "legit-serp-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        visible: shellState.serpWallpaperOpen

        Loader {
            anchors.fill: parent
            active: shellState.serpWallpaperOpen
            source: "serpantinum/quickshell/wallpaper/WallpaperPicker.qml"
            onLoaded: if (item) item.visible = true
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "legit-serp-music"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        visible: shellState.serpMusicOpen

        Loader {
            anchors.fill: parent
            active: shellState.serpMusicOpen
            source: "serpantinum/quickshell/media/MusicPopup.qml"
            onLoaded: if (item) {
                item.visible = true;
                if (item.resetAndPlayIntro) item.resetAndPlayIntro();
            }
        }
    }

    // ---- Noctalia-style system popups (network / bluetooth / audio /
    //      calendar). Each is a full-screen transparent layer: the overlay
    //      swallows clicks outside the card (closes the panel) and holds the
    //      keyboard so Escape reaches it.
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "legit-net-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        visible: shellState.netPanelOpen

        // Click outside the card closes the panel.
        MouseArea { anchors.fill: parent; onClicked: shellState.closePopups() }

        Item {
            width: 470
            height: 640
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 8
                bottomMargin: 52
            }

            Loader {
                anchors.fill: parent
                active: shellState.netPanelOpen
                source: "serpantinum/quickshell/network/NetworkPopup.qml"
                onLoaded: if (item) item.visible = true
            }
        }
    }

    BtPanel { state: shellState; visible: shellState.btPanelOpen }
    VolumePanel { state: shellState; visible: shellState.volPanelOpen }
    CalendarPanel { state: shellState; visible: shellState.calPanelOpen }

    // ---- Serpantinum dock (AGPL-3.0, see legit-shell/serpantinum/NOTICE.md).
    // Self-windowed upstream component: vertical dock pinned to the left edge
    // (autohide from the edge), pretty app icons, pinned + installed apps via
    // its picker. Geometry/autohide/size come from
    // ~/.config/serpantinum/settings.json ("dock" section).
    Loader {
        active: true
        source: "serpantinum/quickshell/dock/Dock.qml"
    }
}
