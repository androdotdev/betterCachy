import QtQuick

// tone: ok | warn | fail | info
Rectangle {
    readonly property var p: backend.palette
    property string text: ""
    property string tone: "info"
    readonly property color tint: tone === "ok" ? "#8fd18a" : tone === "warn" ? "#f0c36b" : tone === "fail" ? p.error : p.primary
    implicitWidth: t.implicitWidth + 20
    implicitHeight: 24
    radius: 12
    color: Qt.alpha(tint, 0.18)
    Text { id: t; anchors.centerIn: parent; text: parent.text; color: parent.tint; font.pixelSize: 11; font.bold: true }
}
