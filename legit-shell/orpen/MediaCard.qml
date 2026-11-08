

import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    height: 90; radius: 16
    color: pill ? pill.t_card : "#1a2420"
    clip: true   

    required property var activePlayer
    property var pill

    
    
    property real playerPosition: root.activePlayer ? root.activePlayer.position : 0
    property real playerLength:   root.activePlayer ? root.activePlayer.length   : 0

    Timer {
        interval: 500
        running: root.activePlayer !== null &&
                 root.activePlayer.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.playerPosition = root.activePlayer ? root.activePlayer.position : 0
    }

    
    Text {
        anchors.centerIn: parent
        text: "No media playing"
        color: pill ? pill.t_textSub : "#555555"; font.pointSize: 9
        font.family: "JetBrainsMono Nerd Font Mono"
        visible: root.activePlayer === null
    }

    Item {
        anchors.fill: parent
        visible: root.activePlayer !== null

        
        Item {
            id: artWrapper
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 66; height: 66

            Image {
                id: artImage
                anchors.fill: parent
                source: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artMask
                }
            }

            Rectangle {
                anchors.fill: parent; radius: 12
                color: pill ? pill.t_bg : "#0d1a16"
                visible: artImage.status !== Image.Ready
                Text {
                    anchors.centerIn: parent; text: "󰎇"
                    color: pill ? pill.t_accent : "#3dffc0"; font.pointSize: 22
                    font.family: "JetBrainsMono Nerd Font Mono"
                }
            }

            Rectangle {
                id: artMask
                anchors.fill: parent; radius: 12
                visible: false; layer.enabled: true
            }
        }

        
        Column {
            anchors.left: artWrapper.right; anchors.leftMargin: 12
            anchors.right: controls.left;  anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: root.activePlayer ? (root.activePlayer.trackTitle  || "Unknown Title")  : ""
                color: pill ? pill.t_text : "#ffffff"; font.pointSize: 10; font.bold: true
                font.family: "JetBrainsMono Nerd Font Mono"
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
                color: pill ? pill.t_textSub : "#aaaaaa"; font.pointSize: 8
                font.family: "JetBrainsMono Nerd Font Mono"
                elide: Text.ElideRight; width: parent.width
            }
            Row {
                spacing: 4
                Text {
                    text: root.activePlayer ? (root.activePlayer.identity || "") : ""
                    color: pill ? pill.t_accent : "#3dffc0"; font.pointSize: 7; opacity: 0.7
                    font.family: "JetBrainsMono Nerd Font Mono"
                }

                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 4
                        Rectangle {
                            property real targetHeight: 3
                            width: 3
                            height: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? targetHeight : 3
                            radius: 1.5
                            color: pill ? pill.t_accent : "#3dffc0"
                            opacity: 0.8
                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                            Timer {
                                interval: 150 + Math.random() * 100
                                running: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
                                repeat: true
                                onTriggered: parent.targetHeight = 3 + Math.random() * 8
                            }
                        }
                    }
                }
            }
        }

        
        Row {
            id: controls
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            
            Rectangle {
                width: 30; height: 30; radius: 15; color: pill ? pill.t_bg : "#0d1a16"
                Text { anchors.centerIn: parent; text: "󰒮"; color: pill ? pill.t_text : "#ffffff"; font.pointSize: 11; font.family: "JetBrainsMono Nerd Font Mono" }
                MouseArea { anchors.fill: parent; onClicked: { if (root.activePlayer) root.activePlayer.previous() } }
            }

            
            Rectangle {
                width: 36; height: 36; radius: 18; color: pill ? pill.t_text : "#ffffff"
                Text {
                    anchors.centerIn: parent
                    text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing)
                          ? "󰏤" : "󰐊"
                    color: pill ? pill.t_card : "#050e0f"; font.pointSize: 13
                    font.family: "JetBrainsMono Nerd Font Mono"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!root.activePlayer) return
                        if (root.activePlayer.playbackState === MprisPlaybackState.Playing)
                            root.activePlayer.pause()
                        else
                            root.activePlayer.play()
                    }
                }
            }

            
            Rectangle {
                width: 30; height: 30; radius: 15; color: pill ? pill.t_bg : "#0d1a16"
                Text { anchors.centerIn: parent; text: "󰒭"; color: pill ? pill.t_text : "#ffffff"; font.pointSize: 11; font.family: "JetBrainsMono Nerd Font Mono" }
                MouseArea { anchors.fill: parent; onClicked: { if (root.activePlayer) root.activePlayer.next() } }
            }
        }
    }
    
    
    Item {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 12
        visible: root.activePlayer !== null && root.playerLength > 0

        
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 3
            color: pill ? pill.t_bg : "#0a1812"

            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                height: 3
                width: root.playerLength > 0
                       ? parent.parent.width * Math.min(1.0, root.playerPosition / root.playerLength)
                       : 0
                color: pill ? pill.t_accent : "#3dffc0"
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
            }
        }

        
        Process {
            id: seekProc
            property real target: 0
            command: ["playerctl", "position", target.toString()]
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function doSeek(xPos) {
                if (!root.activePlayer || root.playerLength <= 0) return
                var fraction = Math.max(0, Math.min(1, xPos / width))
                var newPos = fraction * root.playerLength
                
                
                root.playerPosition = newPos
                
                
                
                try { root.activePlayer.position = newPos } catch(e) {}
                
                
                seekProc.target = newPos
                seekProc.running = true
            }

            onClicked: (mouse) => doSeek(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) doSeek(mouse.x) }
        }
    }
}


