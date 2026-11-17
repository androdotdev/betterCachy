import qs
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Pinned and running apps. Pinned apps live in database.json (dock.pinned).
Item {
    id: dock

    readonly property bool menuOpen: menu.open || picker.open
    readonly property int iconSize: BarDatabase.dockIconSize
    readonly property var windows: ToplevelManager.toplevels.values || []
    readonly property var apps: DesktopEntries.applications.values || []
    readonly property var items: build(windows, apps, BarDatabase.dockPinned || [])
    property var menuTarget: null

    implicitWidth: row.implicitWidth
    implicitHeight: iconSize + 20

    readonly property var seedCandidates: [
        "kitty", "foot", "alacritty", "firefox", "zen-browser", "chromium", "google-chrome", "brave-browser",
        "org.kde.dolphin", "thunar", "org.gnome.Nautilus", "nautilus", "code", "visual-studio-code",
        "spotify", "discord", "vesktop", "org.telegram.desktop", "obsidian"
    ]

    function entryKey(entry) { return String(entry.id).replace(/\.desktop$/, "") }

    function lookupEntry(id, apps) {
        const want = String(id).toLowerCase().replace(/\.desktop$/, "")
        for (const e of apps) {
            if (String(e.id).toLowerCase().replace(/\.desktop$/, "") === want) return e
        }
        for (const e of apps) {
            if (String(e.startupClass || "").toLowerCase() === want || String(e.name).toLowerCase() === want) return e
        }
        return null
    }

    function iconSource(name) {
        const n = String(name || "")
        if (n.indexOf("/") === 0) return "file://" + n
        if (n === "") return Quickshell.iconPath("application-x-executable")
        return Quickshell.iconPath(n, true) || Quickshell.iconPath("application-x-executable")
    }

    function build(windows, apps, pinned) {
        const byApp = {}
        for (const t of windows) {
            const k = String(t.appId || "").toLowerCase()
            ;(byApp[k] = byApp[k] || []).push(t)
        }
        const claimed = {}
        const take = function(keys) {
            let found = []
            for (const k of keys) {
                if (k && byApp[k] && !claimed[k]) { found = found.concat(byApp[k]); claimed[k] = true }
            }
            return found
        }
        const out = []
        for (const id of pinned) {
            const entry = lookupEntry(id, apps)
            const keys = [String(id).toLowerCase()]
            if (entry) {
                keys.push(String(entry.id).toLowerCase().replace(/\.desktop$/, ""))
                if (entry.startupClass) keys.push(String(entry.startupClass).toLowerCase())
                keys.push(String(entry.name).toLowerCase())
            }
            out.push({ key: "p:" + id, id: id, name: entry ? entry.name : id, icon: entry ? entry.icon : id, entry: entry, windows: take(keys), pinned: true })
        }
        for (const k in byApp) {
            if (claimed[k]) continue
            const entry = lookupEntry(k, apps)
            out.push({
                key: "r:" + k, id: entry ? entryKey(entry) : k,
                name: entry ? entry.name : (byApp[k][0].title || k), icon: entry ? entry.icon : k,
                entry: entry, windows: byApp[k], pinned: false
            })
        }
        return out
    }

    function launch(item) {
        if (item.entry) item.entry.execute()
        else Quickshell.execDetached([item.id])
    }

    function activate(item) {
        const list = item.windows
        if (list.length === 0) { launch(item); return false }
        let idx = -1
        for (let i = 0; i < list.length; i++) if (list[i].activated) idx = i
        list[(idx + 1) % list.length].activate()
        return true
    }

    function menuItems(item) {
        if (!item) return []
        const out = [{ id: "title", text: item.name, header: true }]
        for (let i = 0; i < Math.min(item.windows.length, 6); i++)
            out.push({ id: "win:" + i, text: item.windows[i].title || item.name, glyph: "󰖯" })
        if (item.windows.length > 0) out.push({ separator: true })
        out.push({ id: "new", text: item.windows.length > 0 ? "New window" : "Open", glyph: "󰐕" })
        if (item.entry && item.entry.actions) {
            for (let i = 0; i < item.entry.actions.length; i++)
                out.push({ id: "act:" + i, text: item.entry.actions[i].name, glyph: "󰁔" })
        }
        out.push({ separator: true })
        if (item.pinned) {
            out.push({ id: "unpin", text: "Unpin from dock", glyph: "󰤱" })
            out.push({ id: "left", text: "Move left", glyph: "󰁍" })
            out.push({ id: "right", text: "Move right", glyph: "󰁔" })
        } else {
            out.push({ id: "pin", text: "Pin to dock", glyph: "󰤰" })
        }
        if (item.windows.length > 0) out.push({ id: "closeall", text: "Close all windows", glyph: "󰅖", danger: true })
        return out
    }

    function onMenuPicked(id) {
        const item = menuTarget
        menu.open = false
        if (!item) return
        if (id === "new") launch(item)
        else if (id === "pin") BarDatabase.pinApp(item.id)
        else if (id === "unpin") BarDatabase.unpinApp(item.id)
        else if (id === "left") BarDatabase.movePinned(item.id, -1)
        else if (id === "right") BarDatabase.movePinned(item.id, 1)
        else if (id === "closeall") { for (const w of item.windows) w.close() }
        else if (id.indexOf("win:") === 0) item.windows[Number(id.slice(4))].activate()
        else if (id.indexOf("act:") === 0) item.entry.actions[Number(id.slice(4))].execute()
    }

    // first run: pin the common apps that are installed
    Timer {
        interval: 1500
        repeat: true
        running: BarDatabase.ready && !BarDatabase.dockSeeded && dock.apps.length > 0
        onTriggered: {
            const keys = []
            for (const id of dock.seedCandidates) {
                const e = dock.lookupEntry(id, dock.apps)
                if (e && keys.indexOf(dock.entryKey(e)) < 0) keys.push(dock.entryKey(e))
                if (keys.length >= 7) break
            }
            BarDatabase.dockPinned = keys
            BarDatabase.dockSeeded = true
        }
    }

    Row {
        id: row
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 4

        // app picker
        Item {
            id: launcherSlot
            width: dock.iconSize + 14
            height: dock.iconSize + 12
            Rectangle {
                id: launcherButton
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: dock.iconSize
                height: dock.iconSize
                radius: dock.iconSize * 0.28
                color: pickerArea.containsMouse || picker.open ? Qt.alpha(Colors.primary, 0.35) : Qt.alpha(Colors.primary, 0.18)
                Text { anchors.centerIn: parent; text: "󰀻"; color: Colors.primary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: dock.iconSize * 0.5 }
                scale: pickerArea.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                MouseArea {
                    id: pickerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.open = !picker.open
                }
            }
        }

        Rectangle {
            visible: dock.items.length > 0
            width: 1
            height: dock.iconSize * 0.7
            anchors.verticalCenter: launcherSlot.verticalCenter
            color: Qt.alpha(Colors.outline, 0.5)
        }

        Repeater {
            model: dock.items
            delegate: Item {
                id: slot
                required property var modelData
                readonly property bool hovered: area.containsMouse
                readonly property bool focused: modelData.windows.some(function(w) { return w.activated })
                property real lift: 0
                width: dock.iconSize + 14
                height: dock.iconSize + 12

                SequentialAnimation {
                    id: bounce
                    NumberAnimation { target: slot; property: "lift"; to: 14; duration: 160; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slot; property: "lift"; to: 0; duration: 220; easing.type: Easing.OutBounce }
                }

                Item {
                    id: iconWrap
                    width: dock.iconSize
                    height: dock.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6 - slot.lift
                    scale: slot.hovered ? 1.22 : 1
                    transformOrigin: Item.Bottom
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    IconImage {
                        anchors.fill: parent
                        source: dock.iconSource(slot.modelData.icon)
                    }
                }

                Rectangle {
                    visible: slot.modelData.windows.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: slot.focused ? 16 : 5
                    height: 4
                    radius: 2
                    color: slot.focused ? Colors.primary : Colors.fgDim
                    Behavior on width { NumberAnimation { duration: 140 } }
                }

                // tooltip
                Rectangle {
                    visible: slot.hovered && !menu.open
                    opacity: visible ? 1 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -34
                    width: tip.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: Qt.alpha(Colors.surfaceContainerHigh, 0.97)
                    border.color: Qt.alpha(Colors.outline, 0.4)
                    Text { id: tip; anchors.centerIn: parent; text: slot.modelData.name + (slot.modelData.windows.length > 1 ? "  ·  " + slot.modelData.windows.length : ""); color: Colors.fg; font.pixelSize: 11 }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            dock.menuTarget = slot.modelData
                            menu.anchorItem = slot
                            menu.items = dock.menuItems(slot.modelData)
                            menu.open = true
                        } else if (mouse.button === Qt.MiddleButton) {
                            dock.launch(slot.modelData)
                            bounce.restart()
                        } else if (!dock.activate(slot.modelData)) {
                            bounce.restart()
                        }
                    }
                }
            }
        }
    }

    MiniMenu {
        id: menu
        above: true
        onPicked: function(id) { dock.onMenuPicked(id) }
        onDismissed: open = false
    }

    AppPicker {
        id: picker
        anchorItem: launcherSlot
        onDismissed: open = false
    }
}
