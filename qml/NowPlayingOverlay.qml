import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: overlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 1000
    focus: open

    property bool open: false
    property int  currentTab: 0

    readonly property int tabSettings: 0
    readonly property int tabTrack:    1
    readonly property int tabLyrics:   2

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

    function performTrackSave() { trackTab.performSave() }
    function lyricsRefresh() { lyricsTab.refresh() }

    function clearFocus() {
        var w = Window.window
        if (!w) return
        var it = w.activeFocusItem
        if (it && it.focus) it.focus = false
        overlay.forceActiveFocus()
    }

    onOpenChanged: {
        if (open) Qt.callLater(function() { overlay.forceActiveFocus() })
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
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 20
        anchors.bottomMargin: 92

        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 220
            radius: 16
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: overlay.clearFocus()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Rectangle {
                    id: backBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: backHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIcon {
                            glyph: "\ue314"
                            iconSize: 16
                            iconColor: theme.onBackground
                            x: backHov.containsMouse ? -2 : 0
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Back"
                            color: theme.onBackground
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: backHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.closeRequested()
                    }
                }

                Rectangle {
                    id: settingsTab
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: overlay.currentTab === 0
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (settingsHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIcon {
                            glyph: "\ue8b8"
                            iconSize: 16
                            filled: overlay.currentTab === 0
                            iconColor: overlay.currentTab === 0 ? theme.primary : theme.outline
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Settings"
                            color: overlay.currentTab === 0 ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: overlay.currentTab === 0 ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: settingsHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.currentTab = 0
                    }
                }

                Rectangle {
                    id: metadataHeader
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: overlay.currentTab === 1
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (metaHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIcon {
                            glyph: "\ue3c9"
                            iconSize: 16
                            filled: overlay.currentTab === 1
                            iconColor: overlay.currentTab === 1 ? theme.primary : theme.outline
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Metadata"
                            color: overlay.currentTab === 1 ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: overlay.currentTab === 1 ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MaterialIcon {
                            glyph: "\ue5cf"
                            iconSize: 16
                            iconColor: overlay.currentTab === 1 ? theme.primary : theme.outline
                            rotation: overlay.currentTab === 1 ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: metaHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.currentTab = 1
                    }
                }

                Rectangle {
                    id: subFields
                    readonly property bool show: overlay.currentTab === 1
                    property real layoutH: show ? 32 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: overlay.trackSubTab === 0
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                        : (fieldsHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Fields"
                        color: overlay.trackSubTab === 0 ? theme.primary : theme.onBackground
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: fieldsHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.trackSubTab = 0
                    }
                }

                Rectangle {
                    id: subText
                    readonly property bool show: overlay.currentTab === 1
                    property real layoutH: show ? 32 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: overlay.trackSubTab === 1
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                        : (textHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Text"
                        color: overlay.trackSubTab === 1 ? theme.primary : theme.onBackground
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: textHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.trackSubTab = 1
                    }
                }

                Rectangle {
                    id: subLrcMeta
                    readonly property bool show: overlay.currentTab === 1 && overlay.trackSubTab === 1
                    property real layoutH: show ? 26 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 40
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: overlay.trackTextIsLrc
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (lrcMetaHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LRC"
                        color: overlay.trackTextIsLrc ? theme.primary : theme.onBackground
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    MouseArea {
                        id: lrcMetaHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.trackTextIsLrc = true
                    }
                }

                Rectangle {
                    id: subTag
                    readonly property bool show: overlay.currentTab === 1 && overlay.trackSubTab === 1
                    property real layoutH: show ? 26 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 40
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: !overlay.trackTextIsLrc
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (tagHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TAG"
                        color: !overlay.trackTextIsLrc ? theme.primary : theme.onBackground
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    MouseArea {
                        id: tagHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.trackTextIsLrc = false
                    }
                }

                Rectangle {
                    id: lyricsHeader
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: overlay.currentTab === 2
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (lyricsHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        MaterialIcon {
                            glyph: "\ue405"
                            iconSize: 16
                            filled: overlay.currentTab === 2
                            iconColor: overlay.currentTab === 2 ? theme.primary : theme.outline
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Lyrics"
                            color: overlay.currentTab === 2 ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: overlay.currentTab === 2 ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MaterialIcon {
                            glyph: "\ue5cf"
                            iconSize: 16
                            iconColor: overlay.currentTab === 2 ? theme.primary : theme.outline
                            rotation: overlay.currentTab === 2 ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: lyricsHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.currentTab = 2
                    }
                }

                Rectangle {
                    id: subLrcLyrics
                    readonly property bool show: overlay.currentTab === 2
                    property real layoutH: show ? 32 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: overlay.lyricsIsLrc
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                        : (lrcLyricsHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LRC"
                        color: overlay.lyricsIsLrc ? theme.primary : theme.onBackground
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: lrcLyricsHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (overlay.lyricsIsLrc !== true) {
                                overlay.lyricsIsLrc = true
                                overlay.lyricsRefresh()
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56
                        height: 22
                        radius: 6
                        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)

                        TextInput {
                            id: offsetField
                            anchors.fill: parent
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.onBackground
                            font.pixelSize: 10
                            font.family: "monospace"
                            selectByMouse: true
                            clip: true
                            selectionColor: theme.primary
                            selectedTextColor: theme.background
                            validator: DoubleValidator { bottom: -60.0; top: 60.0; decimals: 2 }

                            HoverHandler { cursorShape: Qt.IBeamCursor }

                            function syncFromLibrary() {
                                if (offsetField.activeFocus) return
                                var v = library.getLrcOffset(library.currentIndex)
                                offsetField.text = v.toFixed(2)
                            }

                            function commitValue() {
                                var raw = String(offsetField.text).replace(",", ".").trim()
                                var v = parseFloat(raw)
                                if (isNaN(v)) {
                                    offsetField.activeFocus = false
                                    syncFromLibrary()
                                    return
                                }
                                v = Math.max(-60, Math.min(60, v))
                                library.setLrcOffset(library.currentIndex, v)
                                offsetField.text = v.toFixed(2)
                                offsetField.activeFocus = false
                            }

                            Component.onCompleted: syncFromLibrary()
                            onAccepted: commitValue()
                            onEditingFinished: commitValue()

                            Connections {
                                target: library
                                function onCurrentChanged() { offsetField.syncFromLibrary() }
                                function onOffsetRevisionChanged() { offsetField.syncFromLibrary() }
                            }
                        }
                    }
                }

                Rectangle {
                    id: subTxt
                    readonly property bool show: overlay.currentTab === 2
                    property real layoutH: show ? 32 : 0
                    property real layoutTop: show ? 2 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 8
                    Layout.preferredHeight: layoutH
                    Layout.topMargin: layoutTop
                    opacity: show ? 1 : 0
                    clip: true
                    radius: 8

                    Behavior on layoutH { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on layoutTop { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    color: !overlay.lyricsIsLrc
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                        : (txtHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TXT"
                        color: !overlay.lyricsIsLrc ? theme.primary : theme.onBackground
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: txtHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (overlay.lyricsIsLrc !== false) {
                                overlay.lyricsIsLrc = false
                                overlay.lyricsRefresh()
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
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

                SettingsTab {
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabSettings
                    onFolderRequested: {
                        overlay.closeRequested()
                        overlay.folderRequested()
                    }
                }

                TrackTab {
                    id: trackTab
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabTrack
                    onCloseRequested: overlay.closeRequested()
                    onSaved: overlay.saved()
                }

                LyricsTab {
                    id: lyricsTab
                    anchors.fill: parent
                    isActive: overlay.open && overlay.currentTab === overlay.tabLyrics
                }
            }
        }
    }

    BottomBar {
        id: modalBottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        height: 60
        onLikeClicked: library.toggleCurrentLike()
        onCoverClicked: library.infoPanelVisible = !library.infoPanelVisible
    }
}
