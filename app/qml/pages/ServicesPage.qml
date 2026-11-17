import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: page
    readonly property var p: backend.palette
    property string logFor: ""

    PageHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Services"
        subtitle: "systemd user services from the repo. Restart after changing config."
        Btn { text: "Refresh"; onClicked: backend.refreshServices() }
    }

    Column {
        id: cards
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: backend.serviceList
            delegate: Rectangle {
                required property var modelData
                width: cards.width
                height: 58
                radius: 14
                color: p.surfaceContainerHigh
                border.color: page.logFor === modelData.name ? Qt.alpha(p.primary, 0.6) : "transparent"
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text { text: modelData.name; color: p.fg; font.pixelSize: 14; font.bold: true }
                    Text { text: modelData.enabled; color: p.outline; font.pixelSize: 11 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Chip { anchors.verticalCenter: parent.verticalCenter; text: modelData.active; tone: modelData.active === "active" ? "ok" : modelData.active === "failed" ? "fail" : "warn" }
                    Btn { text: modelData.active === "active" ? "Restart" : "Start"; onClicked: backend.serviceAction(modelData.name, modelData.active === "active" ? "restart" : "start") }
                    Btn { text: "Stop"; kind: "danger"; visible: modelData.active === "active"; onClicked: backend.serviceAction(modelData.name, "stop") }
                    Btn { text: "Logs"; kind: "ghost"; onClicked: { page.logFor = modelData.name; backend.loadLogs(modelData.name) } }
                }
            }
        }
    }

    Rectangle {
        anchors.top: cards.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: 14
        color: p.surfaceContainer
        border.color: Qt.alpha(p.outline, 0.25)
        visible: page.logFor !== ""

        Text {
            id: logTitle
            x: 16
            y: 10
            text: "Logs · " + page.logFor
            color: p.primary
            font.pixelSize: 12
            font.bold: true
        }
        Flickable {
            anchors.top: logTitle.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            clip: true
            contentHeight: logText.implicitHeight
            contentWidth: width
            ScrollBar.vertical: ScrollBar { }
            Text {
                id: logText
                width: parent.width
                text: backend.serviceLog
                color: p.fgDim
                font.family: "monospace"
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: page.logFor === ""
        text: "Pick Logs on a service to read its journal"
        color: p.outline
        font.pixelSize: 12
        bottomPadding: 10
    }
}
