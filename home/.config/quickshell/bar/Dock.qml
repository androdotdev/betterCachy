import qs
import Quickshell
import Quickshell.Wayland
import QtQuick

// Floating dock at the bottom edge. Auto-hides when database dock.autoHide is true.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: Config.dock && BarDatabase.dockEnabled
            anchors { bottom: true }
            implicitWidth: Math.max(shell.width + 60, 320)
            implicitHeight: content.implicitHeight + 90
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            mask: Region { item: shell }
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-dock"
            WlrLayershell.keyboardFocus: content.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            property bool revealed: !BarDatabase.dockAutoHide
            readonly property int peek: 6

            Timer {
                id: hideTimer
                interval: 450
                onTriggered: if (!content.menuOpen) win.revealed = false
            }

            Connections {
                target: BarDatabase
                function onDockAutoHideChanged() { if (!BarDatabase.dockAutoHide) win.revealed = true }
            }

            Rectangle {
                id: shell
                width: content.implicitWidth + 28
                height: content.implicitHeight + 14
                radius: 22
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.revealed ? win.height - height - 10 : win.height - win.peek
                color: Qt.alpha(Colors.surface, 0.78)
                border.color: Qt.alpha(Colors.outline, 0.35)
                border.width: 1
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) { hideTimer.stop(); win.revealed = true }
                        else if (BarDatabase.dockAutoHide) hideTimer.restart()
                    }
                }

                DockContent {
                    id: content
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                }
            }
        }
    }
}
