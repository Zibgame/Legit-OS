import QtQuick
import Quickshell.Io

// DMS BrightnessService-compatible subset (MIT). The upstream multi-device,
// DDC and software-gamma manager is implemented in Go. This adapter prefers a
// real brightnessctl device and falls back to Hyprland/hyprsunset gamma on
// VMs, OLED panels and external displays without /sys/class/backlight.
Item {
    id: root
    property bool active: false
    property bool brightnessAvailable: false
    property bool hardwareAvailable: false
    property bool softwareAvailable: false
    property string backend: "none"
    property int brightnessLevel: 0
    property int pendingLevel: 0
    property bool writing: false

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }
    function setBrightness(percentage) {
        if (!brightnessAvailable) return;
        brightnessLevel = Math.max(10, Math.min(100, Math.round(percentage)));
        pendingLevel = brightnessLevel;
        commit.restart();
    }

    onActiveChanged: if (active) refresh()
    Component.onCompleted: refresh()
    Timer { interval: 3500; running: root.active; repeat: true; onTriggered: root.refresh() }
    Timer {
        id: commit
        interval: 80
        onTriggered: {
            writeProc.running = false;
            writeProc.command = root.backend === "hardware"
                ? ["brightnessctl", "--class=backlight", "set", root.pendingLevel + "%"]
                : ["hyprctl", "hyprsunset", "gamma", root.pendingLevel.toString()];
            writeProc.running = true;
            root.writing = true;
        }
    }
    Process {
        id: readProc
        command: ["sh", "-c",
            "LEVEL=$(brightnessctl --class=backlight -m 2>/dev/null | awk -F, 'NR==1 {gsub(/%/,\"\",$4); print $4}'); "
            + "if [ -n \"$LEVEL\" ]; then echo BACKEND=hardware; echo LEVEL=$LEVEL; "
            + "elif command -v hyprsunset >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then "
            + "pgrep -x hyprsunset >/dev/null 2>&1 || (hyprsunset >/dev/null 2>&1 &); "
            + "sleep 0.15; LEVEL=$(hyprctl hyprsunset gamma 2>/dev/null | awk 'NR==1 {print int($1)}'); "
            + "echo BACKEND=software; echo LEVEL=${LEVEL:-100}; else echo BACKEND=none; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var mode = "none", value = NaN;
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("BACKEND=") === 0) mode = lines[i].slice(8);
                    else if (lines[i].indexOf("LEVEL=") === 0) value = Number(lines[i].slice(6));
                }
                root.backend = mode;
                root.hardwareAvailable = mode === "hardware";
                root.softwareAvailable = mode === "software";
                root.brightnessAvailable = mode !== "none" && isFinite(value) && value >= 0;
                if (root.brightnessAvailable && !root.writing) root.brightnessLevel = value;
            }
        }
    }
    Process { id: writeProc; onExited: { root.writing = false; root.refresh(); } }
}
