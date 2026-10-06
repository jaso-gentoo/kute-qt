import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
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
    property bool floatingSearchOpen: false
    property double lastSearchClose: 0

    readonly property bool anyModalOpen: settingsOpen

    readonly property bool editAvailable: {
        if (currentPage === 0)
            return library.filterArtist === "" && library.filterAlbum === ""
        if (currentPage === 2 && browseView.currentTab === 2)
            return true
        return false
    }

    function closeFloatingSearch() {
        if (!floatingSearchOpen && library.filterText === "") return
        floatingSearchOpen = false
        library.setFilterText("")
        lastSearchClose = Date.now()
    }

    function openModal(tab) {
        closeFloatingSearch()
        if (playlistView) {
            playlistView.closeSort()
            playlistView.closeAddMenu()
        }
        if (browseView) browseView.closePlaylistsDialogs()
        settingsModal.currentTab = tab
        settingsOpen = true
    }

    function toggleSearch() {
        if (floatingSearchOpen) {
            closeFloatingSearch()
        } else {
            if (Date.now() - lastSearchClose < 250) return
            if (settingsOpen) settingsOpen = false
            if (playlistView) {
                playlistView.closeSort()
                playlistView.closeAddMenu()
            }
            if (browseView) browseView.closePlaylistsDialogs()
            floatingSearchOpen = true
        }
    }

    function toggleSettings() {
        if (settingsOpen && settingsModal.currentTab === settingsModal.tabSettings) {
            settingsOpen = false
        } else {
            openModal(settingsModal.tabSettings)
        }
    }

    function toggleMetadata() {
        if (!library.hasCurrent) return
        if (settingsOpen && settingsModal.currentTab === settingsModal.tabTrack) {
            settingsOpen = false
        } else {
            openModal(settingsModal.tabTrack)
        }
    }

    function toggleLyrics() {
        if (!library.hasCurrent) return
        if (settingsOpen && settingsModal.currentTab === settingsModal.tabLyrics) {
            settingsOpen = false
        } else {
            openModal(settingsModal.tabLyrics)
        }
    }

    function handleCtrlS() {
        if (settingsOpen && settingsModal.currentTab === settingsModal.tabTrack) {
            settingsModal.performTrackSave()
        }
    }

    function togglePlayPause()    { library.togglePlayPause() }
    function openFolderDialog()   { folderDialog.open() }
    function toggleInfoPanel()    { library.infoPanelVisible = !library.infoPanelVisible }
    function toggleCurrentLike()  { library.toggleCurrentLike() }

    function toggleReorder() {
        if (currentPage === 2 && browseView.currentTab !== 2) return
        if (currentPage !== 0 && currentPage !== 2) return
        if (currentPage === 0) {
            if (library.filterArtist !== "" || library.filterAlbum !== "") return
        }
        library.toggleReorderMode()
    }

    function syncPlaybackContext() {
        if (currentPage === 0) {
            library.setPlaybackContext("library")
        } else if (currentPage === 2) {
            if (browseView.currentTab === 2 && browseView.playlistsViewing !== "") {
                library.setPlaybackContext("playlist")
            } else {
                library.setPlaybackContext("library")
            }
        }
        if (library.editMode && !window.editAvailable) {
            library.toggleReorderMode()
        }
    }

    function goToHome() {
        library.clearFilter()
        closeFloatingSearch()
        if (playlistView) {
            playlistView.closeSort()
            playlistView.closeAddMenu()
        }
        if (browseView) browseView.closePlaylistsDialogs()
        library.setPlaybackContext("library")
        window.currentPage = 0
        navRail.currentIndex = 0
        Qt.callLater(window.syncPlaybackContext)
    }

    function goToArtists() {
        library.clearFilter()
        closeFloatingSearch()
        if (playlistView) {
            playlistView.closeSort()
            playlistView.closeAddMenu()
        }
        if (browseView) browseView.closePlaylistsDialogs()
        library.setPlaybackContext("library")
        window.currentPage = 2
        navRail.currentIndex = 1
        Qt.callLater(window.syncPlaybackContext)
    }

    function prevTrack() { library.prev() }
    function nextTrack() { library.next() }

    function modalPrevSubTab() { if (settingsOpen) settingsModal.previousSubTab() }
    function modalNextSubTab() { if (settingsOpen) settingsModal.nextSubTab() }

    Connections {
        target: library
        function onFilterArtistChanged() {
            if (library.editMode && library.filterArtist !== "")
                library.toggleReorderMode()
        }
        function onFilterAlbumChanged() {
            if (library.editMode && library.filterAlbum !== "")
                library.toggleReorderMode()
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

    Rectangle {
        anchors.fill: parent
        color: theme.background
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 92
        anchors.rightMargin: 16
        anchors.topMargin: 76
        anchors.bottomMargin: 100
        spacing: 20

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            PlaylistView {
                id: playlistView
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

            BrowseView {
                id: browseView
                anchors.fill: parent
                visible: window.currentPage === 2
                opacity: visible ? 1 : 0
                x: visible ? 0 : -20
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                onArtistSelected: (name) => {
                    library.clearFilter()
                    library.setFilterArtist(name)
                    window.currentPage = 0
                    navRail.currentIndex = 1
                    window.closeFloatingSearch()
                }
                onAlbumSelected: (name) => {
                    library.clearFilter()
                    library.setFilterAlbum(name)
                    window.currentPage = 0
                    navRail.currentIndex = 1
                    window.closeFloatingSearch()
                }
                onBrowseActivated: window.closeFloatingSearch()
                onContextChanged: Qt.callLater(window.syncPlaybackContext)
            }
        }

        InfoPanel {
            Layout.fillHeight: true
            Layout.preferredWidth: library.infoPanelVisible ? 300 : 0
            Layout.minimumWidth: 0
            clip: true
            opacity: library.infoPanelVisible ? 1 : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            onEditRequested: window.toggleMetadata()
        }
    }

    BottomBar {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        height: 72
        onCoverClicked: library.infoPanelVisible = !library.infoPanelVisible
    }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        height: 44
        radius: 16
        color: theme.surface

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: theme.outline
            border.width: 1
            opacity: 0.18
        }

        MouseArea {
            anchors.fill: parent
            onPressed: window.startSystemMove()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 6

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
                    { ic: "\ue15b", hover: "#2a2a2e", act: "min" },
                    { ic: "\ue3c6", hover: "#2a2a2e", act: "max" },
                    { ic: "\ue5cd", hover: "#4a2a2e", act: "close" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 32; height: 32; radius: 10
                    color: hov.containsMouse ? modelData.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MaterialIcon {
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

    NavRail {
        id: navRail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.topMargin: 68
        width: 60
        settingsOpen: window.settingsOpen
        searchOpen: window.floatingSearchOpen
        onInfoToggled: window.toggleInfoPanel()
        onSearchRequested: window.toggleSearch()
        onSettingsRequested: window.toggleSettings()
        onPageChanged: (page) => {
            library.clearFilter()
            window.closeFloatingSearch()
            if (playlistView) {
                playlistView.closeSort()
                playlistView.closeAddMenu()
            }
            if (browseView) browseView.closePlaylistsDialogs()
            window.currentPage = page
            Qt.callLater(window.syncPlaybackContext)
        }
    }

    Connections {
        target: window
        function onAnyModalOpenChanged() {
            if (window.anyModalOpen && playlistView) playlistView.closeSort()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: !window.anyModalOpen
              && !window.floatingSearchOpen
              && (library.filterArtist.length > 0
                  || library.filterAlbum.length > 0
                  || (window.currentPage === 2
                      && browseView.currentTab === 2
                      && browseView.playlistsViewing !== ""))
        onActivated: {
            if (library.filterArtist.length > 0 || library.filterAlbum.length > 0) {
                library.clearFilter()
                window.currentPage = 2
                navRail.currentIndex = 1
            } else {
                browseView.closePlaylistDetail()
            }
        }
    }

    FloatingSearch {
        id: floatingSearch
        open: window.floatingSearchOpen
        onCloseRequested: window.closeFloatingSearch()
    }

    SettingsModal {
        id: settingsModal
        open: window.settingsOpen
        onCloseRequested: window.settingsOpen = false
        onSaved: window.settingsOpen = false
        onFolderRequested: window.openFolderDialog()
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