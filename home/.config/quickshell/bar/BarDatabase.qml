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

    function load(): void {
        // Missing JSON keys are read back as type defaults, so anything older
        // than version 2 gets the current defaults applied once.
        const upgrade = data.version < 2
        root.doNotDisturb = data.doNotDisturb === true
        root.notifications = data.notifications || []
        root.notchHoverExpand = upgrade ? true : data.notchHoverExpand !== false
        root.notchAutoHide = upgrade ? true : data.notchAutoHide !== false
        root.reserveSpace = upgrade ? false : data.reserveSpace === true
        root.ready = true
        data.version = 2
        if (upgrade) persist()
    }

    function persist(): void {
        if (!root.ready) return
        data.version = 2
        data.doNotDisturb = root.doNotDisturb
        data.notifications = root.notifications
        data.notchHoverExpand = root.notchHoverExpand
        data.notchAutoHide = root.notchAutoHide
        data.reserveSpace = root.reserveSpace
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

    FileView {
        id: store
        path: root.filePath
        watchChanges: true

        JsonAdapter {
            id: data
            property int version: 2
            property bool doNotDisturb: false
            property var notifications: []
            property bool notchHoverExpand: true
            property bool notchAutoHide: true
            property bool reserveSpace: false
        }

        onAdapterUpdated: writeAdapter()

        onLoaded: root.load()

        onLoadFailed: {
            root.ready = false
            data.version = 2
            data.doNotDisturb = root.doNotDisturb
            data.notifications = root.notifications
            data.notchHoverExpand = root.notchHoverExpand
            data.notchAutoHide = root.notchAutoHide
            data.reserveSpace = root.reserveSpace
            root.ready = true
            writeAdapter()
        }

        onFileChanged: reload()
    }
}
