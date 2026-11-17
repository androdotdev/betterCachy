pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Single global store for bar/UI state. Editable by hand, watched for
// external changes, and rewritten whenever one of the tracked properties
// changes. MusicPlayer keeps its own per-feature state files.
Singleton {
    id: root

    readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/database.json"

    property bool ready: false
    property bool doNotDisturb: false
    property var notifications: []
    property bool notchHoverExpand: true
    property bool notchAutoHide: true
    property bool reserveSpace: false
    property bool dockEnabled: true
    property bool dockAutoHide: true
    property int dockIconSize: 44
    property bool dockSeeded: false
    property var dockPinned: []

    function pinApp(id: string): void {
        const list = root.dockPinned || []
        if (id !== "" && list.indexOf(id) < 0) root.dockPinned = list.concat([id])
    }

    function unpinApp(id: string): void {
        root.dockPinned = (root.dockPinned || []).filter(function(item) { return item !== id })
    }

    function movePinned(id: string, delta: int): void {
        const list = (root.dockPinned || []).slice()
        const from = list.indexOf(id)
        const to = from + delta
        if (from < 0 || to < 0 || to >= list.length) return
        list.splice(from, 1)
        list.splice(to, 0, id)
        root.dockPinned = list
    }

    function load(): void {
        // Missing JSON keys are read back as type defaults, so anything older
        // than version 2 gets the current defaults applied once.
        const upgrade = data.version < 2
        const upgradeDock = data.version < 3
        root.doNotDisturb = data.doNotDisturb === true
        root.notifications = data.notifications || []
        root.notchHoverExpand = upgrade ? true : data.notchHoverExpand !== false
        root.notchAutoHide = upgrade ? true : data.notchAutoHide !== false
        root.reserveSpace = upgrade ? false : data.reserveSpace === true
        root.dockEnabled = upgradeDock ? true : data.dockEnabled !== false
        root.dockAutoHide = upgradeDock ? true : data.dockAutoHide !== false
        root.dockIconSize = upgradeDock ? 44 : (data.dockIconSize > 0 ? data.dockIconSize : 44)
        root.dockSeeded = upgradeDock ? false : data.dockSeeded === true
        root.dockPinned = upgradeDock ? [] : (data.dockPinned || [])
        root.ready = true
        data.version = 3
        if (upgrade || upgradeDock) persist()
    }

    function persist(): void {
        if (!root.ready) return
        data.version = 3
        data.doNotDisturb = root.doNotDisturb
        data.notifications = root.notifications
        data.notchHoverExpand = root.notchHoverExpand
        data.notchAutoHide = root.notchAutoHide
        data.reserveSpace = root.reserveSpace
        data.dockEnabled = root.dockEnabled
        data.dockAutoHide = root.dockAutoHide
        data.dockIconSize = root.dockIconSize
        data.dockSeeded = root.dockSeeded
        data.dockPinned = root.dockPinned
    }

    function addNotification(entry): void {
        root.notifications = [entry].concat(root.notifications || []).slice(0, 30)
    }

    function clearNotifications(): void {
        root.notifications = []
    }

    onDoNotDisturbChanged: persist()
    onNotificationsChanged: persist()
    onNotchHoverExpandChanged: persist()
    onNotchAutoHideChanged: persist()
    onReserveSpaceChanged: persist()
    onDockEnabledChanged: persist()
    onDockAutoHideChanged: persist()
    onDockIconSizeChanged: persist()
    onDockSeededChanged: persist()
    onDockPinnedChanged: persist()

    FileView {
        id: store
        path: root.filePath
        watchChanges: true

        JsonAdapter {
            id: data
            property int version: 3
            property bool doNotDisturb: false
            property var notifications: []
            property bool notchHoverExpand: true
            property bool notchAutoHide: true
            property bool reserveSpace: false
            property bool dockEnabled: true
            property bool dockAutoHide: true
            property int dockIconSize: 44
            property bool dockSeeded: false
            property var dockPinned: []
        }

        onAdapterUpdated: writeAdapter()

        onLoaded: root.load()

        onLoadFailed: {
            root.ready = false
            data.version = 3
            data.doNotDisturb = root.doNotDisturb
            data.notifications = root.notifications
            data.notchHoverExpand = root.notchHoverExpand
            data.notchAutoHide = root.notchAutoHide
            data.reserveSpace = root.reserveSpace
            data.dockEnabled = root.dockEnabled
            data.dockAutoHide = root.dockAutoHide
            data.dockIconSize = root.dockIconSize
            data.dockSeeded = root.dockSeeded
            data.dockPinned = root.dockPinned
            root.ready = true
            writeAdapter()
        }

        onFileChanged: reload()
    }
}
