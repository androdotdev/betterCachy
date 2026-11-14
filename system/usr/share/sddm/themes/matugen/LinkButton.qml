import QtQuick 2.15

Text {
    id: link

    property color hoverColor: "#ffb59b"
    property color baseColor: "#d8c2bb"

    signal clicked()

    color: hover.containsMouse ? hoverColor : baseColor
    font.family: "Noto Sans"
    font.pixelSize: 14
    opacity: 0.9

    Behavior on color { ColorAnimation { duration: 110 } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: link.clicked()
    }
}
