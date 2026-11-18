import qs
import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

Scope {
    id: root
    property var clock: SystemClock { precision: SystemClock.Minutes }
    property int unreadCount: 0
    property string activePopup: ""
    property bool doNotDisturb: BarDatabase.doNotDisturb
    property var notificationHistory: BarDatabase.notifications
    property bool playerOpen: false
    property bool barHoverRaw: false
    property bool barRevealRaw: false
    property bool barHovered: false
    property bool popupGrace: false
    // Right-click menus (tray, workspace) are separate popup windows, so the
    // bar has to track them itself. Otherwise leaving the capsule for the menu
    // counts as "unhovered" and the notch collapses behind the open menu.
    property int openContextMenus: 0
    readonly property bool showBattery: Config.battery && batteryDevice !== null && batteryDevice.ready
    property bool notchShown: !BarDatabase.notchAutoHide || BarDatabase.reserveSpace
    property bool notchExpanded: (Config.hoverExpand && barHovered) || activePopup !== "" || playerOpen || popupGrace || openContextMenus > 0
    readonly property bool notchAutoHide: BarDatabase.notchAutoHide && !BarDatabase.reserveSpace
    readonly property bool notchKeepShown: !notchAutoHide || barRevealRaw || barHoverRaw || barHovered || activePopup !== "" || playerOpen || popupGrace || openContextMenus > 0

    // Debounced hover: a short delay before expanding/revealing avoids flicker
    // when the pointer crosses the bar, and a longer delay before collapsing
    // keeps the bar open while the pointer moves between its widgets.
    onBarHoverRawChanged: {
        if (barHoverRaw) {
            hoverCollapseTimer.stop()
            hoverExpandTimer.restart()
        } else {
            hoverExpandTimer.stop()
            hoverCollapseTimer.restart()
        }
    }

    Timer {
        id: hoverExpandTimer
        interval: Config.hoverExpandDelay
        onTriggered: if (root.barHoverRaw) root.barHovered = true
    }
    Timer {
        id: hoverCollapseTimer
        interval: Config.hoverCollapseDelay
        onTriggered: if (!root.barHoverRaw) root.barHovered = false
    }

    // Keep the notch expanded briefly after the music popup closes. Closing it
    // with the same capsule click would otherwise collapse and re-expand the
    // bar while the pointer is still on the button.
    onPlayerOpenChanged: {
        if (playerOpen) {
            popupGraceTimer.stop()
            popupGrace = false
        } else {
            popupGrace = true
            popupGraceTimer.restart()
        }
    }

    Timer {
        id: popupGraceTimer
        interval: Config.popupCloseGrace
        onTriggered: root.popupGrace = false
    }

    onNotchAutoHideChanged: notchShown = notchKeepShown
    onNotchKeepShownChanged: {
        if (notchKeepShown) {
            notchShown = true
            notchHideTimer.stop()
        } else {
            notchHideTimer.restart()
        }
    }
    Component.onCompleted: notchShown = notchKeepShown

    Timer {
        id: notchHideTimer
        interval: Config.notchHideDelay
        onTriggered: if (!root.notchKeepShown) root.notchShown = false
    }
    property var notificationToasts: []
    property real toastProgress: 1
    property bool toastHovered: false
    property var batteryDevice: (UPower.devices.values || []).find(function(device) { return device.isLaptopBattery && device.isPresent }) || null
    property var workspaceEntries: {
        const workspaces = Hyprland.workspaces.values || []
        const named = workspaces.filter(function(workspace) { return workspace.id < 0 })
        let highestNumericId = 1
        for (const workspace of workspaces) highestNumericId = Math.max(highestNumericId, workspace.id)
        const numericSlots = Array.from({ length: highestNumericId }, function(_, index) { return index + 1 })
        return named.concat(numericSlots)
    }
    property var activePlayer: {
        const players = Mpris.players.values
        if (!players || players.length === 0) return null
        for (const player of players) {
            if (player.isPlaying) return player
        }
        return players[0]
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: false
        onNotification: function(notification) {
            notification.tracked = true
            root.unreadCount += 1
            const entry = {
                id: notification.id,
                appName: notification.appName || "Notification",
                summary: notification.summary || "",
                body: notification.body || ""
            }
            BarDatabase.addNotification(entry)
            if (!root.doNotDisturb) {
                root.notificationToasts = [entry, ...root.notificationToasts].slice(0, 2)
                toastCountdown.stop()
                root.toastProgress = 1
                toastCountdown.start()
                if (root.toastHovered) toastCountdown.pause()
            }
        }
    }

    function showPopup(name: string): void {
        popupCloseTimer.stop()
        root.activePopup = name
    }

    function deferPopupClose(): void {
        popupCloseTimer.restart()
    }

    function formatMediaTime(seconds): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const remainder = total % 60
        const twoDigits = function(value) { return value < 10 ? "0" + value : "" + value }
        return hours > 0
            ? hours + ":" + twoDigits(minutes) + ":" + twoDigits(remainder)
            : minutes + ":" + twoDigits(remainder)
    }

    function runPowerAction(action: string): void {
        root.activePopup = ""
        if (action === "lock") Quickshell.execDetached(["hyprlock"])
        else if (action === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
        else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    Timer {
        id: popupCloseTimer
        interval: Config.popupCloseDelay
        onTriggered: root.activePopup = ""
    }

    NumberAnimation {
        id: toastCountdown
        target: root
        property: "toastProgress"
        from: 1
        to: 0
        duration: 5000
        onFinished: root.notificationToasts = []
    }

    function hyprMoveActiveToWorkspace(id): void {
        if (Hyprland.usingLua) Hyprland.dispatch("hl.dsp.window.move({ workspace = " + id + " })")
        else Hyprland.dispatch("movetoworkspace " + id)
    }

    function hyprFocusRelative(step: string): void {
        if (Hyprland.usingLua) Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + step + "\" })")
        else Hyprland.dispatch("workspace " + step)
    }

    function hyprFocusWorkspace(id): void {
        if (Hyprland.usingLua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else Hyprland.dispatch("workspace " + id)
    }

    function windowsOnWorkspace(id): var {
        const out = []
        for (const t of (Hyprland.toplevels.values || [])) {
            if (t.workspace && t.workspace.id === id) out.push(t)
        }
        return out
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: Config.panelHeight
            color: "transparent"
            exclusionMode: BarDatabase.reserveSpace ? ExclusionMode.Auto : ExclusionMode.Ignore
            mask: Region {
                x: 0
                y: 0
                width: panel.width
                height: root.notchShown ? Config.panelHeight : Config.hiddenHoverHeight
            }

            Item {
                id: hoverArea
                anchors.fill: parent

                Rectangle {
                    id: notch
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.notchShown ? Config.notchTop : -Config.hiddenOffset
                    opacity: root.notchShown ? 1 : 0
                    Behavior on y { NumberAnimation { duration: Config.revealDuration; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    width: root.notchExpanded ? Math.min(panel.width - Config.screenEdgeMargin, Config.expandedMaxWidth) : Config.collapsedWidth
                    height: Config.notchHeight
                    radius: Config.notchRadius
                    color: Colors.surfaceContainer
                    border.color: Qt.alpha(Colors.outline, 0.35)
                    border.width: 1
                    clip: true
                    Behavior on width { NumberAnimation { duration: Config.widthDuration; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        opacity: root.notchExpanded ? 1 : 0
                        visible: opacity > 0
                        enabled: root.notchExpanded
                        Behavior on opacity { NumberAnimation { duration: Config.contentFadeDuration } }

                        MiniMenu {
                            id: wsMenu
                            property int targetId: 1
                            property bool countedOpen: false
                            onDismissed: open = false
                            onOpenChanged: {
                                if (open && !countedOpen) {
                                    countedOpen = true
                                    root.openContextMenus += 1
                                } else if (!open && countedOpen) {
                                    countedOpen = false
                                    root.openContextMenus = Math.max(0, root.openContextMenus - 1)
                                }
                            }
                            Component.onDestruction: {
                                if (countedOpen) {
                                    countedOpen = false
                                    root.openContextMenus = Math.max(0, root.openContextMenus - 1)
                                }
                            }
                            onPicked: function(id) {
                                open = false
                                if (id === "go") root.hyprFocusWorkspace(targetId)
                                else if (id === "move") root.hyprMoveActiveToWorkspace(targetId)
                            }
                        }

                        Repeater {
                            model: Config.workspaces ? root.workspaceEntries : []
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool numericSlot: typeof modelData === "number"
                                readonly property int workspaceId: numericSlot ? modelData : modelData.id
                                readonly property var workspace: numericSlot
                                    ? (Hyprland.workspaces.values.find(function(item) { return item.id === workspaceId }) || null)
                                    : modelData
                                readonly property bool focused: workspace !== null && workspace.focused
                                readonly property bool urgent: workspace !== null && workspace.urgent
                                width: focused ? 32 : 26
                                height: 26
                                radius: height / 2
                                color: focused ? Colors.primary : (urgent ? Qt.alpha(Colors.error, 0.15) : (workspace ? Colors.surfaceContainer : Colors.surface))
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.numericSlot ? parent.workspaceId : (parent.workspace.name || parent.workspaceId)
                                    color: parent.focused ? Colors.fgPrimary : (parent.workspace ? Colors.fg : Colors.outline)
                                    font.pixelSize: 11
                                    font.bold: parent.focused
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    spacing: 2
                                    Repeater {
                                        model: Math.min(3, root.windowsOnWorkspace(parent.parent.workspaceId).length)
                                        delegate: Rectangle {
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: parent.parent.parent.focused ? Colors.fgPrimary : Colors.primary
                                        }
                                    }
                                }
                                WheelHandler {
                                    onWheel: function(event) { root.hyprFocusRelative(event.angleDelta.y > 0 ? "e-1" : "e+1") }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            wsMenu.targetId = parent.workspaceId
                                            wsMenu.anchorItem = parent
                                            wsMenu.items = [
                                                { id: "title", text: "Workspace " + parent.workspaceId, header: true },
                                                { id: "go", text: "Go here", glyph: "󰁔" },
                                                { id: "move", text: "Move active window here", glyph: "󰁜" }
                                            ]
                                            wsMenu.open = true
                                            return
                                        }
                                        const target = parent.numericSlot ? parent.workspaceId : parent.workspace.name
                                        if (Hyprland.usingLua) {
                                            const value = typeof target === "number"
                                                ? target
                                                : "\"" + String(target).replace(/"/g, "\\\"") + "\""
                                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + value + " })")
                                        } else {
                                            Hyprland.dispatch("workspace " + target)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: Config.systemTray && SystemTray.items.values.length > 0
                            width: trayIcons.implicitWidth + 10
                            height: 30
                            radius: height / 2
                            color: Colors.surfaceContainer

                            Row {
                                id: trayIcons
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: SystemTray.items
                                    delegate: MouseArea {
                                        id: trayDelegate
                                        required property var modelData
                                        width: 24
                                        height: 26
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        ToolTip.visible: containsMouse && !trayPopup.open && (modelData.tooltipTitle || modelData.title)
                                        ToolTip.text: modelData.tooltipTitle || modelData.title || modelData.id
                                        ToolTip.delay: 500
                                        onClicked: function(mouse) {
                                            root.activePopup = ""
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.onlyMenu && modelData.hasMenu) trayPopup.open = true
                                                else modelData.activate()
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                modelData.secondaryActivate()
                                            } else {
                                                trayPopup.open = !trayPopup.open
                                            }
                                        }
                                        onWheel: function(wheel) {
                                            modelData.scroll(wheel.angleDelta.y, wheel.angleDelta.x !== 0)
                                        }
                                        IconImage {
                                            anchors.centerIn: parent
                                            source: trayDelegate.modelData.icon
                                            implicitSize: 18
                                        }
                                        TrayMenu {
                                            id: trayPopup
                                            property bool countedOpen: false
                                            trayItem: trayDelegate.modelData
                                            anchorItem: trayDelegate
                                            onDismissed: open = false
                                            onOpenChanged: {
                                                if (open && !countedOpen) {
                                                    countedOpen = true
                                                    root.openContextMenus += 1
                                                } else if (!open && countedOpen) {
                                                    countedOpen = false
                                                    root.openContextMenus = Math.max(0, root.openContextMenus - 1)
                                                }
                                            }
                                            Component.onDestruction: {
                                                if (countedOpen) {
                                                    countedOpen = false
                                                    root.openContextMenus = Math.max(0, root.openContextMenus - 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        opacity: root.notchExpanded ? 1 : 0
                        visible: opacity > 0
                        enabled: root.notchExpanded
                        Behavior on opacity { NumberAnimation { duration: Config.contentFadeDuration } }

                        Rectangle {
                            id: ytmusicButton
                            visible: Config.musicButton
                            readonly property int barCount: ytMusicPlayer.cavaBarCount
                            readonly property real barWidth: 2
                            readonly property real barGap: 2
                            readonly property real vizPad: 9
                            readonly property real barsWidth: barCount * barWidth + (barCount - 1) * barGap
                            readonly property real vizWidth: barsWidth + vizPad * 2
                            readonly property bool vizActive: Config.musicVisualizer && ytMusicPlayer.playing

                            width: 30 + (vizActive ? vizWidth : 0)
                            height: 30
                            radius: height / 2
                            clip: true
                            color: ytmusicMouse.containsMouse || ytMusicPlayer.open ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            Behavior on width { NumberAnimation { duration: Config.widthDuration; easing.type: Easing.OutCubic } }

                            // Visualizer sits to the LEFT of the glyph. The glyph stays
                            // pinned to the right edge so the capsule opens leftward and
                            // the bars are revealed from right to left.
                            Item {
                                id: ytmusicViz
                                x: 0
                                width: Math.max(0, parent.width - 30)
                                height: parent.height
                                clip: true

                                Row {
                                    id: ytmusicBars
                                    anchors.right: parent.right
                                    anchors.rightMargin: ytmusicButton.vizPad
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: ytmusicButton.barGap
                                    Repeater {
                                        model: ytmusicButton.barCount
                                        delegate: Item {
                                            required property int index
                                            width: ytmusicButton.barWidth
                                            height: 24
                                            Rectangle {
                                                width: parent.width
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: {
                                                    // Left-right mirror: reflect the spectrum around
                                                    // the centre so both halves are identical.
                                                    const src = Math.min(index, ytmusicButton.barCount - 1 - index)
                                                    const value = ytMusicPlayer.cavaBars[src] || 0
                                                    return Math.max(2, Math.min(1, value / 1000) * 16)
                                                }
                                                radius: width / 2
                                                color: Colors.primary
                                                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                id: ytmusicGlyph
                                anchors.right: parent.right
                                width: 30
                                height: parent.height
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "♫"
                                color: ytmusicMouse.containsMouse || ytMusicPlayer.open ? Colors.primary : Colors.fg
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: ytmusicMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    root.activePopup = ""
                                    if (mouse.button === Qt.RightButton) ytMusicPlayer.toggleFull()
                                    else if (mouse.button === Qt.MiddleButton) ytMusicPlayer.togglePlayback()
                                    else ytMusicPlayer.toggleMini()
                                }
                                onWheel: function(wheel) {
                                    ytMusicPlayer.nudgeVolume(wheel.angleDelta.y > 0 ? 5 : -5)
                                }
                            }
                        }

                        QuickSettings {
                            id: quickSettings
                            anchorItem: settingsButton
                            open: root.activePopup === "settings"
                            onPopupEntered: popupCloseTimer.stop()
                            onPopupLeft: root.deferPopupClose()
                        }

                        Rectangle {
                            id: settingsButton
                            color: root.activePopup === "settings" || settingsMouse.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            radius: height / 2
                            width: 32
                            height: 28
                            scale: settingsMouse.pressed ? 0.92 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Text {
                                id: settingsLabel
                                anchors.centerIn: parent
                                text: Networking.wifiEnabled ? "󰖩" : "󰤭"
                                color: settingsMouse.containsMouse || root.activePopup === "settings" ? Colors.primary : Colors.fg
                                font.pixelSize: 15
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea {
                                id: settingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activePopup = root.activePopup === "settings" ? "" : "settings"
                                onExited: if (root.activePopup === "settings") root.deferPopupClose()
                            }
                        }

                        Rectangle {
                            visible: root.showBattery
                            color: Colors.surfaceContainer
                            radius: height / 2
                            width: batteryText.implicitWidth + 16
                            height: 30
                            Text {
                                id: batteryText
                                anchors.centerIn: parent
                                text: {
                                    const device = root.batteryDevice
                                    if (!device || !device.ready) return ""
                                    const state = device.state
                                    const percentage = device.percentage
                                    const percent = Math.round(percentage <= 1 ? percentage * 100 : percentage)
                                    const charging = state === UPowerDeviceState.Charging
                                        || state === UPowerDeviceState.PendingCharge
                                        || !UPower.onBattery
                                    const icon = charging ? "󰂄" : "󰂎"
                                    return icon + " " + percent + "%"
                                }
                                color: Colors.secondary
                                font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        NotificationList {
                            id: notificationList
                            notifications: root.notificationHistory
                            anchorItem: bellButton
                            open: root.activePopup === "notifications"
                            doNotDisturb: root.doNotDisturb
                            onOpened: root.unreadCount = 0
                            onDoNotDisturbToggled: {
                                BarDatabase.doNotDisturb = !BarDatabase.doNotDisturb
                                if (BarDatabase.doNotDisturb) {
                                    toastCountdown.stop()
                                    root.notificationToasts = []
                                }
                            }
                            onPopupEntered: popupCloseTimer.stop()
                            onPopupLeft: root.deferPopupClose()
                        }

                        Rectangle {
                            id: infoCapsule
                            width: infoContents.implicitWidth + 20
                            height: 30
                            radius: height / 2
                            color: Colors.surfaceContainer

                            Row {
                                id: infoContents
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    id: bellButton
                                    visible: Config.notifications
                                    text: "󰂚"
                                    color: root.unreadCount > 0 ? Colors.error : Colors.fg
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        visible: root.unreadCount > 0
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Colors.error
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.activePopup = root.activePopup === "notifications" ? "" : "notifications"
                                        onExited: if (root.activePopup === "notifications") root.deferPopupClose()
                                    }
                                }
                                Text {
                                    id: clockText
                                    text: Qt.formatDateTime(root.clock.date, "ddd, d MMM  HH:mm")
                                    color: clockArea.containsMouse ? Colors.primary : Colors.fg
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    MouseArea {
                                        id: clockArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activePopup = root.activePopup === "calendar" ? "" : "calendar"
                                        onExited: if (root.activePopup === "calendar") root.deferPopupClose()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: powerButton
                            width: 30
                            height: 30
                            radius: height / 2
                            color: root.activePopup === "power" ? Qt.alpha(Colors.outline, 0.4) : Colors.surfaceContainer
                            Text {
                                anchors.centerIn: parent
                                text: "⏻"
                                color: Colors.error
                                font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.activePopup = root.activePopup === "power" ? "" : "power"
                                onExited: if (root.activePopup === "power") root.deferPopupClose()
                            }
                        }
                    }

                    MusicPlayer {
                        id: ytMusicPlayer
                        anchorItem: ytmusicButton
                        onPopupVisibleChanged: root.playerOpen = popupVisible
                        Component.onCompleted: root.playerOpen = popupVisible
                    }

                    CalendarPopup {
                        id: calendarPopup
                        anchorItem: clockText
                        open: root.activePopup === "calendar"
                        onPopupEntered: popupCloseTimer.stop()
                        onPopupLeft: root.deferPopupClose()
                    }

                    PopupWindow {
                        id: powerPopup
                        visible: root.activePopup === "power"
                        anchor.item: powerButton
                        anchor.edges: Edges.Bottom | Edges.Right
                        anchor.gravity: Edges.Bottom | Edges.Left
                        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
                        implicitWidth: 170
                        implicitHeight: 176
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Colors.surfaceContainer
                            border.color: Qt.alpha(Colors.outline, 0.4)
                            border.width: 1
                            HoverHandler {
                                onHoveredChanged: hovered ? popupCloseTimer.stop() : root.deferPopupClose()
                            }
                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                Repeater {
                                    model: [
                                        { label: "Lock", action: "lock", icon: "" },
                                        { label: "Log out", action: "logout", icon: "" },
                                        { label: "Reboot", action: "reboot", icon: "" },
                                        { label: "Shut down", action: "shutdown", icon: "" }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 34
                                        radius: 7
                                        color: powerActionArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            spacing: 9
                                            Text { text: modelData.icon; color: Colors.fgDim; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: modelData.label; color: Colors.fg; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                        MouseArea {
                                            id: powerActionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: root.runPowerAction(modelData.action)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: mediaWidget
                        visible: Config.mediaWidget && root.notchExpanded && (root.activePlayer !== null || opacity > 0)
                        opacity: (root.activePlayer !== null ? 1 : 0) * (root.notchExpanded ? 1 : 0)
                        scale: root.activePlayer !== null ? 1 : 0.94
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 220
                        height: 28
                        color: Colors.surfaceContainer
                        radius: height / 2
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Text {
                            id: mediaText
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: root.activePlayer ? "♫  " + (root.activePlayer.trackTitle || root.activePlayer.trackArtist || "Media") : ""
                            color: Colors.primary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.activePopup = root.activePopup === "media" ? "" : "media"
                            onExited: if (root.activePopup === "media") root.deferPopupClose()
                        }
                    }

                    Item {
                        id: compactContent
                        anchors.fill: parent
                        opacity: root.notchExpanded ? 0 : 1
                        visible: opacity > 0
                        enabled: false
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Row {
                                visible: Config.musicVisualizer && ytMusicPlayer.playing
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: 10
                                    delegate: Rectangle {
                                        required property int index
                                        width: 2
                                        radius: 1
                                        color: Colors.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: {
                                            const src = Math.min(index, 9 - index)
                                            const value = ytMusicPlayer.cavaBars[src] || 0
                                            return Math.max(2, Math.min(1, value / 1000) * 13)
                                        }
                                        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }

                            Text {
                                visible: ytMusicPlayer.playing
                                text: "♫"
                                color: Colors.primary
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: Qt.formatDateTime(root.clock.date, "HH:mm")
                                color: Colors.fg
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: Qt.formatDateTime(root.clock.date, "ddd, d MMM")
                                color: Colors.fgDim
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: root.showBattery
                                text: {
                                    const device = root.batteryDevice
                                    if (!device) return ""
                                    const percent = Math.round(device.percentage <= 1 ? device.percentage * 100 : device.percentage)
                                    const charging = device.state === UPowerDeviceState.Charging
                                        || device.state === UPowerDeviceState.PendingCharge
                                        || !UPower.onBattery
                                    return (charging ? "󰂄 " : "󰂎 ") + percent + "%"
                                }
                                color: Colors.secondary
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // Full-width reveal strip. With auto-hide on, hovering anywhere
            // along the top edge brings the notch back collapsed. It does not
            // expand anything; only the capsule sensor below does that.
            Item {
                id: revealSensor
                z: 999
                x: 0
                y: 0
                width: panel.width
                height: root.notchShown ? Config.panelHeight : Config.hiddenHoverHeight
                HoverHandler { onHoveredChanged: root.barRevealRaw = hovered }
            }

            // Passive hover sensor. It covers only the capsule (or a small
            // centered strip while the notch is hidden) so hovering the empty
            // reserved space reveals the bar without expanding it. HoverHandlers
            // do not accept pointer events, so clicks still reach the widgets.
            Item {
                id: hoverSensor
                z: 1000
                x: notch.x
                width: notch.width
                y: 0
                height: root.notchShown
                    ? Config.notchTop + Config.notchHeight
                    : Config.hiddenHoverHeight
                HoverHandler { onHoveredChanged: root.barHoverRaw = hovered }
            }

            PopupWindow {
                id: mediaPopup
                visible: root.activePopup === "media"
                anchor.item: mediaText
                anchor.edges: Edges.Bottom | Edges.Left
                anchor.gravity: Edges.Bottom | Edges.Right
                anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
                implicitWidth: 250
                implicitHeight: 148
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Colors.surfaceContainer
                    border.color: Qt.alpha(Colors.outline, 0.4)
                    border.width: 1
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text { text: root.activePlayer ? root.activePlayer.trackTitle || "Unknown track" : "No player"; color: Colors.fg; font.bold: true; elide: Text.ElideRight; width: parent.width }
                        Text { text: root.activePlayer ? root.activePlayer.trackArtist || "" : ""; color: Colors.fgDim; elide: Text.ElideRight; width: parent.width }
                        Row {
                            visible: root.activePlayer && root.activePlayer.positionSupported && root.activePlayer.lengthSupported
                            width: parent.width
                            spacing: 6
                            Text {
                                text: root.activePlayer ? root.formatMediaTime(root.activePlayer.position) : "0:00"
                                color: Colors.fgDim
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Slider {
                                id: mediaProgress
                                property var mediaPlayer: root.activePlayer
                                width: parent.width - 82
                                height: 22
                                from: 0
                                to: mediaPlayer ? Math.max(1, mediaPlayer.length) : 1
                                value: mediaPlayer ? Math.min(mediaPlayer.position, to) : 0
                                enabled: mediaPlayer && mediaPlayer.canSeek && mediaPlayer.positionSupported
                                onMoved: if (mediaPlayer && mediaPlayer.canSeek && mediaPlayer.positionSupported) mediaPlayer.position = value
                                background: Rectangle {
                                    x: mediaProgress.leftPadding
                                    y: mediaProgress.topPadding + mediaProgress.availableHeight / 2 - height / 2
                                    width: mediaProgress.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Colors.surfaceContainerHigh
                                    Rectangle {
                                        width: mediaProgress.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: Colors.primary
                                    }
                                }
                                handle: Rectangle {
                                    x: mediaProgress.leftPadding + mediaProgress.visualPosition * (mediaProgress.availableWidth - width)
                                    y: mediaProgress.topPadding + mediaProgress.availableHeight / 2 - height / 2
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: mediaProgress.enabled ? Colors.primary : Colors.outline
                                }
                            }
                            Text {
                                text: root.activePlayer ? root.formatMediaTime(root.activePlayer.length) : "0:00"
                                color: Colors.fgDim
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Row {
                            spacing: 18
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text { text: "⏮"; color: Colors.primary; MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer) root.activePlayer.previous() } }
                            Text { text: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶"; color: Colors.primary; MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer) root.activePlayer.togglePlaying() } }
                            Text { text: "⏭"; color: Colors.primary; MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer) root.activePlayer.next() } }
                        }
                    }
                    Timer {
                        interval: 1000
                        repeat: true
                        running: mediaPopup.visible && root.activePlayer !== null && root.activePlayer.isPlaying && root.activePlayer.positionSupported
                        onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
                    }
                    HoverHandler {
                        onHoveredChanged: hovered ? popupCloseTimer.stop() : root.deferPopupClose()
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { right: true; bottom: true }
            implicitWidth: 370
            implicitHeight: 220
            visible: Config.notifications && root.notificationToasts.length > 0
            color: "transparent"
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-notification-toasts"

            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: 14
                width: 340
                spacing: 8
                HoverHandler {
                    onHoveredChanged: {
                        root.toastHovered = hovered
                        if (hovered) toastCountdown.pause()
                        else if (root.notificationToasts.length > 0) toastCountdown.resume()
                    }
                }
                Repeater {
                    model: root.notificationToasts
                    delegate: Rectangle {
                        required property var modelData
                        width: 340
                        height: Math.max(76, toastContent.implicitHeight + 22)
                        radius: 12
                        color: Qt.alpha(Colors.surfaceContainer, 0.94)
                        border.color: Qt.alpha(Colors.outline, 0.4)
                        border.width: 1

                        Column {
                            id: toastContent
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 4
                            Text {
                                text: modelData.appName || "Notification"
                                color: Colors.primary
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.summary || "Notification"
                                color: Colors.fg
                                font.pixelSize: 13
                                font.bold: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                visible: !!modelData.body
                                text: modelData.body || ""
                                color: Colors.fgDim
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            anchors.bottomMargin: 7
                            height: 3
                            radius: 2
                            color: Colors.surfaceContainerHigh
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, root.toastProgress))
                                height: parent.height
                                radius: parent.radius
                                color: Colors.primary
                            }
                        }
                    }
                }
            }
        }
    }
}
