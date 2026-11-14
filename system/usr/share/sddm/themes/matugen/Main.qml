import QtQuick 2.15

Rectangle {
    id: root

    // ---------------------------------------------------------------- theme --
    // Palette comes from a Matugen-generated Colors.qml. The path is set in
    // theme.conf so the file can live outside the (root-owned) theme folder.
    Loader {
        id: colorsLoader
        source: (config.colorsPath !== undefined && String(config.colorsPath) !== "")
            ? String(config.colorsPath)
            : ""
    }

    function tone(name, fallback) {
        var palette = colorsLoader.item
        if (palette && palette[name] !== undefined && palette[name] !== null)
            return palette[name]
        return fallback
    }

    readonly property color cPrimary: tone("primary", "#ffb59b")
    readonly property color cOnPrimary: tone("fgPrimary", "#55200a")
    readonly property color cSurface: tone("surface", "#1a110e")
    readonly property color cSurfaceContainer: tone("surfaceContainer", "#271d1a")
    readonly property color cSurfaceHigh: tone("surfaceContainerHigh", "#322824")
    readonly property color cFg: tone("fg", "#f1dfd9")
    readonly property color cFgDim: tone("fgDim", "#d8c2bb")
    readonly property color cOutline: tone("outline", "#a08d86")
    readonly property color cError: tone("error", "#ffb4ab")

    readonly property string backgroundPath: (config.background !== undefined)
        ? Qt.resolvedUrl(String(config.background))
        : ""
    readonly property real dimAmount: (config.dim !== undefined)
        ? Math.max(0, Math.min(1, Number(config.dim)))
        : 0.4
    readonly property bool clockVisible: String(config.showClock) !== "false"

    property int sessionIndex: 0
    property string message: ""
    property bool busy: false
    property bool userMenuOpen: false
    property bool sessionMenuOpen: false

    color: cSurface

    // ------------------------------------------------------------- wallpaper --
    Repeater {
        model: screenModel

        Item {
            x: geometry.x
            y: geometry.y
            width: geometry.width
            height: geometry.height

            Image {
                anchors.fill: parent
                source: root.backgroundPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.backgroundPath !== "" ? root.dimAmount : 0
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.22)
                    }
                    GradientStop {
                        position: 0.55
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.55)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.92)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ clock --
    Column {
        id: clockBlock
        visible: root.clockVisible
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 64
        anchors.topMargin: 56
        spacing: 4

        Text {
            id: clockTime
            color: root.cFg
            font.family: "Noto Sans"
            font.pixelSize: 58
            font.weight: Font.Light
            text: Qt.formatTime(new Date(), "HH:mm")
        }

        Text {
            id: clockDate
            color: root.cFgDim
            font.family: "Noto Sans"
            font.pixelSize: 17
            opacity: 0.85
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            clockTime.text = Qt.formatTime(now, "HH:mm")
            clockDate.text = Qt.formatDate(now, "dddd, d MMMM")
        }
    }

    // ------------------------------------------------------------- login card --
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 400
        height: content.implicitHeight + 72
        radius: 26
        color: Qt.rgba(cSurfaceContainer.r, cSurfaceContainer.g, cSurfaceContainer.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(cOutline.r, cOutline.g, cOutline.b, 0.24)

        // Subtle top highlight so the card separates from a dark wallpaper.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.05)
        }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 36
            spacing: 14

            // Avatar -------------------------------------------------------
            Item {
                width: parent.width
                height: 92

                Rectangle {
                    id: avatar
                    anchors.centerIn: parent
                    width: 84
                    height: 84
                    radius: width / 2
                    color: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: usernameField.text.length > 0
                            ? usernameField.text.charAt(0).toUpperCase()
                            : "?"
                        color: root.cPrimary
                        font.family: "Noto Sans"
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                width: parent.width
                text: (typeof sddm.hostName !== "undefined" && sddm.hostName !== "")
                    ? "Sign in to " + sddm.hostName
                    : "Sign in"
                color: root.cFgDim
                font.family: "Noto Sans"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.75
            }

            // Username -----------------------------------------------------
            InputField {
                id: usernameField
                width: parent.width
                placeholder: "Username"
                trailingText: root.userMenuOpen ? "\u25B4" : "\u25BE"
                accentColor: root.cPrimary
                textColor: root.cFg
                fieldColor: Qt.rgba(root.cSurfaceHigh.r, root.cSurfaceHigh.g, root.cSurfaceHigh.b, 0.72)
                edgeColor: root.cOutline
                onTrailingClicked: {
                    root.sessionMenuOpen = false
                    root.userMenuOpen = !root.userMenuOpen
                }
                onAccepted: {
                    if (passwordField.text.length > 0) root.attemptLogin()
                    else passwordField.input.forceActiveFocus()
                }
            }

            // User picker --------------------------------------------------
            // Expands inline under the username field, so it never covers the
            // password box or floats around the screen.
            Item {
                id: userList
                width: parent.width
                height: root.userMenuOpen ? (userListColumn.implicitHeight + 4) : 0
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Column {
                    id: userListColumn
                    width: parent.width
                    topPadding: 2
                    spacing: 2

                    Repeater {
                        model: userModel

                        Rectangle {
                            width: userListColumn.width
                            height: 38
                            radius: 10
                            color: (userPick.containsMouse || model.name === usernameField.text)
                                ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.09)
                                : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.16)

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.name.charAt(0).toUpperCase()
                                        color: root.cPrimary
                                        font.family: "Noto Sans"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Text {
                                    height: 26
                                    verticalAlignment: Text.AlignVCenter
                                    text: model.name
                                    color: model.name === usernameField.text ? root.cPrimary : root.cFg
                                    font.family: "Noto Sans"
                                    font.pixelSize: 14
                                }

                                Text {
                                    height: 26
                                    verticalAlignment: Text.AlignVCenter
                                    visible: model.realName && model.realName !== model.name
                                    text: model.realName
                                    color: root.cFgDim
                                    font.family: "Noto Sans"
                                    font.pixelSize: 12
                                    opacity: 0.6
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.name === usernameField.text
                                text: "\u2713"
                                color: root.cPrimary
                                font.family: "Noto Sans"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: userPick
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    usernameField.text = model.name
                                    root.userMenuOpen = false
                                    root.message = ""
                                    passwordField.input.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            // Password -----------------------------------------------------
            InputField {
                id: passwordField
                width: parent.width
                placeholder: "Password"
                secret: true
                accentColor: root.cPrimary
                textColor: root.cFg
                fieldColor: Qt.rgba(root.cSurfaceHigh.r, root.cSurfaceHigh.g, root.cSurfaceHigh.b, 0.72)
                edgeColor: root.cOutline
                onAccepted: root.attemptLogin()
            }

            // Caps lock hint ----------------------------------------------
            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    visible: keyboard.capsLock && passwordField.input.activeFocus
                    text: "Caps Lock is on"
                    color: root.cFgDim
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    opacity: 0.8
                }
            }

            // Feedback ----------------------------------------------------
            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    text: root.message
                    color: root.cError
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    opacity: root.message !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
            }

            // Login -------------------------------------------------------
            ActionButton {
                width: parent.width
                label: root.busy ? "Signing in\u2026" : "Sign in"
                baseColor: root.cPrimary
                labelColor: root.cOnPrimary
                available: !root.busy
                onClicked: root.attemptLogin()
            }

            // Sessions ----------------------------------------------------
            Item {
                id: sessionRow
                width: parent.width
                height: 30

                Text {
                    id: sessionLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Session"
                    color: root.cFgDim
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    opacity: 0.7
                }

                Rectangle {
                    id: sessionPill
                    anchors.left: sessionLabel.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: sessionValue.implicitWidth + 22
                    height: 26
                    radius: 8
                    color: (sessionMouse.containsMouse || root.sessionMenuOpen)
                        ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.14)
                        : "transparent"
                    border.width: root.sessionMenuOpen ? 1 : 0
                    border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.35)

                    Row {
                        id: sessionValue
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: sessionModel

                            Text {
                                text: model.name
                                visible: index === root.sessionIndex
                                color: root.cPrimary
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            text: "\u25BE"
                            color: root.cPrimary
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: sessionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.userMenuOpen = false
                            root.sessionMenuOpen = !root.sessionMenuOpen
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------- menus overlay --
    // Clicking anywhere outside an open dropdown closes it. This sits above the
    // card but below the menu panels.
    MouseArea {
        anchors.fill: parent
        visible: root.sessionMenuOpen
        z: 50
        onClicked: {
            root.userMenuOpen = false
            root.sessionMenuOpen = false
        }
    }

    Rectangle {
        id: sessionMenu
        visible: root.sessionMenuOpen
        z: 60
        x: card.x + content.x + sessionPill.x
        y: card.y + content.y + sessionRow.y - height - 8
        width: 240
        height: sessionMenuColumn.implicitHeight + 12
        radius: 12
        color: Qt.rgba(root.cSurfaceHigh.r, root.cSurfaceHigh.g, root.cSurfaceHigh.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(root.cOutline.r, root.cOutline.g, root.cOutline.b, 0.35)

        Column {
            id: sessionMenuColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: sessionModel

                Rectangle {
                    width: sessionMenuColumn.width
                    height: 36
                    radius: 9
                    color: (sessionHover.containsMouse || index === root.sessionIndex)
                        ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.09)
                        : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.name
                        color: index === root.sessionIndex ? root.cPrimary : root.cFg
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index === root.sessionIndex
                        text: "\u2713"
                        color: root.cPrimary
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: sessionHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionIndex = index
                            root.sessionMenuOpen = false
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- power --
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 48
        anchors.bottomMargin: 36
        spacing: 26

        LinkButton {
            text: "Suspend"
            baseColor: root.cFgDim
            hoverColor: root.cPrimary
            visible: typeof sddm.canSuspend !== "undefined" ? sddm.canSuspend : false
            onClicked: sddm.suspend()
        }

        LinkButton {
            text: "Restart"
            baseColor: root.cFgDim
            hoverColor: root.cPrimary
            visible: typeof sddm.canReboot !== "undefined" ? sddm.canReboot : false
            onClicked: sddm.reboot()
        }

        LinkButton {
            text: "Shut down"
            baseColor: root.cFgDim
            hoverColor: root.cPrimary
            visible: typeof sddm.canPowerOff !== "undefined" ? sddm.canPowerOff : false
            onClicked: sddm.powerOff()
        }
    }

    // ----------------------------------------------------------------- logic --
    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false
            root.message = ""
        }

        function onLoginFailed() {
            root.busy = false
            root.message = "Incorrect password. Please try again."
            passwordField.text = ""
            passwordField.input.forceActiveFocus()
        }

        function onInformationMessage(msg) {
            root.busy = false
            if (msg && msg.message) root.message = msg.message
        }
    }

    // Moving to the password closes the inline user picker.
    Connections {
        target: passwordField.input
        function onActiveFocusChanged() {
            if (passwordField.input.activeFocus) root.userMenuOpen = false
        }
    }

    function attemptLogin() {
        if (busy) return
        root.userMenuOpen = false
        root.sessionMenuOpen = false
        if (usernameField.text.length === 0) {
            message = "Enter a username."
            usernameField.input.forceActiveFocus()
            return
        }
        message = ""
        busy = true
        sddm.login(usernameField.text, passwordField.text, sessionIndex)
    }

    Component.onCompleted: {
        sessionIndex = sessionModel.lastIndex
        var last = ""
        if (typeof userModel.lastUser !== "undefined" && userModel.lastUser)
            last = userModel.lastUser
        if (last !== "") usernameField.text = last
    }

    // Give focus once the greeter window is actually active, otherwise the
    // initial forceActiveFocus() is dropped while the view is still hidden.
    Timer {
        interval: 150
        repeat: false
        running: true
        onTriggered: {
            if (usernameField.text.length > 0) passwordField.input.forceActiveFocus()
            else usernameField.input.forceActiveFocus()
        }
    }
}
