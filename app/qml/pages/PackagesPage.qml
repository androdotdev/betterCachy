import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: page
    readonly property var p: backend.palette
    readonly property var info: backend.pkgInfo
    property string kind: "pacman"
    readonly property var cur: info[kind] !== undefined ? info[kind] : ({ available: false, listed: 0, installed: 0, missing: [], extra: [] })

    PageHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Packages"
        subtitle: "Installed packages compared with packages/*.txt in the repo"
        Btn { text: "Refresh"; onClicked: backend.refreshPackages() }
        Btn { text: "Save installed to repo lists"; kind: "primary"; onClicked: backend.writePackageLists() }
    }

    Row {
        id: tabs
        anchors.top: header.bottom
        anchors.topMargin: 14
        spacing: 8
        Repeater {
            model: ["pacman", "aur", "flatpak"]
            delegate: Rectangle {
                required property string modelData
                width: 96
                height: 32
                radius: 16
                color: page.kind === modelData ? Qt.alpha(p.primary, 0.28) : p.surfaceContainerHigh
                Text { anchors.centerIn: parent; text: modelData; color: page.kind === modelData ? p.primary : p.fgDim; font.pixelSize: 12; font.bold: page.kind === modelData }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.kind = modelData }
            }
        }
        Item { width: 12; height: 1 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: p.outline
            font.pixelSize: 12
            text: cur.available ? cur.installed + " installed · " + cur.listed + " listed" : "tool not available on this machine"
        }
    }

    Row {
        id: lists
        anchors.top: tabs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: cmdCard.top
        anchors.bottomMargin: 14
        spacing: 14

        Repeater {
            model: [
                { title: "In the repo, not installed", key: "missing", tone: "warn" },
                { title: "Installed, not in the repo", key: "extra", tone: "info" }
            ]
            delegate: Rectangle {
                required property var modelData
                width: (lists.width - 14) / 2
                height: lists.height
                radius: 14
                color: p.surfaceContainerHigh
                Row {
                    x: 16
                    y: 12
                    spacing: 10
                    Text { text: modelData.title; color: p.fg; font.pixelSize: 13; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Chip { text: cur[modelData.key].length; tone: cur[modelData.key].length === 0 ? "ok" : modelData.tone }
                }
                ListView {
                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.topMargin: 46
                    clip: true
                    model: cur[modelData.key]
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Text { required property string modelData; width: ListView.view.width; height: 22; text: modelData; color: p.fgDim; font.pixelSize: 12; elide: Text.ElideRight }
                }
            }
        }
    }

    Card {
        id: cmdCard
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: backend.installCommand !== "" ? 96 : 56
        padding: 12
        Column {
            width: parent.width
            spacing: 6
            Text { text: backend.installCommand !== "" ? "Run this in a terminal to install what is missing:" : "Nothing missing. The repo lists are covered."; color: p.fgDim; font.pixelSize: 12 }
            TextEdit {
                width: parent.width
                visible: backend.installCommand !== ""
                readOnly: true
                selectByMouse: true
                text: backend.installCommand
                color: p.primary
                font.family: "monospace"
                font.pixelSize: 11
                wrapMode: TextEdit.WrapAnywhere
            }
        }
    }
}
