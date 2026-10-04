import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root
    parent: Overlay.overlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 500

    property bool open: false
    signal closeRequested

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        propagateComposedEvents: true
        onClicked: (mouse) => {
            root.closeRequested()
            mouse.accepted = false
        }
    }

    Rectangle {
        id: bar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 100
        width: Math.min(540, parent.width - 80)
        height: 44
        radius: 14
        color: theme.surface
        border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.6)
        border.width: 1

        y: root.open ? 0 : 24
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 10

            MaterialIcon {
                glyph: "\ue8b6"
                iconSize: 17
                iconColor: theme.primary
            }

            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: "Search in current list…"
                placeholderTextColor: theme.outline
                color: theme.onBackground
                font.pixelSize: 13
                background: Item {}
                selectByMouse: true
                onTextChanged: library.setFilterText(text)

                HoverHandler { cursorShape: Qt.IBeamCursor }
            }

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 22

                Text {
                    anchors.centerIn: parent
                    text: "Esc"
                    color: theme.onBackground
                    font.pixelSize: 10
                    font.family: "monospace"
                    opacity: input.text.length === 0 ? 1 : 0
                    scale: input.text.length === 0 ? 1.0 : 0.7
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: clearHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.22)
                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                    opacity: input.text.length > 0 ? 1 : 0
                    scale: input.text.length > 0 ? 1.0 : 0.7
                    Behavior on color   { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue5cd"
                        iconSize: 13
                        iconColor: theme.onBackground
                    }

                    MouseArea {
                        id: clearHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: input.text.length > 0
                        onClicked: {
                            input.text = ""
                            library.setFilterText("")
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onOpenChanged() {
            if (root.open) {
                Qt.callLater(() => input.forceActiveFocus())
            } else {
                input.focus = false
                if (input.text.length > 0) input.text = ""
                library.setFilterText("")
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.closeRequested()
    }
}