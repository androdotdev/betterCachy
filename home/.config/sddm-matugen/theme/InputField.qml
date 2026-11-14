import QtQuick 2.15

Rectangle {
    id: field

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool secret: false
    property color accentColor: "#ffb59b"
    property color textColor: "#f1dfd9"
    property color fieldColor: "#332823"
    property color edgeColor: "#a08d86"
    property string trailingText: ""

    signal accepted()
    signal trailingClicked()

    implicitHeight: 54
    radius: 14
    color: fieldColor
    border.width: 1
    border.color: input.activeFocus
        ? accentColor
        : Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, 0.32)

    Behavior on border.color { ColorAnimation { duration: 120 } }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: field.trailingText !== "" ? 40 : 18
        verticalAlignment: TextInput.AlignVCenter
        color: field.textColor
        font.family: "Noto Sans"
        font.pixelSize: 17
        selectionColor: field.accentColor
        selectedTextColor: "#1a110e"
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: "\u25CF"
        selectByMouse: true
        clip: true
        onAccepted: field.accepted()
        Keys.onEscapePressed: {
            input.text = ""
            input.focus = false
        }
    }

    Text {
        anchors.fill: input
        anchors.leftMargin: 0
        verticalAlignment: TextInput.AlignVCenter
        text: field.placeholder
        color: field.textColor
        opacity: 0.42
        font: input.font
        visible: input.text.length === 0 && !input.activeFocus
        z: -1
    }

    Text {
        visible: field.trailingText !== ""
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: field.trailingText
        color: field.accentColor
        opacity: trailingMouse.containsMouse ? 1.0 : 0.75
        font.family: "Noto Sans"
        font.pixelSize: 13

        MouseArea {
            id: trailingMouse
            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: field.trailingClicked()
        }
    }
}
