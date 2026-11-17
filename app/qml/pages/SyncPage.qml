import QtQuick
import QtQuick.Controls.Basic
import "../components"

Item {
    id: page
    readonly property var p: backend.palette
    property var picked: ({})

    function paths() { const out = []; for (const k in picked) if (picked[k]) out.push(k); return out }
    function resetPicks() {
        const m = {}
        for (const r of backend.drift) m[r.path] = r.select
        picked = m
    }
    Connections { target: backend; function onChanged(name) { if (name === "drift") page.resetPicks() } }

    PageHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Sync"
        subtitle: "Live files in ~/.config compared with the repo's home/ folder"
        Btn { text: "Refresh"; onClicked: backend.refreshSync() }
        Btn { text: "Save selected to repo"; kind: "primary"; enabled: page.paths().length > 0; onClicked: backend.saveToRepo(page.paths()) }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: gitCard.top
        anchors.bottomMargin: 14
        clip: true
        spacing: 5
        model: backend.drift
        ScrollBar.vertical: ScrollBar { }
        delegate: Rectangle {
            required property var modelData
            width: list.width - 8
            height: 40
            radius: 10
            color: p.surfaceContainerHigh
            Rectangle {
                id: box
                width: 18
                height: 18
                radius: 5
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: page.picked[modelData.path] ? p.primary : "transparent"
                border.color: page.picked[modelData.path] ? p.primary : Qt.alpha(p.outline, 0.7)
                Text { anchors.centerIn: parent; text: "✓"; color: p.fgPrimary; font.pixelSize: 12; visible: page.picked[modelData.path] === true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const m = Object.assign({}, page.picked); m[modelData.path] = !m[modelData.path]; page.picked = m } }
            }
            Chip { id: st; anchors.left: box.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.status; tone: modelData.status === "changed" ? "warn" : modelData.status === "new" ? "info" : "fail" }
            Text { anchors.left: st.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.path; color: p.fg; font.pixelSize: 12; elide: Text.ElideMiddle }
        }
        Text { anchors.centerIn: parent; visible: list.count === 0; text: "Everything matches the repo"; color: p.outline; font.pixelSize: 13 }
    }

    Card {
        id: gitCard
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 150
        padding: 14
        Column {
            width: parent.width
            spacing: 8
            Row {
                spacing: 10
                Text { text: "Git"; color: p.fg; font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Chip { text: backend.git.branch !== undefined && backend.git.branch !== "" ? backend.git.branch : "no repo"; tone: "info" }
                Chip { text: (backend.git.dirty !== undefined ? backend.git.dirty : 0) + " uncommitted"; tone: backend.git.dirty > 0 ? "warn" : "ok" }
                Text { text: backend.git.last !== undefined ? backend.git.last : ""; color: p.outline; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    width: parent.width - 220
                    height: 34
                    radius: 17
                    color: p.surfaceContainer
                    border.color: Qt.alpha(p.outline, 0.35)
                    TextInput {
                        id: msg
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: p.fg
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                        Text { visible: msg.text === ""; text: "Commit message"; color: p.outline; font: msg.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Btn { text: "Commit"; kind: "primary"; onClicked: { backend.commit(msg.text); msg.text = "" } }
                Btn { text: "Push"; onClicked: backend.push() }
            }
            Text { width: parent.width; text: backend.git.log !== undefined ? backend.git.log : ""; color: p.outline; font.family: "monospace"; font.pixelSize: 10; elide: Text.ElideRight; maximumLineCount: 3; wrapMode: Text.NoWrap }
        }
    }
}
