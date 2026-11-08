

import QtQuick


Rectangle {
    id: root
    height: 36; radius: 18
    color: pill ? pill.t_card : "#1a2420"
    Behavior on color { ColorAnimation { duration: 180 } }

    
    property var pill
    property real  value:    0.5     
    property string icon:    "󰕾"    
    signal sliderMoved(real newValue)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:  parent.left;  anchors.leftMargin:  14
        anchors.right: parent.right; anchors.rightMargin: 14
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: pill ? pill.t_accent : "#3dffc0"
            font.pointSize: 11
            font.family: "JetBrainsMono Nerd Font Mono"
        }

        Item {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40; height: 20

            
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: pill ? pill.t_bg : "#0d1a16"

                
                Rectangle {
                    width: parent.width * root.value
                    height: parent.height; radius: 2; color: pill ? pill.t_accent : "#3dffc0"
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            
            Rectangle {
                x: (track.width * root.value) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7; color: pill ? pill.t_text : "#ffffff"
                Behavior on x { NumberAnimation { duration: 80 } }
            }

            MouseArea {
                anchors.fill: parent
                function updateValue(mouseX) {
                    var v = Math.max(0, Math.min(1, mouseX / width))
                    root.sliderMoved(v)
                }
                onClicked:         (mouse) => updateValue(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) updateValue(mouse.x) }
            }
        }
    }
}


