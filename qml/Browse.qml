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

    function openPlaylist(id, name) {
        playlistsPage.openById(id, name)
        currentTab = 0
    }

    function scrollPlaylistToCurrent() {
        playlistsPage.scrollDetailToCurrent()
    }

    onCurrentTabChanged: root.contextChanged()

    clip: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 6

            Text {
                text: "BROWSE"
                color: theme.outline
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            Item { Layout.preferredWidth: 8 }

            Repeater {
                model: [
                    { label: "Playlists", icon: "\ue8ef" },
                    { label: "Albums",    icon: "\ue02b" },
                    { label: "Artists",   icon: "\ue7fd" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool active: root.currentTab === index

                    property real chipW: tabRow.implicitWidth + 22
                    Layout.preferredWidth: chipW
                    Layout.preferredHeight: 30
                    radius: 9
                    Behavior on chipW {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    color: active
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (tabHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

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
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: active ? theme.primary : theme.onBackground
                            font.pixelSize: 11
                            font.weight: active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
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

                onPlaylistActivated: root.browseActivated()
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
