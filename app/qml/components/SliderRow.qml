import QtQuick
import QtQuick.Controls.Basic

Item {
    id: row
    readonly property var p: backend.palette
    property string label: ""
    property alias from: slider.from
    property alias to: slider.to
    property real value: 0
    signal moved(real value)
    implicitHeight: 34

    Text { text: row.label; color: p.fgDim; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; width: 100 }
    Slider {
        id: slider
        anchors.left: parent.left
        anchors.leftMargin: 104
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.verticalCenter: parent.verticalCenter
        stepSize: 1
        snapMode: Slider.SnapAlways
        value: row.value
        onMoved: row.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Qt.alpha(row.p.outline, 0.35)
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: row.p.primary }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 14 : 10
            height: width
            radius: width / 2
            color: row.p.primary
        }
    }
    Text { text: Math.round(slider.value); color: p.fg; font.pixelSize: 12; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
}
