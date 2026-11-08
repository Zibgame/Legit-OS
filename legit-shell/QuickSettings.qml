import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "orpen" as Orpen
import "serpantinum/quickshell" as Serp

// Host for orpen123/quickshell-setup's original ControlCenter.qml.
// The visual components live in legit-shell/orpen; this file only provides
// the original pill contract and binds it to LEGIT services.
// Upstream attribution and licensing note: ORPEN123-NOTICE.md.
PanelWindow {
    id: panel
    property var state

    anchors { bottom: true; right: true }
    margins { bottom: 48; right: 8 }
    exclusiveZone: -1
    implicitWidth: 600
    implicitHeight: 580
    color: "transparent"
    WlrLayershell.namespace: "legit-quick-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    DankAudioService { id: audio }
    DankBluetoothService { id: bluetooth }
    DankNetworkService { id: network; active: panel.visible }
    DankBrightnessService { id: brightnessService; active: panel.visible }

    readonly property var activePlayer: {
        const players = Mpris.players.values
        if (players.length === 0) return null
        for (let i = 0; i < players.length; i++)
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
        for (let i = 0; i < players.length; i++)
            if (players[i].playbackState === MprisPlaybackState.Paused) return players[i]
        return players[0]
    }

    QtObject {
        id: pill

        // Original orpen123 pill theme contract, adapted to LEGIT cyan.
        property bool isLightMode: false
        property bool dnd: false
        readonly property color t_bg: "#e50a1018"
        readonly property color t_card: "#c914202c"
        readonly property color t_cardHover: "#df1c2b38"
        readonly property color t_text: "#f4f8fb"
        readonly property color t_textSub: "#9eb2bf"
        readonly property color t_accent: "#49d9ff"
        readonly property color t_border: "#6549d9ff"

        // Live LEGIT state exposed under the original property names.
        readonly property real volumeLevel: audio.volume
        readonly property real brightnessLevel: brightnessService.brightnessAvailable
                                                ? brightnessService.brightnessLevel / 100 : 0
        readonly property bool wifiEnabled: network.wifiEnabled
        readonly property int wifiSignal: network.wifiSignalStrength
        readonly property string wifiSsid: network.currentWifiSSID || "Not connected"
        readonly property bool btPowered: bluetooth.enabled
        readonly property string btDevice: bluetooth.primaryDeviceName
        readonly property var activePlayer: panel.activePlayer

        onDndChanged: {
            Serp.Config.setSetting("notifications.dnd", dnd)
        }
        onIsLightModeChanged: {
            schemeProc.running = false
            schemeProc.command = ["sh", "-c", "gsettings set org.gnome.desktop.interface color-scheme " + (isLightMode ? "default" : "prefer-dark") + " 2>/dev/null || true"]
            schemeProc.running = true
        }

        Component.onCompleted: {
            const notifications = Serp.Config.getSetting("notifications", { "dnd": false })
            dnd = Boolean(notifications && notifications.dnd)
        }
    }

    Process { id: schemeProc }

    Connections {
        target: Serp.Config
        function onSettingsLoaded() {
            const notifications = Serp.Config.getSetting("notifications", { "dnd": false })
            pill.dnd = Boolean(notifications && notifications.dnd)
        }
    }

    property real intro: 0
    NumberAnimation {
        id: openAnimation
        target: panel
        property: "intro"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }

    Rectangle {
        anchors.fill: parent
        radius: 25
        color: "#e40a1018"
        border.width: 1
        border.color: "#7549d9ff"
        opacity: panel.intro
        scale: 0.965 + panel.intro * 0.035
        transformOrigin: Item.BottomRight
        clip: true
        focus: true
        Keys.onEscapePressed: panel.state.closePopups()

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 24
            color: "#321d7b96"
        }

        Orpen.ControlCenter {
            id: controlCenter
            anchors.fill: parent
            anchors.margins: 4
            pill: pill
            onCloseRequested: panel.state.closePopups()
            onVolumeChanged: value => audio.setVolume(value)
            onBrightnessChanged: value => brightnessService.setBrightness(value * 100)
            onWifiToggleRequested: turningOn => {
                if (network.wifiAvailable && network.wifiEnabled !== turningOn)
                    network.toggleWifiRadio()
            }
            onBtToggleRequested: turningOn => bluetooth.setEnabled(turningOn)
        }
    }

    Connections {
        target: panel.state
        function onQuickSettingsViewChanged() {
            if (panel.visible) controlCenter.currentView = panel.state.quickSettingsView
        }
    }

    onVisibleChanged: {
        if (visible) {
            network.refresh()
            brightnessService.refresh()
            controlCenter.currentView = state.quickSettingsView
            intro = 0
            openAnimation.restart()
        }
    }
}
