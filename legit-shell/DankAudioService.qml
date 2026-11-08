import QtQuick
import Quickshell.Services.Pipewire

// Adapted from DankMaterialShell's PipewireAudioBackend.qml (MIT).
// This is the part of DMS audio that does not depend on its Go daemon.
Item {
    id: root
    visible: false

    readonly property bool ready: Pipewire.ready
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool muted: sinkAudio ? Boolean(sinkAudio.muted) : false
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0

    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node; }
    function toggleMute() { if (sinkAudio) sinkAudio.muted = !sinkAudio.muted; }
    function setVolume(value) {
        if (!sinkAudio) return;
        sinkAudio.volume = Math.max(0, Math.min(1, value));
        if (value > 0 && sinkAudio.muted) sinkAudio.muted = false;
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio || !node.isStream)
    }
}
