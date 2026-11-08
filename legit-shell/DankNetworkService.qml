import QtQuick
import Quickshell.Io

// Contract adapted from DMS NetworkService/DMSNetworkService (MIT). DMS's
// complete implementation talks to its Go daemon for NetworkManager secrets,
// VPN and enterprise Wi-Fi. LEGIT's subset keeps the same state/action model
// and uses NetworkManager's real nmcli frontend without a competing daemon.
Item {
    id: root
    property bool active: false
    property bool networkAvailable: false
    property string networkStatus: "disconnected"
    property string primaryConnection: ""
    property bool ethernetConnected: false
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string currentWifiSSID: ""
    property int wifiSignalStrength: 0
    property bool wifiToggling: false
    readonly property string wifiSignalIcon: wifiConnected ? "wifi" : "network-off"

    function refresh() {
        stateProbe.running = false;
        stateProbe.running = true;
    }
    function toggleWifiRadio() {
        if (!networkAvailable || wifiToggling) return;
        wifiToggling = true;
        toggleProc.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
        toggleProc.running = true;
    }

    onActiveChanged: if (active) refresh()
    Component.onCompleted: refresh()
    Timer { interval: 3500; running: root.active; repeat: true; onTriggered: root.refresh() }

    Process {
        id: stateProbe
        command: ["sh", "-c",
            "if command -v nmcli >/dev/null 2>&1 && nmcli -t -f RUNNING general 2>/dev/null | grep -q '^running$'; then "
            + "echo AVAILABLE=1; echo WIFI_AVAIL=$(nmcli -t -f TYPE dev 2>/dev/null | grep -c '^wifi$'); "
            + "echo WIFI_ON=$(nmcli radio wifi 2>/dev/null); "
            + "echo ETH=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c '^ethernet:connected'); "
            + "echo SSID=$(nmcli -t -f IN-USE,SSID dev wifi 2>/dev/null | sed -n 's/^\\*://p' | head -1); "
            + "echo SIGNAL=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | sed -n 's/^\\*://p' | head -1); "
            + "else IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}'); "
            + "if [ -n \"$IFACE\" ]; then echo AVAILABLE=1; "
            + "if [ -d /sys/class/net/$IFACE/wireless ]; then echo WIFI_AVAIL=1; echo WIFI_ON=enabled; echo ETH=0; "
            + "else echo WIFI_AVAIL=0; echo WIFI_ON=disabled; echo ETH=1; fi; "
            + "else echo AVAILABLE=0; echo WIFI_AVAIL=0; echo ETH=0; fi; echo SSID=; echo SIGNAL=0; fi"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim(), pos = line.indexOf("=");
                if (pos < 0) return;
                var key = line.slice(0, pos), value = line.slice(pos + 1);
                if (key === "AVAILABLE") root.networkAvailable = value === "1";
                else if (key === "WIFI_AVAIL") root.wifiAvailable = Number(value) > 0;
                else if (key === "WIFI_ON") root.wifiEnabled = value === "enabled";
                else if (key === "ETH") root.ethernetConnected = Number(value) > 0;
                else if (key === "SSID") { root.currentWifiSSID = value; root.wifiConnected = value.length > 0; }
                else if (key === "SIGNAL") root.wifiSignalStrength = Number(value) || 0;
                root.networkStatus = root.ethernetConnected ? "ethernet" : (root.wifiConnected ? "wifi" : "disconnected");
                root.primaryConnection = root.ethernetConnected ? "Ethernet" : root.currentWifiSSID;
            }
        }
    }
    Process {
        id: toggleProc
        onExited: { root.wifiToggling = false; root.refresh(); }
    }
}
