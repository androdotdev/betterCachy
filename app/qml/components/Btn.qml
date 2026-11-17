import QtQuick

// kind: primary | tonal | danger | ghost
Rectangle {
    id: btn
    readonly property var p: backend.palette
    property string text: ""
    property string kind: "tonal"
    property bool busy: false
    signal clicked()

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 34
    radius: 17
    opacity: enabled ? 1 : 0.45
    color: {
        const hover = area.containsMouse && enabled
        if (kind === "primary") return hover ? Qt.lighter(p.primary, 1.12) : p.primary
        if (kind === "danger") return Qt.alpha(p.error, hover ? 0.32 : 0.18)
        if (kind === "ghost") return hover ? Qt.alpha(p.outline, 0.18) : "transparent"
        return Qt.alpha(p.primary, hover ? 0.3 : 0.18)
    }
    border.color: kind === "ghost" ? Qt.alpha(p.outline, 0.45) : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        font.pixelSize: 12
        font.bold: true
        color: btn.kind === "primary" ? btn.p.fgPrimary : btn.kind === "danger" ? btn.p.error : btn.kind === "ghost" ? btn.p.fgDim : btn.p.primary
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (btn.enabled) btn.clicked()
    }
}
