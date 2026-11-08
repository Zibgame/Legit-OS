import QtQuick
import Quickshell
import Quickshell.Wayland

// LEGIT Shell calendar panel (Noctalia-style): the real system date, a month
// grid with today highlighted, previous/next month navigation. No fake data.
PanelWindow {
    id: panel

    property var state

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "legit-cal-panel"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Keys.onEscapePressed: panel.state.closePopups()

    readonly property color accent: "#4bb3e4"
    readonly property color textColor: "#e8e8e8"
    readonly property color subtext: "#a0a0a0"

    // Displayed month state.
    property date shownMonth: new Date()
    readonly property var monthNames: ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
                                       "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
    readonly property var dayNames: ["L", "M", "M", "J", "V", "S", "D"]

    readonly property int shownYear: shownMonth.getFullYear()
    readonly property int shownMonthIdx: shownMonth.getMonth()

    // Grid cells: leading blanks then 1..N (Monday-first week).
    readonly property var cells: {
        var first = new Date(shownYear, shownMonthIdx, 1);
        var lead = (first.getDay() + 6) % 7; // Monday = 0
        var count = new Date(shownYear, shownMonthIdx + 1, 0).getDate();
        var out = [];
        for (var i = 0; i < lead; i++) out.push(null);
        for (var d = 1; d <= count; d++) out.push(d);
        return out;
    }

    readonly property int todayYear: new Date().getFullYear()
    readonly property int todayMonth: new Date().getMonth()
    readonly property int todayDate: new Date().getDate()

    function shiftMonth(delta) {
        var d = new Date(shownYear, shownMonthIdx + delta, 1);
        shownMonth = d;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.state.closePopups()
    }

    Rectangle {
        width: 330
        height: 350
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 8
            bottomMargin: 52
        }
        color: "#b31a1d24"
        radius: 12
        border.color: "#18ffffff"
        border.width: 1

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Header: month + navigation.
            Item {
                width: parent.width
                height: 30

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevMa.containsMouse ? "#44222730" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: panel.textColor
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.shiftMonth(-1)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: panel.monthNames[panel.shownMonthIdx] + " " + panel.shownYear
                    color: panel.textColor
                    font.pixelSize: 13
                    font.bold: true
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextMa.containsMouse ? "#44222730" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: panel.textColor
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.shiftMonth(1)
                    }
                }
            }

            // Weekday header (Monday-first).
            Grid {
                width: parent.width
                columns: 7
                spacing: 0

                Repeater {
                    model: panel.dayNames

                    Item {
                        required property string modelData
                        width: (parent.width) / 7
                        height: 24

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: panel.subtext
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            // Day grid.
            Grid {
                width: parent.width
                columns: 7
                spacing: 0

                Repeater {
                    model: panel.cells

                    Item {
                        required property var modelData
                        width: (parent.width) / 7
                        height: 38

                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: 16
                            visible: modelData !== null
                            color: (modelData === panel.todayDate
                                    && panel.shownMonthIdx === panel.todayMonth
                                    && panel.shownYear === panel.todayYear)
                                   ? panel.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData === null ? "" : modelData
                                color: (modelData === panel.todayDate
                                        && panel.shownMonthIdx === panel.todayMonth
                                        && panel.shownYear === panel.todayYear)
                                       ? "#12141d" : panel.textColor
                                font.pixelSize: 12
                                font.bold: modelData === panel.todayDate
                            }
                        }
                    }
                }
            }

            Text {
                text: Qt.formatDateTime(new Date(), "dddd d MMMM yyyy").replace(/^./, function (c) { return c.toUpperCase(); })
                color: panel.subtext
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
