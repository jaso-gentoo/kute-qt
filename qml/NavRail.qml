import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rail

    signal infoToggled
    signal pageChanged(int page)
    signal searchRequested
    signal settingsRequested

    property bool settingsOpen: false
    property bool searchOpen: false

    implicitHeight: contentCol.implicitHeight + 20
    radius: 20
    color: theme.surface

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)
        border.width: 1
    }

    property int currentIndex: 0

    ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        // ===== Main pages =====
        Repeater {
            model: [
                { ic: "\ue88a", tip: "Home (Ctrl+1)",    page: 0 },
                { ic: "\ue7fd", tip: "Artists (Ctrl+2)", page: 2 }
            ]

            delegate: Item {
                id: navItem
                required property var modelData
                required property int index

                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                readonly property bool active: rail.currentIndex === index

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: theme.primary
                    opacity: navItem.active ? 0.16 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: theme.onSurface
                    opacity: (hov.containsMouse && !navItem.active) ? 0.09 : 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MaterialIcon {
                    id: navIcon
                    anchors.centerIn: parent
                    glyph: navItem.modelData.ic
                    iconSize: 20
                    filled: navItem.active
                    iconColor: navItem.active ? theme.primary : theme.onBackground
                    scale: hov.containsMouse ? 1.12 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.8
                        }
                    }
                    Behavior on iconColor { ColorAnimation { duration: 250 } }
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        navIcon.spin()
                        rail.currentIndex = navItem.index
                        rail.pageChanged(navItem.modelData.page)
                    }
                }

                Rectangle {
                    anchors.left: parent.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: tipText.implicitWidth + 20
                    height: 26
                    radius: 9
                    color: theme.surfaceVariant
                    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
                    border.width: 1
                    opacity: hov.containsMouse ? 1 : 0
                    visible: opacity > 0
                    z: 100
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: navItem.modelData.tip
                        color: theme.onSurface
                        font.pixelSize: 11
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            Layout.preferredWidth: 20
            Layout.preferredHeight: 1
            color: theme.outline
            opacity: 0.3
        }

        // ===== Now Playing =====
        Item {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: library.infoPanelVisible ? theme.primary : theme.onSurface
                opacity: library.infoPanelVisible
                    ? 0.16
                    : (hovInfo.containsMouse ? 0.09 : 0)
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MaterialIcon {
                id: infoIcon
                anchors.centerIn: parent
                glyph: "\ue88e"
                iconSize: 19
                filled: library.infoPanelVisible
                iconColor: library.infoPanelVisible ? theme.primary : theme.onBackground
                scale: hovInfo.containsMouse ? 1.12 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on iconColor { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: hovInfo
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    infoIcon.spin()
                    rail.infoToggled()
                }
            }

            Rectangle {
                anchors.left: parent.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: tipInfo.implicitWidth + 20
                height: 26
                radius: 9
                color: theme.surfaceVariant
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
                border.width: 1
                opacity: hovInfo.containsMouse ? 1 : 0
                visible: opacity > 0
                z: 100
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    id: tipInfo
                    anchors.centerIn: parent
                    text: "Now playing (Ctrl+Q)"
                    color: theme.onSurface
                    font.pixelSize: 11
                }
            }
        }

        // ===== Search =====
        Item {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: rail.searchOpen ? theme.primary : theme.onSurface
                opacity: rail.searchOpen
                    ? 0.16
                    : (hovSearch.containsMouse ? 0.09 : 0)
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MaterialIcon {
                id: searchIcon
                anchors.centerIn: parent
                glyph: "\ue8b6"
                iconSize: 19
                filled: rail.searchOpen
                iconColor: rail.searchOpen ? theme.primary : theme.onBackground
                scale: hovSearch.containsMouse ? 1.12 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on iconColor { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: hovSearch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    searchIcon.spin()
                    rail.searchRequested()
                }
            }

            Rectangle {
                anchors.left: parent.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: tipSearch.implicitWidth + 20
                height: 26
                radius: 9
                color: theme.surfaceVariant
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
                border.width: 1
                opacity: hovSearch.containsMouse ? 1 : 0
                visible: opacity > 0
                z: 100
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    id: tipSearch
                    anchors.centerIn: parent
                    text: "Search (Ctrl+F)"
                    color: theme.onSurface
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            Layout.preferredWidth: 20
            Layout.preferredHeight: 1
            color: theme.outline
            opacity: 0.3
        }

        // ===== Settings =====
        Item {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: rail.settingsOpen ? theme.primary : theme.onSurface
                opacity: rail.settingsOpen
                    ? 0.16
                    : (hovSettings.containsMouse ? 0.09 : 0)
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MaterialIcon {
                id: settingsIcon
                anchors.centerIn: parent
                glyph: "\ue8b8"
                iconSize: 19
                filled: rail.settingsOpen
                iconColor: rail.settingsOpen ? theme.primary : theme.onBackground
                scale: hovSettings.containsMouse ? 1.12 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on iconColor { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: hovSettings
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    settingsIcon.spin()
                    rail.settingsRequested()
                }
            }

            Rectangle {
                anchors.left: parent.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: tipSettings.implicitWidth + 20
                height: 26
                radius: 9
                color: theme.surfaceVariant
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
                border.width: 1
                opacity: hovSettings.containsMouse ? 1 : 0
                visible: opacity > 0
                z: 100
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    id: tipSettings
                    anchors.centerIn: parent
                    text: "Settings (Ctrl+E)"
                    color: theme.onSurface
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            Layout.preferredWidth: 20
            Layout.preferredHeight: 1
            color: theme.outline
            opacity: 0.3
        }

        // ===== Discord =====
        Item {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: library.discordRpcEnabled ? theme.primary : theme.onSurface
                opacity: library.discordRpcEnabled
                    ? 0.16
                    : (hovDiscord.containsMouse ? 0.09 : 0)
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            MaterialIcon {
                id: discordIcon
                anchors.centerIn: parent
                glyph: "\ue0e0"
                iconSize: 19
                filled: library.discordRpcEnabled
                iconColor: library.discordRpcEnabled ? theme.primary : theme.onBackground
                scale: hovDiscord.containsMouse ? 1.12 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on iconColor { ColorAnimation { duration: 250 } }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 5
                anchors.bottomMargin: 5
                width: 5
                height: 5
                radius: 3
                color: library.discordConnected ? theme.primary : "transparent"
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: hovDiscord
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    discordIcon.spin()
                    library.discordRpcEnabled = !library.discordRpcEnabled
                }
            }

            Rectangle {
                anchors.left: parent.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: tipDiscord.implicitWidth + 20
                height: 26
                radius: 9
                color: theme.surfaceVariant
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
                border.width: 1
                opacity: hovDiscord.containsMouse ? 1 : 0
                visible: opacity > 0
                z: 100
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    id: tipDiscord
                    anchors.centerIn: parent
                    text: library.discordRpcEnabled ? "Discord RPC: on" : "Discord RPC: off"
                    color: theme.onSurface
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 5
            Layout.bottomMargin: 2
            width: 6
            height: 6
            radius: 3
            color: theme.matugenActive ? theme.primary : theme.outline
            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}