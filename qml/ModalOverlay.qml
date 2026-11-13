import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: overlay
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 2000
    focus: open

    property bool open: false
    property int  currentTab: 0

    readonly property int tabSettings: 0
    readonly property int tabSearch:   1
    readonly property int tabTrack:    2
    readonly property int tabLyrics:   3

    property alias trackSubTab: trackTab.subTab
    property alias trackTextIsLrc: trackTab.textIsLrc
    property alias lyricsIsLrc: lyricsTab.isLrcMode

    readonly property bool textFocused: {
        var w = Window.window
        if (!w) return false
        var it = w.activeFocusItem
        if (it === null) return false
        return typeof it.cursorPosition === "number"
    }

    signal closeRequested
    signal saved
    signal folderRequested
    signal searchNavigateToPlaylist(string id, string name, bool shouldScroll)
    signal searchNavigateToArtist(string name, bool shouldScroll)
    signal searchNavigateToAlbum(string name, bool shouldScroll)
    signal searchNavigateToAll(bool shouldScroll)


    function performTrackSave() { trackTab.performSave() }
    function lyricsRefresh() { lyricsTab.refresh() }

    function clearFocus() {
        var w = Window.window
        if (!w) return
        var it = w.activeFocusItem
        if (it && it.focus) it.focus = false
        overlay.forceActiveFocus()
    }

    function dropFocus() {
        var w = Window.window
        if (!w) return
        var it = w.activeFocusItem
        if (it && it.focus) it.focus = false
    }

    onOpenChanged: {
        if (open) Qt.callLater(function() { overlay.forceActiveFocus() })
        else dropFocus()
    }

    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    HoverHandler { blocking: true }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: true
        onWheel: (event) => { event.accepted = true }
    }

    Shortcut {
        sequence: "Escape"
        enabled: overlay.open
        onActivated: overlay.closeRequested()
    }

    Keys.onPressed: (event) => {
        if (!overlay.open) return
        if (overlay.textFocused) return
        if (event.key === Qt.Key_Space) {
            library.togglePlayPause()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            library.prev()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            library.next()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (library.hasCurrent && library.duration > 0)
                library.seek(Math.max(0, library.position - 3000))
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (library.hasCurrent && library.duration > 0)
                library.seek(Math.min(library.duration, library.position + 3000))
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: overlay.clearFocus()
        }
    }

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 20
        anchors.bottomMargin: 88

        Sidebar {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            currentTab: overlay.currentTab
            trackSubTab: overlay.trackSubTab
            trackTextIsLrc: overlay.trackTextIsLrc
            lyricsIsLrc: overlay.lyricsIsLrc

            onTabRequested: (tab) => overlay.currentTab = tab
            onTrackSubTabRequested: (sub) => overlay.trackSubTab = sub
            onTrackTextIsLrcRequested: (lrc) => {
                if (overlay.trackTextIsLrc !== lrc) overlay.trackTextIsLrc = lrc
            }
            onLyricsIsLrcRequested: (lrc) => {
                if (overlay.lyricsIsLrc !== lrc) overlay.lyricsIsLrc = lrc
            }
            onCloseRequested: overlay.closeRequested()
        }

        Rectangle {
            id: rightPanel
            anchors.left: sidebar.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 20
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: overlay.clearFocus()
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12
                clip: true

                SettingsView {
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabSettings
                    onFolderRequested: {
                        overlay.closeRequested()
                        overlay.folderRequested()
                    }
                }

                SearchView {
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabSearch
                    onNavigateToPlaylist: (id, name, shouldScroll) => overlay.searchNavigateToPlaylist(id, name, shouldScroll)
                    onNavigateToArtist: (name, shouldScroll) => overlay.searchNavigateToArtist(name, shouldScroll)
                    onNavigateToAlbum: (name, shouldScroll) => overlay.searchNavigateToAlbum(name, shouldScroll)
                    onNavigateToAll: (shouldScroll) => overlay.searchNavigateToAll(shouldScroll)
                }

                MetadataView {
                    id: trackTab
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabTrack
                    onCloseRequested: overlay.closeRequested()
                    onSaved: overlay.saved()
                }

                LyricsView {
                    id: lyricsTab
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabLyrics
                }
            }


        }
    }

    PlayerBar {
        id: modalPlayerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        height: 62
        z: 50
        onCoverClicked: library.infoPanelVisible = !library.infoPanelVisible
    }
}
