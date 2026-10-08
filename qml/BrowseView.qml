import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal artistSelected(string name)
    signal albumSelected(string name)
    signal browseActivated
    signal contextChanged

    property int currentTab: 0
    property alias playlistsPageViewing: playlistsPage.viewing

    function closePlaylistDetail() {
        playlistsPage.closeDetail()
    }

    function closePlaylistsDialogs() {
        playlistsPage.closeDialogs()
    }

    onCurrentTabChanged: root.contextChanged()

    clip: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            Row {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [
                        { label: "Playlists", icon: "\ue8ef" },
                        { label: "Albums",    icon: "\ue02b" },
                        { label: "Artists",   icon: "\ue7fd" }
                    ]
                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentTab === index

                        width: tabRow.implicitWidth + 26
                        height: 34

                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            spacing: 7

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: modelData.icon
                                iconSize: 15
                                iconColor: active ? theme.primary : theme.outline
                                Behavior on iconColor { ColorAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: active ? theme.primary : theme.onBackground
                                opacity: active ? 1.0 : 0.6
                                font.pixelSize: 12
                                font.weight: active ? Font.DemiBold : Font.Medium
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: active ? tabRow.implicitWidth + 12 : 0
                            height: 2; radius: 1
                            color: theme.primary
                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            onTapped: root.currentTab = index
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            PlaylistsPage {
                id: playlistsPage
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.currentTab === 0 ? 1 : 0
                x: root.currentTab === 0 ? 0 : 24
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                onPlaylistActivated: root.browseActivated()
                onContextChanged: root.contextChanged()
            }

            AlbumsView {
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.currentTab === 1 ? 1 : 0
                x: root.currentTab === 1 ? 0 : (root.currentTab < 1 ? 24 : -24)
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                onAlbumSelected: (name) => root.albumSelected(name)
                onAlbumActivated: root.browseActivated()
            }

            ArtistsView {
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