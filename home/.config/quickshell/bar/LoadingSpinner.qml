import qs
import QtQuick

Item {
    id: root
    property color color: Colors.primary
    property real dotSize: 5
    property int speed: 900
    implicitWidth: 18
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(Colors.outline, 0.4)
    }

    Item {
        anchors.fill: parent
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: root.speed
            loops: Animation.Infinite
            running: root.visible
            easing.type: Easing.Linear
        }

        Rectangle {
            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: root.color
            x: parent.width / 2 - width / 2
            y: 0
        }
    }
}
