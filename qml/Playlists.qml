import QtQuick

Item {
    id: page

    signal playlistOpened(string id, string name)
    signal contextChanged

    clip: true

    function closeDialogs() {
        listPage.closeDialogs()
    }

    PlaylistList {
        id: listPage
        anchors.fill: parent
        onPlaylistOpened: (id, name) => page.playlistOpened(id, name)
    }
}
