import qs
import QtQuick

// Placeholder rows shown while a list is loading.
Column {
    id: root
    property int rows: 8
    property real pulse: 0.35
    spacing: 2

    SequentialAnimation on pulse {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { to: 0.7; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutSine }
    }

    Repeater {
        model: root.rows
        delegate: Item {
            required property int index
            width: root.width
            height: 54
            Rectangle {
                x: 38
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 6
                color: Colors.outline
                opacity: root.pulse * 0.6
            }
            Rectangle {
                x: 90
                y: 12
                width: Math.max(80, (parent.width - 180) * (0.45 + ((index * 37) % 40) / 100))
                height: 11
                radius: 5
                color: Colors.outline
                opacity: root.pulse
            }
            Rectangle {
                x: 90
                y: 30
                width: Math.max(60, (parent.width - 180) * (0.25 + ((index * 53) % 25) / 100))
                height: 9
                radius: 4
                color: Colors.outline
                opacity: root.pulse * 0.7
            }
        }
    }
}
