import QtQuick
import QtQuick.Effects

// Image with rounded corners (Rectangle clip cannot round an Image).
Item {
    id: root
    property url source
    property real radius: 18
    readonly property bool ready: img.status === Image.Ready

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: false
    }
    Item {
        id: mask
        width: root.width
        height: root.height
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle { width: mask.width; height: mask.height; radius: root.radius }
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: mask
        visible: img.status === Image.Ready
    }
}
