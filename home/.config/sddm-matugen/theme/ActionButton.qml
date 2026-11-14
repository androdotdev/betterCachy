import QtQuick 2.15

Rectangle {
    id: button

    property string label: "Continue"
    property color baseColor: "#ffb59b"
    property color labelColor: "#55200a"
    property bool available: true

    signal clicked()

    implicitHeight: 52
    radius: 14
    opacity: available ? 1 : 0.55
    color: !available
        ? baseColor
        : (pressed.containsPress
            ? Qt.darker(baseColor, 1.12)
            : (pressed.containsMouse ? Qt.lighter(baseColor, 1.10) : baseColor))

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: button.label
        color: button.labelColor
        font.family: "Noto Sans"
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: pressed
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (button.available) button.clicked()
    }
}
