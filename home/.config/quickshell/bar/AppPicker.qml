import qs
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

// Application list for the dock: search, launch, pin and unpin.
PopupWindow {
    id: popup

    property var anchorItem
    property bool open: false
    signal dismissed()

    readonly property var matches: {
        const q = search.text.trim().toLowerCase()
        const out = []
        for (const e of (DesktopEntries.applications.values || [])) {
            if (e.noDisplay) continue
            if (q === "" || String(e.name).toLowerCase().indexOf(q) >= 0 || String(e.genericName || "").toLowerCase().indexOf(q) >= 0) out.push(e)
        }
        out.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
        return out
    }

    function entryKey(e) { return String(e.id).replace(/\.desktop$/, "") }
    function iconFor(e) {
        const name = String(e.icon || "")
        if (name.indexOf("/") === 0) return "file://" + name
        return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable")
    }

    onOpenChanged: if (open) { search.text = ""; Qt.callLater(function() { search.forceActiveFocus() }) }

    visible: open || body.opacity > 0.01
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    implicitWidth: 340
    implicitHeight: 440
    color: "transparent"

    HyprlandFocusGrab {
        active: popup.open
        windows: [popup]
        onCleared: popup.dismissed()
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Colors.surfaceContainer, 0.98)
        border.color: Qt.alpha(Colors.outline, 0.4)
        border.width: 1
        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.96
        transformOrigin: Item.Bottom
        focus: true
        Keys.onEscapePressed: popup.dismissed()
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            id: searchBox
            x: 14
            y: 14
            width: parent.width - 28
            height: 36
            radius: 18
            color: Colors.surfaceContainerHigh
            border.color: search.activeFocus ? Colors.primary : Qt.alpha(Colors.outline, 0.35)
            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.fg
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onAccepted: if (popup.matches.length > 0) { popup.matches[0].execute(); popup.dismissed() }
                Text { visible: search.text === ""; text: "Search applications"; color: Colors.outline; font: search.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        ListView {
            id: list
            anchors.top: searchBox.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            clip: true
            spacing: 2
            model: popup.matches
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool pinned: (BarDatabase.dockPinned || []).indexOf(popup.entryKey(modelData)) >= 0
                width: list.width
                height: 44
                radius: 10
                color: rowArea.containsMouse ? Qt.alpha(Colors.primary, 0.16) : "transparent"
                IconImage {
                    id: rowIcon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 28
                    source: popup.iconFor(row.modelData)
                }
                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.right: pinButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: Colors.fg
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { row.modelData.execute(); popup.dismissed() }
                }
                Rectangle {
                    id: pinButton
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    height: 26
                    radius: 13
                    color: row.pinned ? Qt.alpha(Colors.primary, 0.3) : Qt.alpha(Colors.outline, 0.18)
                    Text { anchors.centerIn: parent; text: row.pinned ? "Pinned" : "Pin"; color: row.pinned ? Colors.primary : Colors.fgDim; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const key = popup.entryKey(row.modelData)
                            if (row.pinned) BarDatabase.unpinApp(key); else BarDatabase.pinApp(key)
                        }
                    }
                }
            }
        }
    }
}
