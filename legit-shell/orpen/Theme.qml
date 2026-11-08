pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string accent:     "#49d9ff"
    property string background: "#0a1018"
    property string surface:    "#101a24"
    property string surface2:   "#14202c"
    property string text:       "#f4f8fb"
    property string subtext:    "#9eb2bf"

    function reload() {
        themeRead.running = true
    }

    Process {
        id: themeRead
        command: ["bash", "-c",
            "cat ~/.config/quickshell/themes/$(cat ~/.config/quickshell/themes/.active 2>/dev/null || echo ariadne).json 2>/dev/null"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.accent     = d.accent     || "#49d9ff"
                    root.background = d.background || "#0a1018"
                    root.surface    = d.surface    || "#101a24"
                    root.surface2   = d.surface2   || "#14202c"
                    root.text       = d.text       || "#f4f8fb"
                    root.subtext    = d.subtext     || "#9eb2bf"
                } catch(e) {}
            }
        }
    }

    
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: themeRead.running = true
    }
}




