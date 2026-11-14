import qs
import QtQuick
import QtQuick.Controls

Slider {
    id: control
    implicitHeight: 20
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Qt.alpha(Colors.outline, 0.35)
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: Colors.primary
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.pressed || control.hovered ? 12 : 8
        height: width
        radius: width / 2
        color: Colors.primary
        Behavior on width { NumberAnimation { duration: 90 } }
    }
}
