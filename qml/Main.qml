import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 1100
    height: 700
    minimumWidth: 800
    minimumHeight: 500
    visible: true
    title: "kute"
    color: theme.background
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint

    property int  currentPage: 0
    property bool settingsOpen: false
    property double lastSearchClose: 0
    property string activeRenderer: ""

    readonly property bool floatingSearchOpen: window.settingsOpen
        && nowPlayingOverlay
        && nowPlayingOverlay.currentTab === nowPlayingOverlay.tabSearch

    readonly property bool anyModalOpen: window.settingsOpen

    readonly property bool editAvailable: {
        if (currentPage === 0) {
            if (library.showOnlyLiked) return false
            if (library.sortField !== "custom") return false
            return library.filterArtist === ""
                && library.filterAlbum === ""
                && library.filterText === ""
        }
        if (currentPage === 3) return library.filterText === ""
        if (currentPage === 2 && browseView.currentTab === 0) return true
        return false
    }

    function closeFloatingSearch() {
        if (!window.settingsOpen) return
        window.settingsOpen = false
        window.lastSearchClose = Date.now()
    }

    function openModal(tab) {
        closeFloatingSearch()
        if (trackListPage) {
            trackListPage.closeSort()
            trackListPage.closeAddMenu()
        }
        if (browseView) browseView.closePlaylistsDialogs()
        nowPlayingOverlay.currentTab = tab
        window.settingsOpen = true
    }

    function toggleSearch() {
        if (window.floatingSearchOpen) {
            window.settingsOpen = false
            window.lastSearchClose = Date.now()
        } else {
            if (Date.now() - window.lastSearchClose < 250) return
            if (trackListPage) {
                trackListPage.closeSort()
                trackListPage.closeAddMenu()
            }
            if (browseView) browseView.closePlaylistsDialogs()
            nowPlayingOverlay.currentTab = nowPlayingOverlay.tabSearch
            window.settingsOpen = true
        }
    }

    function toggleSettings() {
        if (settingsOpen && nowPlayingOverlay.currentTab === nowPlayingOverlay.tabSettings) {
            window.settingsOpen = false
        } else {
            openModal(nowPlayingOverlay.tabSettings)
        }
    }

    function toggleMetadata() {
        if (!library.hasCurrent) return
        if (settingsOpen && nowPlayingOverlay.currentTab === nowPlayingOverlay.tabTrack) {
            window.settingsOpen = false
        } else {
            openModal(nowPlayingOverlay.tabTrack)
        }
    }

    function toggleLyrics() {
        if (!library.hasCurrent) return
        if (settingsOpen && nowPlayingOverlay.currentTab === nowPlayingOverlay.tabLyrics) {
            window.settingsOpen = false
        } else {
            openModal(nowPlayingOverlay.tabLyrics)
        }
    }

    function handleCtrlS() {
        if (settingsOpen && nowPlayingOverlay.currentTab === nowPlayingOverlay.tabTrack) {
            nowPlayingOverlay.performTrackSave()
        }
    }

    function togglePlayPause()    { library.togglePlayPause() }
    function openFolderDialog()   { folderDialog.open() }
    function toggleInfoPanel()    { library.infoPanelVisible = !library.infoPanelVisible }

    function refreshLibrary() {
        if (trackListPage) {
            trackListPage.triggerRefresh()
        } else {
            library.refreshLibrary()
        }
    }

    function toggleCurrentLike() {
        if (library.showOnlyLiked && library.isCurrentLiked() && trackListPage) {
            trackListPage.deleteCurrentLikedTrack()
        } else {
            library.toggleCurrentLike()
        }
    }

    function toggleEdit() {
        if (currentPage === 2 && browseView.currentTab !== 0) return
        if (currentPage === 0) {
            if (library.showOnlyLiked) return
            if (library.filterArtist !== "" || library.filterAlbum !== "") return
            if (library.filterText !== "") return
            if (library.sortField !== "custom") {
                library.applySort("custom", true)
            }
        } else if (currentPage === 3) {
            if (library.filterText !== "") return
        } else if (currentPage !== 2) {
            return
        }
        library.toggleEditMode()
    }

    function syncPlaybackContext() {
        if (library.activePlaylistId !== "") {
            library.setPlaybackContext("playlist")
        } else {
            library.setPlaybackContext("library")
        }
        if (library.editMode && !window.editAvailable) {
            library.toggleEditMode()
        }
    }

    function goToHome() {
        library.clearFilter()
        library.setActivePlaylist("")
        closeFloatingSearch()
        if (trackListPage) {
            trackListPage.closeSort()
            trackListPage.closeAddMenu()
        }
        if (browseView) {
            browseView.closePlaylistsDialogs()
        }
        library.setPlaybackContext("library")
        window.currentPage = 0
        navRail.currentIndex = 0
        Qt.callLater(window.syncPlaybackContext)
    }

    function goToArtists() {
        library.clearFilter()
        library.setActivePlaylist("")
        library.showOnlyLiked = false
        closeFloatingSearch()
        if (trackListPage) {
            trackListPage.closeSort()
            trackListPage.closeAddMenu()
        }
        if (browseView) {
            browseView.closePlaylistsDialogs()
        }
        library.setPlaybackContext("library")
        window.currentPage = 2
        navRail.currentIndex = 1
        Qt.callLater(window.syncPlaybackContext)
    }

    function prevTrack() { library.prev() }
    function nextTrack() { library.next() }

    function seekBackward() {
        if (!library.hasCurrent || library.duration <= 0) return
        library.seek(Math.max(0, library.position - 3000))
    }

    function seekForward() {
        if (!library.hasCurrent || library.duration <= 0) return
        library.seek(Math.min(library.duration, library.position + 3000))
    }

    function handleGlobalClick(gx, gy) {
    }

    function navigateToPlaylist(id, name, shouldScroll) {
        window.settingsOpen = false
        window.lastSearchClose = Date.now()
        library.clearFilter()
        library.setActivePlaylist(id)
        if (trackListPage) {
            trackListPage.closeSort()
            trackListPage.closeAddMenu()
        }
        if (browseView) browseView.closePlaylistsDialogs()
        window.currentPage = 3
        navRail.currentIndex = 1
        if (shouldScroll) Qt.callLater(function() {
            if (playlistDetailPage) playlistDetailPage.scrollToCurrent()
        })
        Qt.callLater(window.syncPlaybackContext)
    }

    function navigateToArtist(name, shouldScroll) {
        window.settingsOpen = false
        window.lastSearchClose = Date.now()
        library.clearFilter()
        library.setActivePlaylist("")
        library.setFilterArtist(name)
        window.currentPage = 0
        navRail.currentIndex = 1
        if (shouldScroll) Qt.callLater(window.scrollToCurrentTrack)
    }

    function navigateToAlbum(name, shouldScroll) {
        window.settingsOpen = false
        window.lastSearchClose = Date.now()
        library.clearFilter()
        library.setActivePlaylist("")
        library.setFilterAlbum(name)
        window.currentPage = 0
        navRail.currentIndex = 1
        if (shouldScroll) Qt.callLater(window.scrollToCurrentTrack)
    }

    function navigateToAll(shouldScroll) {
        window.settingsOpen = false
        window.lastSearchClose = Date.now()
        library.clearFilter()
        library.setActivePlaylist("")
        window.currentPage = 0
        navRail.currentIndex = 0
        if (shouldScroll) Qt.callLater(window.scrollToCurrentTrack)
    }

    function scrollToCurrentTrack() {
        if (trackListPage) trackListPage.scrollToCurrent()
    }

    Connections {
        target: library
        function onFilterArtistChanged() {
            if (library.editMode && library.filterArtist !== "")
                library.toggleEditMode()
        }
        function onFilterAlbumChanged() {
            if (library.editMode && library.filterAlbum !== "")
                library.toggleEditMode()
        }
        function onFilterTextChanged() {
            if (library.editMode && library.filterText !== "")
                library.toggleEditMode()
        }
        function onShowOnlyLikedChanged() {
            if (library.editMode && library.showOnlyLiked)
                library.toggleEditMode()
        }
        function onSearchShouldClose() {
            window.closeFloatingSearch()
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Select music folder"
        onAccepted: {
            library.loadFolder(selectedFolder.toString())
            window.goToHome()
        }
    }

    Item {
        id: mainContent
        anchors.fill: parent
        layer.enabled: window.settingsOpen
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.7
            blurMax: 64
        }

        Rectangle {
            anchors.fill: parent
            color: theme.background
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: theme.hideNavBar ? 16 : 86
            anchors.rightMargin: 16
            anchors.topMargin: theme.hideHeader ? 16 : 70
            anchors.bottomMargin: 88
            spacing: library.infoPanelVisible ? 10 : 0
            Behavior on spacing {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.topMargin {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: mainContentPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: theme.surface
                border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)
                border.width: 1
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true

                    TrackList {
                        id: trackListPage
                        anchors.fill: parent
                        visible: window.currentPage === 0
                        opacity: visible ? 1 : 0
                        x: visible ? 0 : -20
                        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                        onBackRequested: {
                            window.currentPage = 2
                            navRail.currentIndex = 1
                            window.closeFloatingSearch()
                        }
                        onTrackActivated: window.closeFloatingSearch()
                    }

                    Browse {
                        id: browseView
                        anchors.fill: parent
                        visible: window.currentPage === 2
                        opacity: visible ? 1 : 0
                        x: visible ? 0 : -20
                        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                        onArtistSelected: (name) => {
                            window.closeFloatingSearch()
                            library.clearFilter()
                            library.setActivePlaylist("")
                            library.setFilterArtist(name)
                            window.currentPage = 0
                            navRail.currentIndex = 1
                            Qt.callLater(window.scrollToCurrentTrack)
                        }
                        onAlbumSelected: (name) => {
                            window.closeFloatingSearch()
                            library.clearFilter()
                            library.setActivePlaylist("")
                            library.setFilterAlbum(name)
                            window.currentPage = 0
                            navRail.currentIndex = 1
                            Qt.callLater(window.scrollToCurrentTrack)
                        }
                        onPlaylistOpened: (id, name) => {
                            library.clearFilter()
                            library.setActivePlaylist(id)
                            window.closeFloatingSearch()
                            if (trackListPage) {
                                trackListPage.closeSort()
                                trackListPage.closeAddMenu()
                            }
                            window.currentPage = 3
                            navRail.currentIndex = 1
                            Qt.callLater(window.syncPlaybackContext)
                        }
                        onBrowseActivated: window.closeFloatingSearch()
                        onContextChanged: Qt.callLater(window.syncPlaybackContext)
                    }

                    PlaylistDetail {
                        id: playlistDetailPage
                        anchors.fill: parent
                        visible: window.currentPage === 3
                        opacity: visible ? 1 : 0
                        x: visible ? 0 : -20
                        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                        playlistId: library.activePlaylistId
                        playlistName: library.activePlaylistName

                        onBackRequested: {
                            library.setActivePlaylist("")
                            window.currentPage = 2
                            navRail.currentIndex = 1
                            Qt.callLater(window.syncPlaybackContext)
                        }
                        onPlaylistActivated: window.closeFloatingSearch()
                    }
                }
            }

            Item {
                id: infoSlot
                Layout.fillHeight: true
                Layout.preferredWidth: library.infoPanelVisible ? 260 : 0
                Layout.minimumWidth: 0
                clip: true
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                InfoPanel {
                    id: infoPanel
                    anchors.fill: parent
                    opacity: library.infoPanelVisible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }

        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            y: theme.hideHeader ? -44 : 16
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            height: 44
            radius: 16
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                enabled: !theme.hideHeader
                onPressed: window.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 8
                spacing: 6
                enabled: !theme.hideHeader

                Text {
                    text: "kute"
                    color: theme.onSurface
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }
                Text {
                    text: "· " + Qt.application.version
                    color: theme.outline
                    font.pixelSize: 10
                    font.letterSpacing: 1.0
                }

                Rectangle {
                    id: editBadge
                    Layout.leftMargin: 10
                    Layout.preferredWidth: library.editMode ? editBadgeText.implicitWidth + 20 : 0
                    Layout.preferredHeight: 20
                    radius: 10
                    color: theme.primary
                    clip: true
                    opacity: library.editMode ? 0.20 : 0

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Text {
                        id: editBadgeText
                        anchors.centerIn: parent
                        text: "EDIT MODE"
                        color: theme.primary
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        x: library.editMode ? 0 : 30
                        opacity: library.editMode ? 1 : 0
                        Behavior on x {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { ic: "", hover: "#2a2a2e", act: "min" },
                        { ic: "", hover: "#2a2a2e", act: "max" },
                        { ic: "", hover: "#4a2a2e", act: "close" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 32; height: 32; radius: 10
                        color: hov.containsMouse ? modelData.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Icon {
                            anchors.centerIn: parent
                            glyph: modelData.ic
                            iconSize: 15
                            iconColor: theme.onSurface
                        }
                        scale: hov.pressed ? 0.9 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 3.0 }
                        }
                        MouseArea {
                            id: hov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.act === "min") window.showMinimized()
                                else if (modelData.act === "max")
                                    window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                                else window.close()
                            }
                        }
                    }
                }
            }
        }

        NavBar {
            id: navRail
            x: theme.hideNavBar ? -60 : 16
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            anchors.top: parent.top
            anchors.topMargin: theme.hideHeader ? 16 : 70
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 88
            width: 60
            enabled: !theme.hideNavBar
            Behavior on anchors.topMargin {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            settingsOpen: window.settingsOpen
            searchOpen: window.floatingSearchOpen
            onInfoToggled: window.toggleInfoPanel()
            onSearchRequested: window.toggleSearch()
            onSettingsRequested: window.toggleSettings()
            onMetadataRequested: window.toggleMetadata()
            onLyricsRequested: window.toggleLyrics()
            onPageChanged: (page) => {
                library.clearFilter()
                library.setActivePlaylist("")
                if (page === 2) library.showOnlyLiked = false
                window.closeFloatingSearch()
                if (trackListPage) {
                    trackListPage.closeSort()
                    trackListPage.closeAddMenu()
                }
                if (browseView) {
                    browseView.closePlaylistsDialogs()
                }
                window.currentPage = page
                Qt.callLater(window.syncPlaybackContext)
            }
        }
    }

    PlayerBar {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        height: 62
        z: 500
        visible: !window.settingsOpen
        opacity: window.settingsOpen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        onCoverClicked: library.infoPanelVisible = !library.infoPanelVisible
        onLikeClicked: window.toggleCurrentLike()
    }

    Connections {
        target: window
        function onAnyModalOpenChanged() {
            if (window.anyModalOpen && trackListPage) trackListPage.closeSort()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: !window.anyModalOpen
              && (library.filterArtist.length > 0
                  || library.filterAlbum.length > 0
                  || library.activePlaylistId !== "")
        onActivated: {
            if (library.activePlaylistId !== "") {
                library.setActivePlaylist("")
                window.currentPage = 2
                navRail.currentIndex = 1
                Qt.callLater(window.syncPlaybackContext)
            } else if (library.filterArtist.length > 0 || library.filterAlbum.length > 0) {
                library.clearFilter()
                window.currentPage = 2
                navRail.currentIndex = 1
            }
        }
    }

    Shortcut { sequence: "Ctrl+R"; onActivated: library.refreshLibrary() }

    ModalOverlay {
        id: nowPlayingOverlay
        anchors.fill: parent
        open: window.settingsOpen
        onCloseRequested: window.settingsOpen = false
        onSaved: window.settingsOpen = false
        onFolderRequested: window.openFolderDialog()
        onSearchNavigateToPlaylist: (id, name, shouldScroll) => window.navigateToPlaylist(id, name, shouldScroll)
        onSearchNavigateToArtist: (name, shouldScroll) => window.navigateToArtist(name, shouldScroll)
        onSearchNavigateToAlbum: (name, shouldScroll) => window.navigateToAlbum(name, shouldScroll)
        onSearchNavigateToAll: (shouldScroll) => window.navigateToAll(shouldScroll)
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 6
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.TopEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 6
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.BottomEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.LeftEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.RightEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: 14
        height: 14
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        width: 14
        height: 14
        cursorShape: Qt.SizeBDiagCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.TopEdge | Qt.RightEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: 14
        height: 14
        cursorShape: Qt.SizeBDiagCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 14
        height: 14
        cursorShape: Qt.SizeFDiagCursor
        preventStealing: true
        onPressed: window.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }
}
