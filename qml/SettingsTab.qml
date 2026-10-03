import QtQuick
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: isActive

    signal folderRequested

    readonly property bool lightLocked: theme.matugenEnabled
    readonly property bool matugenLocked: theme.lightTheme || !theme.matugenAvailable

    function previousSubTab() {}
    function nextSubTab() {}

    component ModalSection: ColumnLayout {
        id: secRoot
        property string title: ""
        property string icon: ""
        default property alias content: secBox.data

        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.leftMargin: 2
            spacing: 10

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: secRoot.icon
                    iconSize: 15
                    iconColor: theme.onBackground
                }
            }

            Text {
                text: secRoot.title
                color: theme.onBackground
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            id: secBox
            Layout.fillWidth: true
            spacing: 4
        }
    }

    component GroupedList: Rectangle {
        id: groupedList
        default property alias items: innerCol.data

        Layout.fillWidth: true
        implicitHeight: innerCol.implicitHeight + 8
        radius: 14
        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.03)
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
        border.width: 1

        ColumnLayout {
            id: innerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 0
        }
    }

    component SettingRow: Rectangle {
        id: setRow
        property string icon: ""
        property string label: ""
        property string description: ""
        property bool   rowChecked: false
        property bool   rowEnabled: true
        signal toggled

        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 10
        color: setRowHov.containsMouse && setRow.rowEnabled
            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        opacity: setRow.rowEnabled ? 1.0 : 0.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            MaterialIcon {
                glyph: setRow.icon
                iconSize: 18
                iconColor: theme.onBackground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: setRow.label
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: setRow.description
                    color: theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 21
                radius: 11
                color: setRow.rowChecked
                    ? theme.primary
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.20)
                Behavior on color { ColorAnimation { duration: 220 } }

                Rectangle {
                    width: 15
                    height: 15
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: setRow.rowChecked ? parent.width - width - 3 : 3
                    color: setRow.rowChecked ? theme.surface : theme.onBackground
                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        MouseArea {
            id: setRowHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: setRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: setRow.rowEnabled
            onClicked: setRow.toggled()
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 300
        maximumFlickVelocity: 8000

        TapHandler {
            onTapped: {
                const w = tab.Window.window
                if (w && w.activeFocusItem) w.activeFocusItem.focus = false
            }
        }

        ColumnLayout {
            id: col
            x: 24
            y: 20
            width: flick.width - 48
            spacing: 18

            ModalSection {
                title: "Library"
                icon: "\ue2c7"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 10
                    color: folderHov.containsMouse
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        MaterialIcon {
                            glyph: "\ue2c7"
                            iconSize: 18
                            iconColor: theme.onBackground
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: "Music folder"
                                color: theme.onBackground
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: library.folderName.length > 0 ? library.folderName : "Not selected"
                                color: theme.outline
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 55
                            Layout.preferredHeight: 20
                            radius: 6
                            color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Ctrl+O"
                                color: theme.onBackground
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }

                        MaterialIcon {
                            glyph: "\ue5cc"
                            iconSize: 16
                            iconColor: theme.outline
                        }
                    }

                    MouseArea {
                        id: folderHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.folderRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 2
                    text: "Scans recursively for .mp3, .flac, .ogg, .opus, .wav, .m4a, .aac"
                    color: theme.outline
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.8
                }
            }

            ModalSection {
                title: "Appearance"
                icon: "\ue40a"

                GroupedList {
                    SettingRow {
                        icon: "\ue518"
                        label: "Light theme"
                        description: tab.lightLocked
                            ? "Disabled while Matugen is on"
                            : "Switch between light and dark"
                        rowEnabled: !tab.lightLocked
                        rowChecked: theme.lightTheme
                        onToggled: theme.lightTheme = !theme.lightTheme
                    }

                    SettingRow {
                        icon: "\ue3b1"
                        label: "Matugen"
                        description: !theme.matugenAvailable
                            ? "Config not found in ~/.config/kute/matugen/"
                            : theme.lightTheme
                                ? "Disabled while Light theme is on"
                                : "Theme colors from wallpaper"
                        rowEnabled: theme.matugenAvailable && !theme.lightTheme
                        rowChecked: theme.matugenEnabled
                        onToggled: theme.matugenEnabled = !theme.matugenEnabled
                    }
                }
            }
        }
    }
}