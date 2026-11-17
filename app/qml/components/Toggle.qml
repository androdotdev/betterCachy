import QtQuick

Item {
    id: tg
    readonly property var p: backend.palette
    property string label: ""
    property bool checked: false
    signal toggled(bool checked)
    implicitHeight: 34

    Text { text: tg.label; color: p.fgDim; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 22
        radius: 11
        color: tg.checked ? tg.p.primary : Qt.alpha(tg.p.outline, 0.35)
        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: tg.checked ? 21 : 3
            color: tg.checked ? tg.p.fgPrimary : tg.p.fgDim
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { tg.checked = !tg.checked; tg.toggled(tg.checked) }
        }
    }
}
