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
    property var passwordNetwork: null
    property string passwordText: ""
    property string wifiMessage: ""
    signal popupEntered()
    signal popupLeft()

    readonly property var wifiDevice: {
        const devices = Networking.devices.values || []
        for (let index = 0; index < devices.length; index++) {
            if (devices[index].type === DeviceType.Wifi) return devices[index]
        }
        return null
    }

    readonly property var wifiNetworks: {
        const device = wifiDevice
        if (!device) return []
        const source = device.networks.values || []
        return source.filter(function(network) {
            return network && network.name
        }).sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.known !== b.known) return a.known ? -1 : 1
            return (b.signalStrength || 0) - (a.signalStrength || 0)
        })
    }

    readonly property var connectedNetwork: {
        for (const network of wifiNetworks) if (network.connected) return network
        return null
    }

    function securityNeedsPassword(network): bool {
        if (!network) return false
        return network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae
            || network.security === WifiSecurityType.Wpa3SuiteB192
    }

    function securityLabel(network): string {
        if (!network) return ""
        if (network.known) return "saved"
        return securityNeedsPassword(network) ? "locked" : "open"
    }

    function selectNetwork(network): void {
        if (!network || network.stateChanging) return
        root.wifiMessage = ""
        if (network.connected) {
            network.disconnect()
            return
        }
        if (network.known) {
            network.connect()
            return
        }
        if (securityNeedsPassword(network)) {
            root.passwordNetwork = network
            root.passwordText = ""
            return
        }
        network.connect()
    }

    function connectPassword(): void {
        if (!root.passwordNetwork) return
        root.passwordNetwork.connectWithPsk(root.passwordText)
        root.passwordNetwork = null
        root.passwordText = ""
    }

    function signalIcon(strength): string {
        const value = Math.max(0, Math.min(1, Number(strength) || 0))
        if (value > 0.8) return "󰤨"
        if (value > 0.55) return "󰤥"
        if (value > 0.3) return "󰤢"
        return "󰤟"
    }

    onOpenChanged: {
        if (open) {
            profileQuery.running = true
            if (wifiDevice) wifiDevice.scannerEnabled = true
        } else {
            if (wifiDevice) wifiDevice.scannerEnabled = false
            passwordNetwork = null
            passwordText = ""
            wifiMessage = ""
        }
    }

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
        implicitWidth: 330
        implicitHeight: Math.min(680, ccColumn.implicitHeight + 28)
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
                id: ccColumn
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 9

                Text {
                    text: "Control center"
                    color: Colors.primary
                    font.pixelSize: 13
                    font.bold: true
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 8
                        color: Networking.wifiEnabled ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: (Networking.wifiEnabled ? "󰖩" : "󰤭") + " Wi-Fi"
                            color: Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }

                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 8
                        color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "󰂰" : "󰂳") + " BT"
                            color: Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }

                    Rectangle {
                        width: (parent.width - 16) / 3
                        height: 34
                        radius: 8
                        color: BarDatabase.notchAutoHide && !BarDatabase.reserveSpace ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: "󰍹 Auto-hide"
                            color: Colors.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BarDatabase.notchAutoHide = !BarDatabase.notchAutoHide
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 8
                    color: BarDatabase.reserveSpace ? Qt.alpha(Colors.primary, 0.25) : Colors.surfaceContainer
                    border.color: BarDatabase.reserveSpace ? Qt.alpha(Colors.primary, 0.6) : "transparent"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: (BarDatabase.reserveSpace ? "󰄬  " : "     ") + "Reserve space on desktop"
                        color: BarDatabase.reserveSpace ? Colors.primary : Colors.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarDatabase.reserveSpace = !BarDatabase.reserveSpace
                    }
                }

                Text {
                    width: parent.width
                    text: !Networking.wifiEnabled ? "Wi-Fi is off"
                        : root.connectedNetwork ? "Connected to " + root.connectedNetwork.name
                        : "Not connected"
                    color: Colors.fgDim
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    visible: Networking.wifiEnabled
                    text: "Networks"
                    color: Colors.fgDim
                    font.pixelSize: 11
                    font.bold: true
                }

                ListView {
                    id: networkList
                    visible: Networking.wifiEnabled
                    width: parent.width
                    height: visible ? Math.max(34, Math.min(contentHeight, 168)) : 0
                    clip: true
                    spacing: 2
                    model: root.wifiNetworks
                    delegate: Rectangle {
                        required property var modelData
                        width: networkList.width
                        height: 32
                        radius: 7
                        color: modelData.connected
                            ? Qt.alpha(Colors.primary, 0.2)
                            : networkArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.connected ? "󰄬" : root.signalIcon(modelData.signalStrength)
                                color: modelData.connected ? Colors.primary : Colors.fgDim
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            Text {
                                width: parent.width - 118
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: modelData.connected ? Colors.primary : Colors.fg
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 66
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: modelData.stateChanging ? "connecting…"
                                    : root.securityLabel(modelData)
                                color: modelData.stateChanging ? Colors.primary : Colors.outline
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: networkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectNetwork(modelData)
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Networking.wifiEnabled && root.wifiNetworks.length === 0
                        text: "Scanning for networks…"
                        color: Colors.outline
                        font.pixelSize: 10
                    }
                }

                Column {
                    visible: root.passwordNetwork !== null
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: "Password for " + (root.passwordNetwork ? root.passwordNetwork.name : "")
                        color: Colors.fg
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    TextField {
                        id: pskField
                        width: parent.width
                        height: 32
                        placeholderText: "Wi-Fi password"
                        placeholderTextColor: Colors.outline
                        echoMode: TextInput.Password
                        color: Colors.fg
                        font.pixelSize: 11
                        onAccepted: root.connectPassword()
                        background: Rectangle {
                            radius: 7
                            color: Colors.surface
                            border.color: Qt.alpha(Colors.outline, 0.4)
                            border.width: 1
                        }
                    }

                    Row {
                        spacing: 8
                        Rectangle {
                            width: 76
                            height: 28
                            radius: 7
                            color: connectArea.containsMouse ? Qt.alpha(Colors.primary, 0.35) : Qt.alpha(Colors.primary, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Colors.primary
                                font.pixelSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                id: connectArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectPassword()
                            }
                        }
                        Rectangle {
                            width: 64
                            height: 28
                            radius: 7
                            color: cancelArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: Colors.fgDim
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.passwordNetwork = null
                                    root.passwordText = ""
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.wifiMessage !== ""
                    width: parent.width
                    text: root.wifiMessage
                    color: Colors.error
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Text {
                    text: "Audio output"
                    color: Colors.fgDim
                    font.pixelSize: 11
                    font.bold: true
                }

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
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                        }
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
