import qs
import Quickshell
import QtQuick
import QtQuick.Controls

Scope {
    id: root
    property bool open: false
    property var anchorItem
    signal popupEntered()
    signal popupLeft()

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var cells: buildCells(viewYear, viewMonth)

    function buildCells(year, month) {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7 // Monday-first
        const days = new Date(year, month + 1, 0).getDate()
        const result = []
        for (let i = 0; i < offset; i++) result.push(0)
        for (let d = 1; d <= days; d++) result.push(d)
        while (result.length % 7 !== 0) result.push(0)
        while (result.length < 42) result.push(0)
        return result
    }

    function shiftMonth(delta) {
        let month = viewMonth + delta
        let year = viewYear
        if (month < 0) { month = 11; year -= 1 }
        else if (month > 11) { month = 0; year += 1 }
        viewMonth = month
        viewYear = year
    }

    function isToday(day) {
        if (day <= 0) return false
        const now = new Date()
        return day === now.getDate() && viewMonth === now.getMonth() && viewYear === now.getFullYear()
    }

    onOpenChanged: {
        if (!open) return
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    PopupWindow {
        visible: root.open
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: 292
        implicitHeight: 322
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.surfaceContainer
            border.color: Qt.alpha(Colors.outline, 0.4)
            border.width: 1

            HoverHandler {
                onHoveredChanged: hovered ? root.popupEntered() : root.popupLeft()
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Row {
                    width: parent.width
                    height: 26

                    Text {
                        width: 26
                        height: 26
                        text: "‹"
                        color: arrowLeft.containsMouse ? Colors.primary : Colors.fgDim
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            id: arrowLeft
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    Text {
                        width: parent.width - 52
                        height: 26
                        text: Qt.formatDateTime(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                        color: Colors.fg
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: 26
                        height: 26
                        text: "›"
                        color: arrowRight.containsMouse ? Colors.primary : Colors.fgDim
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            id: arrowRight
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                Row {
                    width: parent.width
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text {
                            required property string modelData
                            width: 36
                            text: modelData
                            color: Colors.outline
                            font.pixelSize: 10
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    columns: 7
                    Repeater {
                        model: root.cells
                        delegate: Rectangle {
                            required property var modelData
                            width: 36
                            height: 30
                            radius: 7
                            color: root.isToday(modelData) ? Colors.primary : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                color: root.isToday(modelData) ? Colors.fgPrimary : Colors.fg
                                font.pixelSize: 11
                                font.bold: root.isToday(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
