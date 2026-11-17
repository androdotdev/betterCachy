import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    readonly property var p: backend.palette
    readonly property var checks: backend.checks
    function count(s) { let n = 0; for (const c of checks) if (c.status === s) n++; return n }

    PageHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Doctor"
        subtitle: "Checks tools, services, generated files, repo drift and package lists"
        Chip { text: count("ok") + " ok"; tone: "ok" }
        Chip { text: count("warn") + " warnings"; tone: "warn"; visible: count("warn") > 0 }
        Chip { text: count("fail") + " failing"; tone: "fail"; visible: count("fail") > 0 }
        Btn { text: "Run again"; kind: "primary"; onClicked: backend.runDoctor() }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 6
        model: checks
        ScrollBar.vertical: ScrollBar { }
        section.property: "group"
        section.delegate: Item {
            required property string section
            width: list.width
            height: 34
            Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: section.toUpperCase(); color: p.primary; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2 }
        }
        delegate: Rectangle {
            required property var modelData
            width: list.width - 8
            height: 50
            radius: 12
            color: p.surfaceContainerHigh
            Rectangle {
                id: dot
                width: 10
                height: 10
                radius: 5
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.status === "ok" ? "#8fd18a" : modelData.status === "warn" ? "#f0c36b" : p.error
            }
            Column {
                anchors.left: dot.right
                anchors.leftMargin: 14
                anchors.right: fixBtn.visible ? fixBtn.left : parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { width: parent.width; text: modelData.title; color: p.fg; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: modelData.detail; color: p.outline; font.pixelSize: 11; elide: Text.ElideRight; visible: text !== "" }
            }
            Btn {
                id: fixBtn
                visible: modelData.fix !== null && modelData.fix !== undefined
                text: visible ? modelData.fix.label : ""
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                onClicked: backend.applyFix(modelData.fix.id)
            }
        }
    }
}
