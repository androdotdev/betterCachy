import qs
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls

// Now-playing card: art-forward, blurred backdrop, lyrics tab, keyboard shortcuts.
PopupWindow {
    id: popup

    required property var player
    property string view: "player"
    // Set either to false if corners ever look square on your Qt build.
    property bool fancyBackdrop: true
    property bool fancyCover: true

    readonly property bool shown: player.open && player.popupMode === "mini"
    readonly property var track: player.currentTrack
    readonly property bool liked: !!(track && player.likedIds[track.id])
    readonly property var upNext: player.queueIndex >= 0 && player.queueIndex + 1 < player.queue.length
        ? player.queue[player.queueIndex + 1] : null
    readonly property string artUrl: track ? popup.bigArt(track.thumbnail) : ""

    function bigArt(url) {
        if (!url) return ""
        if (/googleusercontent\.com|ggpht\.com/.test(url)) return url.replace(/=w\d+-h\d+.*$/, "=w544-h544-l90-rj")
        return url
    }

    function setView(name) {
        view = name
        player.lyricsWanted = name === "lyrics"
        if (player.lyricsWanted) player.requestLyrics()
    }

    visible: shown || body.opacity > 0.01
    anchor.item: player.anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    implicitWidth: 380
    implicitHeight: 584
    color: "transparent"

    HyprlandFocusGrab {
        active: popup.shown
        windows: [popup]
        onCleared: popup.player.closePopup()
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 20
        color: Colors.surfaceContainer
        border.color: Qt.alpha(Colors.outline, 0.4)
        border.width: 1
        opacity: popup.shown ? 1 : 0
        scale: popup.shown ? 1 : 0.96
        transformOrigin: Item.TopRight
        focus: true
        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) popup.player.closePopup()
            else if (event.key === Qt.Key_Space) popup.player.togglePlayback()
            else if (event.key === Qt.Key_Right) popup.player.sendMpv(["seek", 5])
            else if (event.key === Qt.Key_Left) popup.player.sendMpv(["seek", -5])
            else if (event.key === Qt.Key_N) popup.player.nextTrack()
            else if (event.key === Qt.Key_P) popup.player.previousTrack()
            else if (event.key === Qt.Key_L) popup.setView(popup.view === "lyrics" ? "player" : "lyrics")
            else return
            event.accepted = true
        }

        Loader {
            id: backdrop
            anchors.fill: parent
            active: popup.fancyBackdrop
            Component.onCompleted: setSource("BlurBackdrop.qml", {
                source: Qt.binding(function() { return popup.artUrl }),
                radius: 20
            })
        }
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.alpha(Colors.surfaceContainer, 0.58)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // ---- tabs + library button
            Item {
                width: parent.width
                height: 30

                Rectangle {
                    width: 152
                    height: 30
                    radius: 15
                    color: Qt.alpha(Colors.outline, 0.16)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        Repeater {
                            model: [ { id: "player", label: "Player" }, { id: "lyrics", label: "Lyrics" } ]
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width / 2
                                height: parent.height
                                radius: 12
                                color: popup.view === modelData.id ? Qt.alpha(Colors.primary, 0.3) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: popup.view === modelData.id ? Colors.primary : Colors.fgDim
                                    font.pixelSize: 11
                                    font.bold: popup.view === modelData.id
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.setView(modelData.id)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    width: 92
                    height: 30
                    radius: 15
                    color: libArea.containsMouse ? Qt.alpha(Colors.primary, 0.3) : Qt.alpha(Colors.primary, 0.16)
                    Text { anchors.centerIn: parent; text: "▤  Library"; color: Colors.primary; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: libArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.player.openLibrary("home")
                    }
                }
            }

            // ---- stage: cover or lyrics
            Item {
                width: parent.width
                height: 280

                Item {
                    id: cover
                    width: 280
                    height: 280
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: popup.view === "player" ? 1 : 0
                    visible: opacity > 0.01
                    scale: popup.player.playing ? 1 : 0.93
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Colors.surfaceContainerHigh
                        visible: !maskedCover.item || !maskedCover.item.ready
                        Image {
                            id: plainCover
                            anchors.fill: parent
                            source: popup.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: maskedCover.status !== Loader.Ready && status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "♫"
                            color: Colors.primary
                            font.pixelSize: 72
                            visible: plainCover.status !== Image.Ready && (!maskedCover.item || !maskedCover.item.ready)
                        }
                    }
                    Loader {
                        id: maskedCover
                        anchors.fill: parent
                        active: popup.fancyCover
                        Component.onCompleted: setSource("MaskedImage.qml", {
                            source: Qt.binding(function() { return popup.artUrl }),
                            radius: 20
                        })
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Qt.alpha(Colors.surface, 0.75)
                        visible: popup.player.trackLoading
                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            LoadingSpinner { width: 26; height: 26; dotSize: 6; anchors.horizontalCenter: parent.horizontalCenter }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: popup.player.loadingStage === "resolve" ? "Finding stream…" : popup.player.loadingStage === "buffer" ? "Buffering…" : "Starting player…"
                                color: Colors.fg
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Row {
                    id: modeRow
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    opacity: popup.view === "lyrics" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Repeater {
                        model: [ { id: "original", label: "Original" }, { id: "roman", label: "Hinglish" }, { id: "english", label: "English" } ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 76
                            height: 24
                            radius: 12
                            color: popup.player.lyricsMode === modelData.id ? Qt.alpha(Colors.primary, 0.3) : Qt.alpha(Colors.outline, 0.16)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: popup.player.lyricsMode === modelData.id ? Colors.primary : Colors.fgDim
                                font.pixelSize: 11
                                font.bold: popup.player.lyricsMode === modelData.id
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popup.player.setLyricsMode(modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: popup.view === "lyrics" && popup.player.lyricsMode !== "original"
                        && (popup.player.lyricsAltState === "loading" || popup.player.lyricsAltState === "failed")
                    text: popup.player.lyricsAltState === "loading" ? "Converting lyrics…" : "Conversion unavailable (check network)"
                    color: Colors.outline
                    font.pixelSize: 11
                    z: 5
                }

                LyricsView {
                    anchors.top: modeRow.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    opacity: popup.view === "lyrics" ? 1 : 0
                    visible: opacity > 0.01
                    lines: popup.player.lyricsLines
                    mode: popup.player.lyricsMode
                    altLines: popup.player.lyricsAlt
                    status: popup.player.lyricsState
                    position: popup.player.position
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    onSeekRequested: function(time) { popup.player.sendMpv(["set_property", "time-pos", time]) }
                }
            }

            // ---- title + like
            Item {
                width: parent.width
                height: 46
                Column {
                    anchors.left: parent.left
                    anchors.right: likeButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: popup.track ? popup.track.title : "Nothing playing"
                        color: Colors.fg
                        font.pixelSize: 17
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: popup.track ? popup.track.artist : "Open the library to pick something"
                        color: Colors.fgDim
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    id: likeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    glyph: popup.liked ? "♥" : "♡"
                    tint: popup.liked ? Colors.error : Colors.outline
                    onClicked: popup.player.toggleLike()
                }
            }

            // ---- seek
            Row {
                width: parent.width
                spacing: 8
                Text { text: popup.player.formatTime(popup.player.position); color: Colors.fgDim; font.pixelSize: 10; width: 32; anchors.verticalCenter: parent.verticalCenter }
                ThemedSlider {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: Math.max(1, popup.player.duration)
                    value: Math.min(popup.player.position, to)
                    enabled: popup.track !== null && popup.player.duration > 0
                    onMoved: popup.player.sendMpv(["set_property", "time-pos", value])
                }
                Text { text: popup.player.formatTime(popup.player.duration); color: Colors.fgDim; font.pixelSize: 10; width: 32; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
            }

            // ---- transport
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⤨"; size: 17; tint: popup.player.shuffleEnabled ? Colors.primary : Colors.outline; onClicked: popup.player.toggleShuffle() }
                IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⏮"; size: 23; onClicked: popup.player.previousTrack() }
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: playArea.pressed ? Qt.darker(Colors.primary, 1.2) : Colors.primary
                    scale: playArea.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: popup.player.playing ? "⏸" : "▶"; color: Colors.fgPrimary; font.pixelSize: 23 }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: popup.player.togglePlayback() }
                }
                IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "⏭"; size: 23; onClicked: popup.player.nextTrack() }
                IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: popup.player.repeatMode === 0 ? "↻" : popup.player.repeatMode === 1 ? "↻¹" : "↻²"; size: 17; tint: popup.player.repeatMode === 0 ? Colors.outline : Colors.primary; onClicked: popup.player.cycleRepeat() }
            }

            // ---- volume, autoplay, queue
            Item {
                width: parent.width
                height: 28
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: popup.player.muted ? "󰖁" : "󰕾"
                        color: Colors.primary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: popup.player.sendMpv(["cycle", "mute"]) }
                    }
                    ThemedSlider {
                        width: 130
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0
                        to: 100
                        value: popup.player.volumeLevel
                        onMoved: popup.player.setPlayerVolume(value)
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    IconButton { anchors.verticalCenter: parent.verticalCenter; glyph: "∞"; size: 17; tint: popup.player.autoplay ? Colors.primary : Colors.outline; onClicked: popup.player.autoplay = !popup.player.autoplay }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        height: 26
                        radius: 13
                        color: queueArea.containsMouse ? Qt.alpha(Colors.primary, 0.3) : Qt.alpha(Colors.outline, 0.16)
                        Text { anchors.centerIn: parent; text: "☰  " + popup.player.queue.length; color: Colors.fg; font.pixelSize: 11 }
                        MouseArea {
                            id: queueArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.player.openLibrary("queue")
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 16
                horizontalAlignment: Text.AlignHCenter
                text: popup.upNext ? "Up next · " + popup.upNext.title : (popup.player.autoplay && popup.track ? "Autoplay will pick similar tracks" : "")
                color: Colors.outline
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
