import qs
import QtQuick

Item {
    id: root

    property var lines: []
    property real position: 0
    // idle | loading | ready (synced) | plain | none
    property string status: "idle"
    // original | roman | english, with altLines aligned to lines by index
    property string mode: "original"
    property var altLines: []
    signal seekRequested(real time)

    readonly property bool synced: status === "ready"
    readonly property int activeIndex: {
        if (!synced) return -1
        let found = -1
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].t <= position + 0.15) found = i
            else break
        }
        return found
    }

    clip: true

    ListView {
        id: list
        anchors.fill: parent
        visible: root.status === "ready" || root.status === "plain"
        model: root.lines
        spacing: 12
        interactive: !root.synced
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.activeIndex
        highlightRangeMode: root.synced ? ListView.StrictlyEnclosingRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - 24
        preferredHighlightEnd: height / 2 + 24
        highlightMoveDuration: 380
        highlightMoveVelocity: -1
        highlight: Item {}
        header: Item { width: list.width; height: root.synced ? list.height / 2 - 24 : 8 }
        footer: Item { width: list.width; height: root.synced ? list.height / 2 - 24 : 8 }

        delegate: Item {
            id: lineItem
            required property var modelData
            required property int index
            readonly property bool active: index === root.activeIndex
            readonly property string altText: root.mode !== "original" && index < root.altLines.length
                ? String(root.altLines[index] || "") : ""
            width: list.width
            height: lineColumn.implicitHeight

            Column {
                id: lineColumn
                x: 12
                width: parent.width - 24
                spacing: 2
                opacity: !root.synced || lineItem.active ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Text {
                    width: parent.width
                    text: lineItem.altText !== "" ? lineItem.altText : lineItem.modelData.text
                    color: lineItem.active ? Colors.fg : Colors.fgDim
                    font.pixelSize: 18
                    font.bold: lineItem.active
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    visible: root.mode === "english" && lineItem.altText !== ""
                    text: lineItem.modelData.text
                    color: Colors.outline
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.synced && lineItem.modelData.t >= 0
                cursorShape: Qt.PointingHandCursor
                onClicked: root.seekRequested(lineItem.modelData.t)
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !list.visible

        LoadingSpinner {
            width: 22
            height: 22
            dotSize: 6
            visible: root.status === "loading"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.status === "loading" ? "Finding lyrics…"
                : root.status === "none" ? "No lyrics found for this track"
                : "Play something to see lyrics"
            color: Colors.fgDim
            font.pixelSize: 13
        }
    }
}
