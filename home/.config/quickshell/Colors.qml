pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property color primary: adapter.primary
    property color fgPrimary: adapter.fgPrimary
    property color surface: adapter.surface
    property color surfaceContainer: adapter.surfaceContainer
    property color surfaceContainerHigh: adapter.surfaceContainerHigh
    property color fg: adapter.fg
    property color fgDim: adapter.fgDim
    property color outline: adapter.outline
    property color secondary: adapter.secondary
    property color tertiary: adapter.tertiary
    property color error: adapter.error

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string primary: "#cebdff"
            property string fgPrimary: "#35275e"
            property string surface: "#141318"
            property string surfaceContainer: "#211f24"
            property string surfaceContainerHigh: "#2b292f"
            property string fg: "#e6e1e9"
            property string fgDim: "#cac4cf"
            property string outline: "#938f99"
            property string secondary: "#cbc3dc"
            property string tertiary: "#efb8c9"
            property string error: "#ffb4ab"
        }
    }
}
