import QtQuick

Rectangle {
    readonly property var p: backend.palette
    default property alias content: inner.data
    property int padding: 16
    color: p.surfaceContainerHigh
    radius: 16
    border.color: Qt.alpha(p.outline, 0.25)
    border.width: 1
    implicitHeight: inner.implicitHeight + padding * 2

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.padding
        implicitHeight: childrenRect.height
    }
}
