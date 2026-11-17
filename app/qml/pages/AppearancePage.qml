import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: page
    readonly property var p: backend.palette
    property string selected: ""
    property bool lockToo: backend.lock
    property var hy: ({})

    Connections {
        target: backend
        function onChanged(name) { if (name === "hypr") page.hy = Object.assign({}, backend.hypr) }
    }
    Component.onCompleted: hy = Object.assign({}, backend.hypr)

    function setHy(key, value) { const c = Object.assign({}, hy); c[key] = value; hy = c }

    PageHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Appearance"
        subtitle: "Pick a wallpaper, regenerate every palette, tune Hyprland"
    }

    // ---------- wallpaper column ----------
    Item {
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.right: side.left
        anchors.rightMargin: 18

        Row {
            id: folderRow
            width: parent.width
            spacing: 8
            Rectangle {
                width: parent.width - 90
                height: 34
                radius: 17
                color: p.surfaceContainerHigh
                border.color: Qt.alpha(p.outline, 0.35)
                TextInput {
                    id: folderInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    text: backend.wallpaperDir
                    color: p.fg
                    font.pixelSize: 12
                    clip: true
                    selectByMouse: true
                    onAccepted: backend.setWallpaperDir(text)
                }
            }
            Btn { text: "Scan"; onClicked: backend.setWallpaperDir(folderInput.text) }
        }

        GridView {
            id: grid
            anchors.top: folderRow.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: applyRow.top
            anchors.bottomMargin: 12
            clip: true
            cellWidth: Math.floor(width / Math.max(2, Math.floor(width / 200)))
            cellHeight: 128
            model: backend.wallpapers
            ScrollBar.vertical: ScrollBar { }
            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool isSelected: page.selected === modelData.path && modelData.path !== ""
                readonly property bool isCurrent: backend.currentWallpaper === modelData.path && modelData.path !== ""
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 12
                    color: p.surfaceContainerHigh
                    border.width: isSelected ? 2 : 0
                    border.color: p.primary
                    Image {
                        anchors.fill: parent
                        anchors.margins: isSelected ? 3 : 0
                        source: modelData.path !== "" ? "file://" + modelData.path : ""
                        sourceSize.width: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 26
                        radius: 12
                        color: Qt.alpha(p.surface, 0.8)
                        Text { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: Text.AlignVCenter; text: modelData.name; color: p.fg; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    Chip { visible: isCurrent; text: "current"; tone: "ok"; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.selected = modelData.path }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: "No images found in this folder"
                color: p.outline
                font.pixelSize: 13
            }
        }

        Row {
            id: applyRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            spacing: 14
            Btn {
                text: "Apply theme"
                kind: "primary"
                enabled: page.selected !== "" && backend.busy === ""
                onClicked: backend.applyWallpaper(page.selected, page.lockToo)
            }
            Toggle { label: "Also set lock screen"; checked: page.lockToo; onToggled: function(c) { page.lockToo = c }; width: 200; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---------- side column ----------
    Flickable {
        id: side
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 360
        clip: true
        contentHeight: sideCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sideCol
            width: parent.width
            spacing: 14

            Card {
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 10
                    Text { text: "Current palette"; color: p.fg; font.pixelSize: 14; font.bold: true }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: ["primary", "secondary", "error", "surface", "surfaceContainer", "surfaceContainerHigh", "outline", "fg"]
                            delegate: Column {
                                required property string modelData
                                spacing: 3
                                Rectangle { width: 40; height: 36; radius: 10; color: p[modelData]; border.color: Qt.alpha(p.outline, 0.5) }
                                Text { text: modelData === "secondary" ? "second" : modelData.replace("surfaceContainerHigh", "sc high").replace("surfaceContainer", "sc"); color: p.outline; font.pixelSize: 8; width: 40; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }
            }

            Card {
                width: parent.width
                Column {
                    width: parent.width
                    spacing: 4
                    Text { text: "Hyprland"; color: p.fg; font.pixelSize: 14; font.bold: true; bottomPadding: 6 }
                    SliderRow { width: parent.width; label: "Rounding"; from: 0; to: 30; value: page.hy.rounding !== undefined ? page.hy.rounding : 8; onMoved: function(v) { page.setHy("rounding", v) } }
                    SliderRow { width: parent.width; label: "Border size"; from: 0; to: 6; value: page.hy.border_size !== undefined ? page.hy.border_size : 1; onMoved: function(v) { page.setHy("border_size", v) } }
                    SliderRow { width: parent.width; label: "Gaps inner"; from: 0; to: 24; value: page.hy.gaps_in !== undefined ? page.hy.gaps_in : 6; onMoved: function(v) { page.setHy("gaps_in", v) } }
                    SliderRow { width: parent.width; label: "Gaps outer"; from: 0; to: 48; value: page.hy.gaps_out !== undefined ? page.hy.gaps_out : 12; onMoved: function(v) { page.setHy("gaps_out", v) } }
                    Toggle { width: parent.width; label: "Blur"; checked: page.hy.blur_enabled === true; onToggled: function(c) { page.setHy("blur_enabled", c) } }
                    SliderRow { width: parent.width; label: "Blur size"; from: 1; to: 16; value: page.hy.blur_size !== undefined ? page.hy.blur_size : 8; onMoved: function(v) { page.setHy("blur_size", v) } }
                    SliderRow { width: parent.width; label: "Blur passes"; from: 1; to: 6; value: page.hy.blur_passes !== undefined ? page.hy.blur_passes : 1; onMoved: function(v) { page.setHy("blur_passes", v) } }
                    Item { width: 1; height: 6 }
                    Btn { text: "Apply to Hyprland"; kind: "primary"; enabled: backend.busy === ""; onClicked: backend.applyHypr(page.hy) }
                    Text {
                        width: parent.width
                        visible: !backend.hyprInclude
                        wrapMode: Text.WordWrap
                        topPadding: 8
                        color: p.outline
                        font.pixelSize: 11
                        text: "First apply adds require(\"bettercachy\") to hyprland.lua (a backup is kept)."
                    }
                }
            }
        }
    }
}
