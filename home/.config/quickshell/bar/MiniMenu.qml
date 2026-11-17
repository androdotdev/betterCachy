import qs
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Small context menu. items: [{ id, text, glyph, danger, enabled, separator, header }]
PopupWindow {
    id: menu

    property var anchorItem
    property var items: []
    property bool open: false
    property bool above: false
    property int menuWidth: 230
    readonly property int rowHeight: 32
    signal picked(string id)
    signal dismissed()

    function close() { dismissed() }

    readonly property int contentHeight: {
        let h = 12
        for (const item of items) h += item.separator ? 9 : (item.header ? 30 : rowHeight)
        return h
    }

    visible: open || body.opacity > 0.01
    anchor.item: anchorItem
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    implicitWidth: menuWidth
    implicitHeight: contentHeight
    color: "transparent"

    HyprlandFocusGrab {
        active: menu.open
        windows: [menu]
        onCleared: menu.dismissed()
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Colors.surfaceContainer, 0.97)
        border.color: Qt.alpha(Colors.outline, 0.4)
        border.width: 1
        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.96
        transformOrigin: menu.above ? Item.Bottom : Item.Top
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Keys.onEscapePressed: menu.dismissed()
        focus: true

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            Repeater {
                model: menu.items
                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: modelData.separator ? 9 : (modelData.header ? 30 : menu.rowHeight)

                    Rectangle {
                        visible: modelData.separator === true
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 12
                        x: 6
                        height: 1
                        color: Qt.alpha(Colors.outline, 0.35)
                    }
                    Text {
                        visible: modelData.header === true
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.text || ""
                        color: Colors.primary
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: !modelData.separator && !modelData.header
                        anchors.fill: parent
                        radius: 8
                        opacity: modelData.enabled === false ? 0.4 : 1
                        color: rowArea.containsMouse && modelData.enabled !== false
                            ? Qt.alpha(modelData.danger ? Colors.error : Colors.primary, 0.2) : "transparent"
                        Text {
                            id: glyphText
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            text: modelData.glyph || ""
                            color: modelData.danger ? Colors.error : Colors.primary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.left: glyphText.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text || ""
                            color: modelData.danger ? Colors.error : Colors.fg
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.enabled === false ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (modelData.enabled !== false) menu.picked(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
