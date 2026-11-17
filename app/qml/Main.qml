import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"
import "pages"

ApplicationWindow {
    id: win
    readonly property var p: backend.palette
    property int pageIndex: 0
    width: 1160
    height: 760
    minimumWidth: 900
    minimumHeight: 560
    visible: true
    title: "betterCachy"
    color: p.surface

    readonly property var pages: [
        { label: "Doctor", glyph: "✚", hint: "health checks" },
        { label: "Appearance", glyph: "◐", hint: "wallpaper, palette, Hyprland" },
        { label: "Services", glyph: "⚙", hint: "user services and logs" },
        { label: "Packages", glyph: "▣", hint: "installed vs listed" },
        { label: "Sync", glyph: "⇅", hint: "live config vs repo" }
    ]

    function refreshPage() {
        if (pageIndex === 0) backend.runDoctor()
        else if (pageIndex === 1) backend.loadAppearance()
        else if (pageIndex === 2) backend.refreshServices()
        else if (pageIndex === 3) backend.refreshPackages()
        else if (pageIndex === 4) backend.refreshSync()
    }
    onPageIndexChanged: refreshPage()
    Component.onCompleted: refreshPage()

    Rectangle {
        id: sidebar
        width: 220
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: p.surfaceContainer

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            Item {
                width: parent.width
                height: 54
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "betterCachy"; color: p.primary; font.pixelSize: 19; font.bold: true }
                    Text { text: "control center"; color: p.outline; font.pixelSize: 11 }
                }
            }

            Repeater {
                model: win.pages
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool active: win.pageIndex === index
                    width: parent.width
                    height: 44
                    radius: 12
                    color: active ? Qt.alpha(p.primary, 0.22) : navArea.containsMouse ? Qt.alpha(p.outline, 0.14) : "transparent"
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Text { text: modelData.glyph; color: active ? p.primary : p.fgDim; font.pixelSize: 16; width: 18 }
                        Text { text: modelData.label; color: active ? p.primary : p.fg; font.pixelSize: 14; font.bold: active }
                    }
                    MouseArea { id: navArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pageIndex = index }
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 18
            width: parent.width - 36
            text: backend.busy !== "" ? backend.busy + "…" : "ready"
            color: backend.busy !== "" ? p.primary : p.outline
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    StackLayout {
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 24
        currentIndex: win.pageIndex

        DoctorPage {}
        AppearancePage {}
        ServicesPage {}
        PackagesPage {}
        SyncPage {}
    }

    // toast
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(parent.width - 340, toastText.implicitWidth + 40)
        height: 42
        radius: 21
        color: p.surfaceContainerHigh
        border.color: Qt.alpha(p.primary, 0.5)
        opacity: backend.toast !== "" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: toastText; anchors.centerIn: parent; width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; text: backend.toast; color: p.fg; font.pixelSize: 12; elide: Text.ElideRight }
        Timer { running: backend.toast !== ""; interval: 4500; onTriggered: backend.clearToast() }
    }
}
