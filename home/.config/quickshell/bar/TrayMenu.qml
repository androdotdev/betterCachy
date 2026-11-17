import qs
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Right-click menu for a system tray icon: Open, the app's own menu (Quit and
// friends, with submenus) and a fallback to close its windows.
PopupWindow {
    id: popup

    property var trayItem
    property var anchorItem
    property bool open: false
    property var stack: []
    signal dismissed()

    readonly property var currentMenu: stack.length > 0 ? stack[stack.length - 1] : (trayItem && trayItem.hasMenu ? trayItem.menu : null)
    readonly property var appWindows: {
        if (!trayItem) return []
        const keys = [String(trayItem.id || ""), String(trayItem.title || "")]
            .map(function(k) { return k.toLowerCase() }).filter(function(k) { return k.length > 2 })
        const out = []
        for (const t of (ToplevelManager.toplevels.values || [])) {
            const app = String(t.appId || "").toLowerCase()
            if (app === "") continue
            for (const k of keys) {
                if (app === k || k.indexOf(app) >= 0 || app.indexOf(k) >= 0) { out.push(t); break }
            }
        }
        return out
    }

    onOpenChanged: if (!open) stack = []

    visible: open || body.opacity > 0.01
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    implicitWidth: 250
    implicitHeight: 14 + 46 + (stack.length > 0 ? 32 : 0) + Math.max(34, Math.min(entries.contentHeight, 340))
        + (appWindows.length > 0 ? 38 : 0)
    color: "transparent"

    HyprlandFocusGrab {
        active: popup.open
        windows: [popup]
        onCleared: popup.dismissed()
    }

    QsMenuOpener {
        id: opener
        menu: popup.currentMenu
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Colors.surfaceContainer, 0.98)
        border.color: Qt.alpha(Colors.outline, 0.4)
        border.width: 1
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.96
        transformOrigin: Item.Top
        focus: true
        Keys.onEscapePressed: popup.dismissed()
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        Item {
            id: head
            x: 6
            y: 6
            width: parent.width - 12
            height: 46
            IconImage {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: popup.trayItem ? popup.trayItem.icon : ""
            }
            Text {
                anchors.left: appIcon.right
                anchors.leftMargin: 10
                anchors.right: openButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: popup.trayItem ? (popup.trayItem.tooltipTitle || popup.trayItem.title || popup.trayItem.id) : ""
                color: Colors.fg
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                id: openButton
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 58
                height: 28
                radius: 14
                color: openArea.containsMouse ? Qt.lighter(Colors.primary, 1.12) : Colors.primary
                Text { anchors.centerIn: parent; text: "Open"; color: Colors.fgPrimary; font.pixelSize: 11; font.bold: true }
                MouseArea {
                    id: openArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (popup.trayItem) popup.trayItem.activate(); popup.dismissed() }
                }
            }
        }

        Rectangle {
            id: backRow
            visible: popup.stack.length > 0
            x: 6
            y: head.y + head.height
            width: parent.width - 12
            height: 32
            radius: 8
            color: backArea.containsMouse ? Qt.alpha(Colors.primary, 0.2) : "transparent"
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "‹  Back"; color: Colors.primary; font.pixelSize: 12 }
            MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: popup.stack = popup.stack.slice(0, popup.stack.length - 1) }
        }

        ListView {
            id: entries
            x: 6
            y: head.y + head.height + (backRow.visible ? 32 : 0)
            width: parent.width - 12
            height: Math.max(34, Math.min(contentHeight, 340))
            clip: true
            model: opener.children
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: entry
                required property var modelData
                width: entries.width
                height: modelData.isSeparator ? 9 : 32

                Rectangle {
                    visible: entry.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    width: parent.width - 12
                    height: 1
                    color: Qt.alpha(Colors.outline, 0.35)
                }
                Rectangle {
                    visible: !entry.modelData.isSeparator
                    anchors.fill: parent
                    radius: 8
                    opacity: entry.modelData.enabled ? 1 : 0.4
                    color: rowArea.containsMouse && entry.modelData.enabled ? Qt.alpha(Colors.primary, 0.2) : "transparent"
                    Text {
                        id: mark
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        text: entry.modelData.buttonType === QsMenuButtonType.RadioButton
                            ? (entry.modelData.checkState === Qt.Checked ? "●" : "")
                            : (entry.modelData.buttonType === QsMenuButtonType.CheckBox && entry.modelData.checkState === Qt.Checked ? "✓" : "")
                        color: Colors.primary
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.left: mark.right
                        anchors.leftMargin: 6
                        anchors.right: chevron.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.text
                        color: Colors.fg
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        id: chevron
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.hasChildren ? "›" : ""
                        color: Colors.outline
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!entry.modelData.enabled) return
                            if (entry.modelData.hasChildren) popup.stack = popup.stack.concat([entry.modelData])
                            else { entry.modelData.triggered(); popup.dismissed() }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: entries.count === 0
                text: popup.trayItem && popup.trayItem.hasMenu ? "Menu is empty" : "This app has no menu"
                color: Colors.outline
                font.pixelSize: 11
            }
        }

        Rectangle {
            visible: popup.appWindows.length > 0
            x: 6
            y: parent.height - 38
            width: parent.width - 12
            height: 32
            radius: 8
            color: closeArea.containsMouse ? Qt.alpha(Colors.error, 0.25) : Qt.alpha(Colors.error, 0.12)
            Text {
                anchors.centerIn: parent
                text: "Close " + popup.appWindows.length + (popup.appWindows.length === 1 ? " window" : " windows")
                color: Colors.error
                font.pixelSize: 11
                font.bold: true
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    for (const t of popup.appWindows) t.close()
                    popup.dismissed()
                }
            }
        }
    }
}
