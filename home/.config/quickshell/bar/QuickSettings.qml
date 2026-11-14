import qs
import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Io

Scope {
    id: root
    property bool open: false
    property var anchorItem
    property var outputNodes: (Pipewire.nodes.values || []).filter(function(node) {
        return node.isSink && !node.isStream && node.audio
    })
    property var outputProfiles: []
    signal popupEntered()
    signal popupLeft()

    onOpenChanged: if (open) profileQuery.running = true

    function selectProfile(cardName: string, profileName: string): void {
        profileSetter.exec(["pactl", "set-card-profile", cardName, profileName])
    }

    Process {
        id: profileQuery
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const cards = JSON.parse(this.text)
                    const profiles = []
                    for (const card of cards) {
                        for (const profileName of Object.keys(card.profiles || {})) {
                            const profile = card.profiles[profileName]
                            if (!profile.available || profile.sinks < 1 || profileName === "pro-audio") continue
                            const label = profileName.indexOf("Speaker") >= 0 ? "Speakers"
                                : profileName.indexOf("Headphones") >= 0 ? "Headphones"
                                : profile.description || profileName
                            profiles.push({
                                cardName: card.name,
                                cardDescription: card.properties["device.description"] || card.name,
                                profileName: profileName,
                                label: label,
                                active: card.active_profile === profileName
                            })
                        }
                    }
                    root.outputProfiles = profiles
                } catch (error) {
                    root.outputProfiles = []
                }
            }
        }
    }

    Process {
        id: profileSetter
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("Audio profile switch failed:", this.text.trim())
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) console.warn("Audio profile switch exited with code", exitCode)
            profileQuery.running = true
        }
    }

    PwObjectTracker { objects: root.outputNodes }

    PopupWindow {
        visible: root.open
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: 280
        implicitHeight: 380
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colors.surfaceContainer
            border.color: Qt.alpha(Colors.outline, 0.4)
            border.width: 1
            HoverHandler {
                onHoveredChanged: hovered ? root.popupEntered() : root.popupLeft()
            }
            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                Text { text: "Control center"; color: Colors.primary; font.pixelSize: 13; font.bold: true }
                Row {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 38
                        radius: 8
                        color: Networking.wifiEnabled ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: (Networking.wifiEnabled ? "󰖩" : "󰤭") + "  Wi-Fi"
                            color: Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
                    }
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 38
                        radius: 8
                        color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "󰂰" : "󰂳")
                                  + "  Bluetooth"
                            color: Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
                    }
                }
                Text { text: "Audio output"; color: Colors.fgDim; font.pixelSize: 11; font.bold: true }
                ListView {
                    id: outputList
                    width: parent.width
                    height: Math.max(34, Math.min(contentHeight, 96))
                    clip: true
                    model: root.outputNodes
                    delegate: Rectangle {
                        required property var modelData
                        width: outputList.width
                        height: 34
                        radius: 7
                        color: Pipewire.defaultAudioSink === modelData ? Qt.alpha(Colors.primary, 0.25) : "transparent"
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Pipewire.defaultAudioSink === modelData ? "󰄬  " : "󰓃  ")
                                  + (modelData.description || modelData.nickname || modelData.name || "Audio device")
                            color: Pipewire.defaultAudioSink === modelData ? Colors.primary : Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.outputNodes.length === 0
                        text: "No audio outputs found"
                        color: Colors.outline
                        font.pixelSize: 11
                    }
                }
                Text {
                    visible: root.outputProfiles.length > 1
                    text: "Output mode"
                    color: Colors.fgDim
                    font.pixelSize: 11
                    font.bold: true
                }
                ListView {
                    id: profileList
                    visible: root.outputProfiles.length > 1
                    width: parent.width
                    height: Math.min(contentHeight, 72)
                    clip: true
                    model: root.outputProfiles
                    delegate: Rectangle {
                        required property var modelData
                        width: profileList.width
                        height: 34
                        radius: 7
                        color: modelData.active ? Qt.alpha(Colors.primary, 0.25) : "transparent"
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            verticalAlignment: Text.AlignVCenter
                            text: (modelData.active ? "󰄬  " : "󰓃  ") + modelData.label
                            color: modelData.active ? Colors.primary : Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectProfile(modelData.cardName, modelData.profileName)
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        width: parent.width - muteButton.width - parent.spacing
                        text: "󰕾  " + (Pipewire.defaultAudioSink
                              ? (Pipewire.defaultAudioSink.audio.muted ? "Muted" : Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%")
                              : "Volume unavailable")
                        color: Colors.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: muteButton
                        text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio.muted ? "󰖁" : "󰕾"
                        color: Colors.primary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
                    }
                }
                Slider {
                    width: parent.width
                    from: 0
                    to: 1.5
                    value: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0
                    onMoved: if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = value
                }
            }
        }
    }
}
