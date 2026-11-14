import qs
import Quickshell
import QtQuick
import QtQuick.Controls

Scope {
    id: root
    property bool open: false
    property bool doNotDisturb: false
    property var notifications: []
    property var anchorItem
    signal opened()
    signal doNotDisturbToggled()
    signal popupEntered()
    signal popupLeft()

    onOpenChanged: if (open) opened()

    PopupWindow {
        visible: root.open
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: 310
        implicitHeight: 300
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
                anchors.margins: 12
                spacing: 8
                Row {
                    width: parent.width
                    height: 30
                    Text {
                        text: "Notifications"
                        color: Colors.fg
                        font.bold: true
                        font.pixelSize: 14
                        width: parent.width - dndButton.width - 8
                        verticalAlignment: Text.AlignVCenter
                    }
                    Rectangle {
                        id: dndButton
                        width: 74
                        height: 26
                        radius: 8
                        color: root.doNotDisturb ? "#594456" : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: root.doNotDisturb ? "DND  On" : "DND  Off"
                            color: root.doNotDisturb ? Colors.error : Colors.fgDim
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.doNotDisturbToggled()
                        }
                    }
                }
                ListView {
                    width: parent.width
                    height: parent.height - 30
                    model: root.notifications
                    clip: true
                    spacing: 6
                    header: Text {
                        visible: root.notifications.length === 0
                        text: "You’re all caught up."
                        color: Colors.outline
                        width: ListView.view.width
                        height: visible ? 28 : 0
                        verticalAlignment: Text.AlignVCenter
                    }
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: Math.max(74, cardContent.implicitHeight + 18)
                        radius: 7
                        color: Colors.surfaceContainer
                        Column {
                            id: cardContent
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 4
                            Text { text: modelData.appName; color: Colors.primary; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                            Text { text: modelData.summary || "Notification"; color: Colors.fg; font.bold: true; wrapMode: Text.Wrap; width: parent.width }
                            Text { text: modelData.body || ""; color: Colors.fgDim; wrapMode: Text.Wrap; width: parent.width; maximumLineCount: 3; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
