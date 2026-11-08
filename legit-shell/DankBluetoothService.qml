import QtQuick
import Quickshell.Bluetooth

// DMS BluetoothService subset adapted for LEGIT Shell (MIT). Basic power,
// discovery state and trusted-device connections use Quickshell/BlueZ directly.
// Passkey pairing and codec switching remain backend-only DMS capabilities.
Item {
    id: root
    visible: false

    readonly property var adapters: Bluetooth.adapters ? Bluetooth.adapters.values : []
    readonly property var adapter: Bluetooth.defaultAdapter || null
    readonly property bool available: adapter !== null
    readonly property bool enabled: available ? Boolean(adapter.enabled) : false
    readonly property bool discovering: available ? Boolean(adapter.discovering) : false
    readonly property var devices: available && adapter.devices ? adapter.devices.values : []
    readonly property var connectedDevices: devices.filter(device => device && device.connected)
    readonly property bool connected: connectedDevices.length > 0
    readonly property bool connecting: devices.some(device => device && device.state === BluetoothDeviceState.Connecting)
    readonly property string primaryDeviceName: connected ? (connectedDevices[0].name || connectedDevices[0].alias || "Appareil connecté") : ""

    function setEnabled(value) { if (adapter) adapter.enabled = value; }
    function toggle() { setEnabled(!enabled); }
    function connectTrusted(device) {
        if (!device) return;
        device.trusted = true;
        device.connect();
    }
    function disconnect(device) { if (device) device.disconnect(); }
}
