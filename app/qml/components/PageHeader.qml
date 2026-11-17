import QtQuick

Item {
    readonly property var p: backend.palette
    property string title: ""
    property string subtitle: ""
    default property alias actions: row.data
    implicitHeight: 56

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { text: title; color: p.fg; font.pixelSize: 26; font.bold: true }
        Text { text: subtitle; color: p.outline; font.pixelSize: 12; visible: subtitle !== "" }
    }
    Row {
        id: row
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
