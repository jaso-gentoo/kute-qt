import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal playlistOpened(string id, string name)
    signal artistSelected(string name)
    signal albumSelected(string name)
    signal browseActivated
    signal contextChanged

    property int currentTab: 0
    readonly property bool showCounters: root.width > 550

    function closePlaylistsDialogs() {
        playlistsPage.closeDialogs()
    }

    onCurrentTabChanged: root.contextChanged()

    clip: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16)

                Icon {
                    anchors.centerIn: parent
                    glyph: ""
                    iconSize: 19
                    iconColor: theme.primary
                    filled: true
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "Browse"
                color: theme.onBackground
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Item { Layout.preferredWidth: 8 }

            Repeater {
                model: [
                    { label: "Playlists", icon: "" },
                    { label: "Albums",    icon: "" },
                    { label: "Artists",   icon: "" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool active: root.currentTab === index
                    readonly property int cnt: index === 0 ? library.playlistsFiltered.count
                                            : index === 1 ? library.albums.length
                                            : library.artists.length

                    property real chipW: tabRow.implicitWidth + (root.showCounters ? 20 : 16)
                    Layout.preferredWidth: chipW
                    Layout.preferredHeight: 30
                    radius: 9
                    Behavior on chipW {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    color: active
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (tabHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: modelData.icon
                            iconSize: 14
                            iconColor: active ? theme.primary : theme.outline
                            filled: active
                            Behavior on iconColor { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: active ? theme.primary : theme.onBackground
                            font.pixelSize: 11
                            font.weight: active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            visible: root.showCounters
                            anchors.verticalCenter: parent.verticalCenter
                            text: "·"
                            color: active ? theme.primary : theme.outline
                            font.pixelSize: 11
                            opacity: 0.5
                        }

                        Text {
                            visible: root.showCounters
                            anchors.verticalCenter: parent.verticalCenter
                            text: cnt
                            color: active ? theme.primary : theme.outline
                            font.pixelSize: 10
                            font.family: "monospace"
                            opacity: active ? 1.0 : 0.8
                        }
                    }

                    MouseArea {
                        id: tabHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = index
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Playlists {
                id: playlistsPage
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.currentTab === 0 ? 1 : 0
                x: root.currentTab === 0 ? 0 : 24
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                onPlaylistOpened: (id, name) => root.playlistOpened(id, name)
                onContextChanged: root.contextChanged()
            }

            Albums {
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.currentTab === 1 ? 1 : 0
                x: root.currentTab === 1 ? 0 : (root.currentTab < 1 ? 24 : -24)
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                onAlbumSelected: (name) => root.albumSelected(name)
                onAlbumActivated: root.browseActivated()
            }

            Artists {
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.currentTab === 2 ? 1 : 0
                x: root.currentTab === 2 ? 0 : (root.currentTab > 2 ? -24 : 24)
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                onArtistSelected: (name) => root.artistSelected(name)
                onArtistActivated: root.browseActivated()
            }
        }
    }
}
