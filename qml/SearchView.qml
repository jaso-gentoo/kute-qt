import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: opacity > 0.01
    opacity: isActive ? 1 : 0
    enabled: isActive
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property string query: ""
    property var results: []
    property var flatItems: []
    property int selectedIndex: 0

    signal navigateToPlaylist(string id, string name, bool shouldScroll)
    signal navigateToArtist(string name, bool shouldScroll)
    signal navigateToAlbum(string name, bool shouldScroll)
    signal navigateToAll(bool shouldScroll)

    function rebuild() {
        var q = query.trim()
        if (q.length === 0) {
            results = []
            flatItems = []
            selectedIndex = 0
            return
        }
        results = library.searchGrouped(q)
        rebuildFlat()
    }

    function rebuildFlat() {
        var flat = []
        for (var g = 0; g < results.length; g++) {
            var group = results[g]
            for (var i = 0; i < group.items.length; i++) {
                var item = group.items[i]
                flat.push({ kind: "container", groupIdx: g, itemIdx: i, data: item, groupType: group.type })
                for (var t = 0; t < item.tracks.length; t++) {
                    flat.push({ kind: "track", groupIdx: g, itemIdx: i, trackIdx: t, data: item.tracks[t], groupType: group.type })
                }
            }
        }
        flatItems = flat
        if (selectedIndex >= flat.length) selectedIndex = Math.max(0, flat.length - 1)
    }

    function moveSelection(delta) {
        if (flatItems.length === 0) return
        var n = selectedIndex + delta
        if (n < 0) n = 0
        if (n >= flatItems.length) n = flatItems.length - 1
        selectedIndex = n
        var item = resultsList.itemAtIndex(n)
        if (item) {
            var itemTop = item.y - resultsList.contentY
            var itemBottom = itemTop + item.height
            if (itemTop < 0) resultsList.positionViewAtIndex(n, ListView.Beginning)
            else if (itemBottom > resultsList.height) resultsList.positionViewAtIndex(n, ListView.End)
        } else {
            resultsList.positionViewAtIndex(n, ListView.Contain)
        }
    }

    function handleEnter() {
        if (selectedIndex < 0 || selectedIndex >= flatItems.length) return
        var it = flatItems[selectedIndex]
        var parentItem = results[it.groupIdx].items[it.itemIdx]
        if (it.kind === "track") {
            library.playTrackPath(it.data.path)
            if (it.groupType === "playlist") navigateToPlaylist(parentItem.id, parentItem.name, true)
            else if (it.groupType === "artist") navigateToArtist(parentItem.name, true)
            else if (it.groupType === "album") navigateToAlbum(parentItem.name, true)
            else if (it.groupType === "all") navigateToAll(true)
        } else {
            if (it.groupType === "playlist") navigateToPlaylist(it.data.id, it.data.name, false)
            else if (it.groupType === "artist") navigateToArtist(it.data.name, false)
            else if (it.groupType === "album") navigateToAlbum(it.data.name, false)
            else if (it.groupType === "all") navigateToAll(false)
        }
    }

    onIsActiveChanged: {
        if (isActive) {
            if (inputField.text !== tab.query) inputField.text = tab.query
            Qt.callLater(function() { inputField.forceActiveFocus() })
        }
    }

    onQueryChanged: searchDebounce.restart()

    Timer {
        id: searchDebounce
        interval: 120
        onTriggered: tab.rebuild()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 10
            color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
            border.color: inputField.activeFocus ? theme.primary : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 180 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10

                Icon {
                    glyph: "\ue8b6"
                    iconSize: 17
                    iconColor: theme.primary
                }

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    placeholderText: "Search tracks, playlists, artists, albums"
                    placeholderTextColor: theme.outline
                    color: theme.onBackground
                    font.pixelSize: 12
                    background: Item {}
                    selectByMouse: true
                    onTextChanged: tab.query = text

                    Keys.onDownPressed: { tab.moveSelection(1); event.accepted = true }
                    Keys.onUpPressed: { tab.moveSelection(-1); event.accepted = true }
                    Keys.onReturnPressed: { tab.handleEnter(); event.accepted = true }
                    Keys.onEnterPressed: { tab.handleEnter(); event.accepted = true }

                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: backHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.22)
                            : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                        opacity: inputField.text.length > 0 ? 1 : 0
                        scale: inputField.text.length > 0 ? 1.0 : 0.7
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                        Icon {
                            anchors.centerIn: parent
                            glyph: "\ue5c4"
                            iconSize: 14
                            iconColor: theme.onBackground
                            x: backHov.containsMouse ? -1 : 0
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: backHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: inputField.text.length > 0
                            onClicked: inputField.text = ""
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.03)
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
            border.width: 1
            clip: true

            Flickable {
                id: resultsList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                contentWidth: width
                contentHeight: itemsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 300
                maximumFlickVelocity: 8000

                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    policy: ScrollBar.AsNeeded
                    width: 10
                    z: 2
                    visible: resultsList.contentHeight > resultsList.height + 1
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 2.5
                        color: theme.outline
                        opacity: vbar.pressed ? 0.8 : (vbar.hovered ? 0.55 : 0.3)
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    background: Item {}
                }

                NumberAnimation {
                    id: resultsWheelAnim
                    target: resultsList
                    property: "contentY"
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    blocking: true
                    onWheel: (event) => {
                        const maxY = Math.max(0, resultsList.contentHeight - resultsList.height)
                        let dy = 0
                        if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                        else dy = (event.angleDelta.y / 120.0) * 140
                        const currentTarget = resultsWheelAnim.running ? resultsWheelAnim.to : resultsList.contentY
                        const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                        if (Math.abs(target - resultsList.contentY) < 0.5) {
                            event.accepted = true
                            return
                        }
                        resultsWheelAnim.stop()
                        resultsWheelAnim.from = resultsList.contentY
                        resultsWheelAnim.to = target
                        resultsWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - resultsList.contentY) * 1.2))
                        resultsWheelAnim.start()
                        event.accepted = true
                    }
                }

                Column {
                    id: itemsColumn
                    width: resultsList.width - 12
                    spacing: 2

                    Repeater {
                        model: tab.flatItems

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool isContainer: modelData.kind === "container"
                            readonly property bool isTrack: modelData.kind === "track"
                            readonly property bool isSelected: tab.selectedIndex === index
                            readonly property bool isHovered: rowHov.hovered
                            readonly property string typeLabel: modelData.groupType === "all"
                                ? "Track"
                                : (modelData.groupType === "playlist"
                                    ? "Playlist"
                                    : (modelData.groupType === "artist" ? "Artist" : "Album"))

                            width: itemsColumn.width
                            height: isContainer ? 38 : 32
                            radius: 8
                            color: isSelected
                                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                                : (isHovered
                                    ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                                    : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }

                            HoverHandler {
                                id: rowHov
                                cursorShape: Qt.PointingHandCursor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tab.selectedIndex = index
                                    tab.handleEnter()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: isContainer ? 10 : 26
                                anchors.rightMargin: 10
                                spacing: 10

                                Icon {
                                    visible: row.isContainer
                                    glyph: row.modelData.groupType === "all"
                                        ? "\ue8f7"
                                        : (row.modelData.groupType === "playlist"
                                            ? "\ue8ef"
                                            : (row.modelData.groupType === "artist" ? "\ue7fd" : "\ue02b"))
                                    iconSize: 15
                                    iconColor: isSelected ? theme.primary : theme.outline
                                    filled: isSelected
                                    Behavior on iconColor { ColorAnimation { duration: 160 } }
                                }

                                Item {
                                    visible: row.isTrack
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: theme.surfaceVariant
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: row.isTrack && row.modelData.data.thumb
                                            ? library.toFileUrl(row.modelData.data.thumb) + "?v=" + library.coverVersion
                                            : ""
                                        sourceSize.width: 44
                                        sourceSize.height: 44
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        visible: status === Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.isContainer ? row.modelData.data.name : row.modelData.data.title
                                        color: isSelected
                                            ? theme.primary
                                            : (row.isContainer ? theme.onSurface : theme.onBackground)
                                        font.pixelSize: row.isContainer ? 12 : 11
                                        font.weight: row.isContainer ? Font.DemiBold : Font.Medium
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: row.isTrack
                                        text: row.isTrack ? row.modelData.data.artist : ""
                                        color: theme.outline
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: row.isContainer
                                    text: row.typeLabel
                                    color: theme.outline
                                    font.pixelSize: 10
                                    opacity: 0.6
                                }

                                Text {
                                    visible: row.isTrack
                                    text: row.isTrack ? library.formatDuration(row.modelData.data.duration) : ""
                                    color: theme.outline
                                    font.pixelSize: 9
                                    font.family: "monospace"
                                    Layout.preferredWidth: 36
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

                Connections {
                    target: tab
                    function onQueryChanged() { contentFadeOutAnim.start() }
                    function onFlatItemsChanged() { contentFadeInAnim.start() }
                }

                NumberAnimation {
                    id: contentFadeOutAnim
                    target: itemsColumn
                    property: "opacity"
                    to: 0.15
                    duration: 100
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: contentFadeInAnim
                    target: itemsColumn
                    property: "opacity"
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                }


            Text {
                anchors.centerIn: parent
                visible: tab.flatItems.length === 0
                text: tab.query.trim().length === 0
                    ? "Search tracks, playlists, artists, albums"
                    : "No results"
                color: theme.outline
                font.pixelSize: 12
                opacity: 0.6
            }
        }
    }
}
