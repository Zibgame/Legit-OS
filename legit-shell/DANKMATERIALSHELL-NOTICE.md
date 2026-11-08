# DankMaterialShell adaptation notice

The LEGIT Shell control center adapts service and interaction patterns from
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), without
starting or installing its shell UI.

The adapted parts are the Quickshell PipeWire object tracking and volume
control, BlueZ adapter/device state handling, NetworkManager state contract,
brightness-device availability model, toggle tiles and slider interactions.
They live in `DankAudioService.qml`, `DankBluetoothService.qml`,
`DankNetworkService.qml`, `DankBrightnessService.qml`, `ControlTile.qml` and
`ControlSlider.qml`.

The full DMS network manager, credential agent, enhanced Bluetooth pairing,
multi-backend brightness/DDC and gamma controls require the Go `dms` daemon
and its JSON socket. LEGIT Shell deliberately does not launch `dms run`, since
that command owns the shell lifecycle. The adapted services use the native
Quickshell providers where available and real system-command fallbacks for
the backend-only paths.

DankMaterialShell is Copyright (c) 2025 Avenge Media LLC and distributed under
the MIT License. Source and license:
https://github.com/AvengeMedia/DankMaterialShell
