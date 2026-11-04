import QtQuick
import Quickshell
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

        function closePopups(except) {
            if (except !== "startmenu") shellState.startMenuOpen = false;
            if (except !== "qs") shellState.quickSettingsOpen = false;
        }

        function toggleStartMenu() {
            shellState.closePopups("startmenu");
            shellState.startMenuOpen = !shellState.startMenuOpen;
        }

        function toggleQuickSettings() {
            shellState.closePopups("qs");
            shellState.quickSettingsOpen = !shellState.quickSettingsOpen;
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
}