import qs
import QtQuick
import QtQuick.Controls

Item {
    id: iconButton
    property string glyph: ""
    property color tint: Colors.primary
    property int size: 18
    signal clicked()
    width: size + 12
    height: size + 12
    Text {
        anchors.centerIn: parent
        text: iconButton.glyph
        color: iconButton.tint
        font.pixelSize: iconButton.size
        opacity: iconArea.containsMouse ? 1 : 0.85
    }
    MouseArea {
        id: iconArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconButton.clicked()
    }
}
