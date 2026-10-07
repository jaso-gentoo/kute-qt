import QtQuick

Item {
    id: page

    signal playlistActivated
    signal contextChanged

    clip: true

    property string viewing: ""
    property string viewingName: ""

    readonly property alias pendingRemoveCover: detailPage.pendingRemoveCover

    function closeDetail() {
        if (pendingRemoveCover && viewing !== "") {
            library.clearPlaylistCover(viewing)
        }
        library.setActivePlaylist("")
        viewing = ""
    }

    function closeDialogs() {
        listPage.closeDialogs()
    }

    onViewingChanged: page.contextChanged()

    Connections {
        target: library
        function onEditModeChanged() {
            if (!library.editMode && detailPage.pendingRemoveCover && page.viewing !== "") {
                library.clearPlaylistCover(page.viewing)
                detailPage.pendingRemoveCover = false
            }
        }
        function onFolderChanged() {
            page.closeDetail()
        }
    }

    PlaylistListPage {
        id: listPage
        anchors.fill: parent
        visible: opacity > 0.01

        onPlaylistOpened: (id, name) => {
            page.viewing = id
            page.viewingName = name
            library.setActivePlaylist(id)
        }
    }

    PlaylistDetailPage {
        id: detailPage
        anchors.fill: parent
        visible: opacity > 0.01

        playlistId: page.viewing
        playlistName: page.viewingName

        onBackRequested: page.closeDetail()
        onPlaylistActivated: page.playlistActivated()
    }

    states: [
        State {
            name: "list"
            when: page.viewing === ""

            PropertyChanges { target: listPage;   x: 0;             opacity: 1 }
            PropertyChanges { target: detailPage; x: detailPage.width; opacity: 0 }
        },
        State {
            name: "detail"
            when: page.viewing !== ""

            PropertyChanges { target: listPage;   x: -listPage.width; opacity: 0 }
            PropertyChanges { target: detailPage; x: 0;             opacity: 1 }
        }
    ]

    transitions: Transition {
        NumberAnimation { properties: "x"; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { property: "opacity"; duration: 320; easing.type: Easing.OutCubic }
    }
}