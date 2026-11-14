import QtQuick
import QtQuick.Effects

// Blurred album art wash behind the player card.
Item {
    id: root
    property url source
    property real radius: 20

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 160
        sourceSize.height: 160
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
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        saturation: 0.25
        maskEnabled: true
        maskSource: mask
        opacity: img.status === Image.Ready ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }
}
