import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: playlistRoot

    signal backRequested
    signal trackActivated

    readonly property color tipText: theme.onBackground

    property bool   addMenuOpen: false
    property string addMenuPath: ""
    property real   addMenuAnchorContentY: 0
    property real   addMenuAnchorOffset: 0

    function openAddMenu(path, rightX, anchorContentY, btnHeight) {
        if (addMenuOpen && addMenuPath === path) {
            closeAddMenu()
            return
        }

        addMenuPath = path
        addMenuAnchorContentY = anchorContentY

        const ow = Overlay.overlay ? Overlay.overlay.width  : 800
        const oh = Overlay.overlay ? Overlay.overlay.height : 600
        const mw = 240
        const mh = addMenuRect.contentH

        const listTopInOverlay = list.mapToItem(Overlay.overlay, 0, 0).y
        const btnWindowY = listTopInOverlay + anchorContentY - list.contentY

        let offset = btnHeight + 4
        if (btnWindowY + offset + mh > oh - 12) {
            const above = -mh - 8
            if (btnWindowY + above >= 12) offset = above
            else offset = Math.max(12 - btnWindowY, oh - mh - 12 - btnWindowY)
        }

        addMenuAnchorOffset = offset
        addMenuRect.x = Math.max(12, Math.min(rightX - mw, ow - mw - 12))

        if (sortPopup.shown) sortPopup.shown = false

        addMenuOpen = true
    }

    function closeAddMenu() {
        addMenuOpen = false
    }

    function closeSort() {
        if (sortPopup.shown) sortPopup.shown = false
    }

    Shortcut {
        sequence: "Escape"
        enabled: playlistRoot.addMenuOpen
        onActivated: playlistRoot.closeAddMenu()
    }

    Rectangle {
        id: addMenuScrim
        parent: Overlay.overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0.01
        opacity: playlistRoot.addMenuOpen ? 1 : 0
        z: 9998
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: playlistRoot.closeAddMenu()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }
    }

    Rectangle {
        id: addMenuRect
        parent: Overlay.overlay

        readonly property real contentH: addMenuCol.implicitHeight + 16

        width: 240
        height: Math.min(contentH, (parent ? parent.height : 600) - 24)
        radius: 14
        color: theme.surface
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.20)
        border.width: 1
        z: 9999
        transformOrigin: Item.TopRight

        visible: opacity > 0.01
        opacity: playlistRoot.addMenuOpen ? 1 : 0
        scale: playlistRoot.addMenuOpen ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        y: {
            if (!parent) return 0
            const listTopInOverlay = list.mapToItem(Overlay.overlay, 0, 0).y
            return listTopInOverlay + playlistRoot.addMenuAnchorContentY
                   - list.contentY + playlistRoot.addMenuAnchorOffset
        }

        onVisibleChanged: if (!visible) newNameField.text = ""

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: (mouse) => mouse.accepted = true
        }

        function submitNew() {
            const name = newNameField.text.trim()
            if (name.length === 0) return
            library.createPlaylistWithTrack(name, playlistRoot.addMenuPath)
            playlistRoot.closeAddMenu()
        }

        Flickable {
            id: addMenuFlick
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: addMenuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: addMenuCol
                width: addMenuFlick.width
                spacing: 4

                TextField {
                    id: newNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    placeholderText: "New playlist…"
                    placeholderTextColor: theme.outline
                    color: theme.onBackground
                    font.pixelSize: 12
                    leftPadding: 10
                    rightPadding: 10
                    selectByMouse: true

                    background: Rectangle {
                        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
                        radius: 8
                        border.color: newNameField.activeFocus ? theme.primary : "transparent"
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                    }

                    onAccepted: addMenuRect.submitNew()
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    Layout.preferredHeight: 1
                    color: theme.outline
                    opacity: 0.15
                    visible: library.playlists.length > 0
                }

                Repeater {
                    model: library.playlists

                    delegate: Rectangle {
                        id: plItem
                        required property string playlistId
                        required property string playlistName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: "transparent"

                        readonly property bool alreadyIn:
                            library.isPathInPlaylist(plItem.playlistId, playlistRoot.addMenuPath)

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: theme.onSurface
                            opacity: plItemHov.hovered ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: plItem.playlistName
                                color: theme.onBackground
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                visible: plItem.alreadyIn
                                glyph: plItem.alreadyIn ? "\ue5ca" : ""
                                iconSize: 13
                                iconColor: theme.primary
                            }
                        }

                        HoverHandler { id: plItemHov; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            onTapped: {
                                if (plItem.alreadyIn) {
                                    library.removeTrackFromPlaylist(
                                        plItem.playlistId,
                                        library.playlistIndexOf(plItem.playlistId, playlistRoot.addMenuPath))
                                } else {
                                    library.addTrackToPlaylist(plItem.playlistId, playlistRoot.addMenuPath)
                                }
                                playlistRoot.closeAddMenu()
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    visible: library.filterArtist.length > 0 || library.filterAlbum.length > 0
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: Qt.rgba(1, 1, 1, backHov.containsMouse ? 0.20 : 0.10)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\ue5c4"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: "white"
                        renderType: Text.NativeRendering
                        font.variableAxes: ({
                            "FILL": 0,
                            "wght": 400,
                            "GRAD": 0,
                            "opsz": 24
                        })
                        x: backHov.containsMouse ? -2 : 0
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: backHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            library.clearFilter()
                            playlistRoot.backRequested()
                        }
                    }
                }

                Text {
                    visible: library.filterArtist.length > 0 || library.filterAlbum.length > 0
                    Layout.alignment: Qt.AlignVCenter
                    text: library.filterAlbum.length > 0
                        ? library.filterAlbum.toUpperCase()
                        : library.filterArtist.toUpperCase()
                    color: theme.primary
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }

                Item { Layout.fillWidth: true }

                Item {
                    id: reorderBtnSlot
                    Layout.preferredWidth: (library.filterArtist === "" && library.filterAlbum === "") ? 30 : 0
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter

                    visible: library.filterArtist === "" && library.filterAlbum === ""

                    opacity: (library.trackCount > 0
                              && library.sortField === "custom"
                              && !library.showOnlyLiked
                              && library.filterText === "") ? 1 : 0
                    scale: opacity

                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.8
                        }
                    }

                    Rectangle {
                        id: reorderBtn
                        anchors.fill: parent
                        radius: 8
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: library.editMode ? theme.primary : theme.onSurface
                            opacity: library.editMode
                                ? 0.22
                                : (reorderHov.containsMouse ? 0.22 : 0.10)
                            border.color: library.editMode ? theme.primary : "transparent"
                            border.width: 1
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue25d"
                            iconSize: 18
                            iconColor: library.editMode ? theme.primary : theme.onBackground
                            scale: reorderHov.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.5
                                }
                            }
                        }

                        MouseArea {
                            id: reorderHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: library.toggleReorderMode()
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: reorderTipText.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: theme.surface
                        border.color: theme.outline
                        border.width: 1
                        opacity: reorderHov.containsMouse ? 1 : 0
                        visible: opacity > 0
                        z: 9999
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            id: reorderTipText
                            anchors.centerIn: parent
                            text: library.editMode
                                ? "Exit edit mode (Ctrl+Shift+E)"
                                : "Edit mode (Ctrl+Shift+E)"
                            color: playlistRoot.tipText
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }

                Item {
                    id: sortBtnSlot
                    Layout.preferredWidth: (library.filterArtist === "" && library.filterAlbum === "") ? 30 : 0
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter

                    visible: library.filterArtist === "" && library.filterAlbum === ""

                    opacity: library.trackCount > 0 ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: sortBtn
                        anchors.fill: parent
                        radius: 8
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: sortPopup.shown ? theme.primary : theme.onSurface
                            opacity: sortPopup.shown
                                ? 0.22
                                : (sortHov.containsMouse ? 0.22 : 0.10)
                            border.color: sortPopup.shown ? theme.primary : "transparent"
                            border.width: 1
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue8d5"
                            iconSize: 18
                            iconColor: sortPopup.shown ? theme.primary : theme.onBackground
                            scale: sortHov.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.5
                                }
                            }
                        }

                        MouseArea {
                            id: sortHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (sortPopup.shown) {
                                    sortPopup.shown = false
                                } else {
                                    sortPopup.reposition(sortBtnSlot)
                                    sortPopup.shown = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: sortTipText.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: theme.surface
                        border.color: theme.outline
                        border.width: 1
                        opacity: sortHov.containsMouse && !sortPopup.shown ? 1 : 0
                        visible: opacity > 0
                        z: 9999
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            id: sortTipText
                            anchors.centerIn: parent
                            text: "Sort options"
                            color: playlistRoot.tipText
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Row {
                id: chipsRow
                anchors.centerIn: parent
                spacing: 8
                z: 50

                visible: library.filterArtist.length === 0
                      && library.filterAlbum.length === 0
                      && (library.trackCount > 0
                          || library.likedCount > 0
                          || library.showOnlyLiked)

                Item {
                    id: allChip
                    readonly property bool active: !library.showOnlyLiked
                    width: allLabel.implicitWidth + 16
                    height: 34

                    Text {
                        id: allLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -2
                        text: "All"
                        color: allChip.active ? theme.primary : theme.onBackground
                        opacity: allChip.active ? 1.0 : 0.6
                        font.pixelSize: 12
                        font.weight: allChip.active ? Font.DemiBold : Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: allChip.active ? allLabel.implicitWidth + 12 : 0
                        height: 2
                        radius: 1
                        color: theme.primary
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler {
                        id: allChipHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: library.showOnlyLiked = false
                    }
                }

                Item {
                    id: likedChip
                    readonly property bool active: library.showOnlyLiked
                    width: likedTabRow.implicitWidth + 20
                    height: 34

                    Row {
                        id: likedTabRow
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        spacing: 7

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "\ue87d"
                            iconSize: 15
                            filled: likedChip.active
                            iconColor: likedChip.active ? theme.primary : theme.outline
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Liked"
                            color: likedChip.active ? theme.primary : theme.onBackground
                            opacity: likedChip.active ? 1.0 : 0.6
                            font.pixelSize: 12
                            font.weight: likedChip.active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: likedChip.active ? likedTabRow.implicitWidth + 12 : 0
                        height: 2
                        radius: 1
                        color: theme.primary
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler {
                        id: likedChipHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: library.showOnlyLiked = true
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: library.trackCount === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    glyph: library.showOnlyLiked ? "\ue87d" : "\ue2c7"
                    iconSize: 56
                    iconColor: theme.outline
                    opacity: 0.5
                    filled: library.showOnlyLiked
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: library.showOnlyLiked ? "No liked tracks" : "No library"
                    color: theme.onSurface
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: library.showOnlyLiked
                        ? (library.likedCount === 0
                            ? "Press Ctrl+W or middle-click on a track to add it here"
                            : "Nothing matches the current filters")
                        : "Press Ctrl+O to select a folder"
                    color: theme.outline
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: library.trackCount > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.DragOverBounds
            boundsMovement: Flickable.StopAtBounds
            cacheBuffer: 200
            reuseItems: false
            flickDeceleration: 500
            maximumFlickVelocity: 8000

            property int  dragIndex: -1
            property int  dropIndex: -1
            property real lastMouseY: 0
            property real handleW: (library.editMode
                                    && library.filterArtist === ""
                                    && library.filterAlbum === ""
                                    && library.filterText === ""
                                    && !library.showOnlyLiked) ? 18 : 0

            Behavior on handleW {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            model: library.tracks

            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: ScrollBar.AsNeeded
                width: 10

                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: theme.outline
                    opacity: vbar.pressed ? 0.8 : (vbar.hovered ? 0.55 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                background: Item {}
            }

            function resetScrollAndFade() {
                list.opacity = 0
                Qt.callLater(function() {
                    list.contentY = 0
                    list.positionViewAtBeginning()
                    list.forceLayout()
                    listFadeIn.restart()
                })
            }

            Connections {
                target: library
                function onSortChanged() { list.resetScrollAndFade() }
                function onShowOnlyLikedChanged() { list.resetScrollAndFade() }
                function onFilterTextChanged() { list.resetScrollAndFade() }
                function onFilterArtistChanged() { list.resetScrollAndFade() }
                function onFilterAlbumChanged() { list.resetScrollAndFade() }
            }

            NumberAnimation {
                id: listFadeIn
                target: list
                property: "opacity"
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: wheelAnim
                target: list
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, list.contentHeight - list.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) {
                        dy = event.pixelDelta.y * 3.5
                    } else {
                        dy = (event.angleDelta.y / 120.0) * 140
                    }

                    const currentTarget = wheelAnim.running ? wheelAnim.to : list.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))

                    wheelAnim.stop()
                    wheelAnim.from = list.contentY
                    wheelAnim.to = target
                    wheelAnim.duration = Math.min(
                        550,
                        Math.max(240, Math.abs(target - list.contentY) * 1.2)
                    )
                    wheelAnim.start()
                    event.accepted = true
                }
            }

            Timer {
                id: autoScrollTimer
                interval: 16
                repeat: true
                running: false

                onTriggered: {
                    const edge = 70
                    const maxSpeed = 16
                    let step = 0

                    if (list.lastMouseY < edge) {
                        step = -(maxSpeed * (1 - list.lastMouseY / edge))
                    } else if (list.lastMouseY > list.height - edge) {
                        step = maxSpeed * (1 - (list.height - list.lastMouseY) / edge)
                    }

                    if (Math.abs(step) > 0.5) {
                        const maxY = Math.max(0, list.contentHeight - list.height)
                        const target = Math.max(0, Math.min(maxY, list.contentY + step))
                        list.contentY = target

                        if (list.dragIndex >= 0) {
                            const contentY = list.lastMouseY + list.contentY
                            const stride = 42 + list.spacing
                            let idx = Math.floor(contentY / stride)
                            idx = Math.max(0, Math.min(library.tracks.count - 1, idx))
                            if (idx !== list.dropIndex) list.dropIndex = idx
                        }
                    }
                }
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: 300; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"; from: -60; to: 0
                    duration: 360; easing.type: Easing.OutCubic
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"; to: 0
                    duration: 220; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"; to: -60
                    duration: 300; easing.type: Easing.OutCubic
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 260; easing.type: Easing.OutCubic
                }
            }

            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 320; easing.type: Easing.OutCubic
                }
            }

            delegate: Rectangle {
                id: row

                required property int index
                required property string title
                required property string artist
                required property string thumb
                required property real duration

                readonly property bool canDrag: library.editMode
                    && library.filterArtist === ""
                    && library.filterAlbum === ""
                    && library.filterText === ""
                    && !library.showOnlyLiked

                readonly property bool isCurrent: library.currentFilePath === library.tracks.pathAt(row.index)
                readonly property bool isDragging: list.dragIndex === row.index
                readonly property bool isDropTargetAbove: list.dropIndex === row.index
                                   && list.dragIndex > row.index
                                   && list.dragIndex !== row.index
                readonly property bool isDropTargetBelow: list.dropIndex === row.index
                                   && list.dragIndex < row.index
                                   && list.dragIndex !== row.index

                readonly property bool liked: {
                    library.likedRevision
                    return library.isLiked(row.index)
                }

                HoverHandler { id: rowHover }

                width: list.width
                height: 42
                radius: 10
                color: "transparent"

                opacity: isDragging ? 0.35 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                MouseArea {
                    id: hov4
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: row.canDrag
                        ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                        : Qt.PointingHandCursor
                    preventStealing: row.canDrag

                    onClicked: (mouse) => {
                        if (row.canDrag) return

                        if (mouse.button === Qt.MiddleButton) {
                            library.toggleLike(row.index)
                            return
                        }

                        if (row.isCurrent) {
                            library.togglePlayPause()
                        } else {
                            library.playIndex(row.index)
                        }
                        if (window.floatingSearchOpen) window.closeFloatingSearch()
                        playlistRoot.trackActivated()
                    }

                    onPressed: (mouse) => {
                        if (!row.canDrag) return
                        if (mouse.button !== Qt.LeftButton) return
                        const pt = hov4.mapToItem(list, mouse.x, mouse.y)
                        list.dragIndex = row.index
                        list.dropIndex = row.index
                        list.lastMouseY = pt.y
                        autoScrollTimer.start()
                    }

                    onPositionChanged: (mouse) => {
                        if (!row.canDrag || list.dragIndex < 0) return
                        const pt = hov4.mapToItem(list, mouse.x, mouse.y)
                        list.lastMouseY = pt.y
                        const contentY = pt.y + list.contentY
                        const stride = row.height + list.spacing
                        let idx = Math.floor(contentY / stride)
                        idx = Math.max(0, Math.min(library.tracks.count - 1, idx))
                        if (idx !== list.dropIndex) list.dropIndex = idx
                    }

                    onReleased: {
                        autoScrollTimer.stop()
                        if (!row.canDrag) {
                            list.dragIndex = -1
                            list.dropIndex = -1
                            return
                        }
                        if (list.dragIndex >= 0
                            && list.dropIndex >= 0
                            && list.dragIndex !== list.dropIndex) {
                            library.moveTrack(list.dragIndex, list.dropIndex)
                        }
                        list.dragIndex = -1
                        list.dropIndex = -1
                    }

                    onCanceled: {
                        autoScrollTimer.stop()
                        list.dragIndex = -1
                        list.dropIndex = -1
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 22
                    height: 2
                    radius: 1
                    color: theme.primary

                    y: row.isDropTargetAbove ? 0
                       : row.isDropTargetBelow ? parent.height - 2
                       : 0

                    visible: row.isDropTargetAbove || row.isDropTargetBelow
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 20
                    radius: parent.radius
                    color: theme.onSurface
                    opacity: (rowHover.hovered && !row.canDrag) ? 0.06 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 20
                    radius: parent.radius
                    color: theme.primary
                    opacity: row.isCurrent ? 0.10 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    width: 3
                    height: row.isCurrent ? 18 : 0
                    radius: 2
                    color: theme.primary
                    Behavior on height {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 30
                    spacing: 10

                    Item {
                        Layout.preferredWidth: row.canDrag ? 18 : 0
                        Layout.preferredHeight: 18
                        clip: true
                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue25d"
                            iconSize: 16
                            iconColor: theme.outline
                            opacity: row.canDrag ? 1 : 0
                            scale: row.canDrag ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.0
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: theme.surfaceVariant
                        }

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: row.thumb ? library.toFileUrl(row.thumb) + "?v=" + library.coverVersion : ""
                            sourceSize.width: 30
                            sourceSize.height: 30
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            smooth: false
                            visible: status === Image.Ready
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue405"
                            iconSize: 14
                            iconColor: theme.outline
                            visible: !row.thumb || thumbImg.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "#000"
                            opacity: (rowHover.hovered && !row.canDrag) ? 0.5 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            MaterialIcon {
                                anchors.centerIn: parent
                                glyph: row.isCurrent && library.isPlaying ? "\ue034" : "\ue037"
                                iconSize: 14
                                iconColor: "white"
                                opacity: rowHover.hovered ? 1 : 0
                                scale: rowHover.hovered ? 1.0 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 2.5
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: likeBadge
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: -4
                            anchors.topMargin: -4
                            width: 14
                            height: 14
                            radius: 7
                            color: theme.surface

                            opacity: row.liked ? 1 : 0
                            scale: row.liked ? 1.0 : 0.3
                            rotation: row.liked ? 0 : -30

                            Behavior on opacity {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 340
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 3.5
                                }
                            }
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 340
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.5
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                width: 11
                                height: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                glyph: "\ue87d"
                                iconSize: 11
                                filled: true
                                iconColor: theme.primary
                                anchors.horizontalCenterOffset: 0.5
                                anchors.verticalCenterOffset: 0.7
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            id: rowTitle
                            Layout.fillWidth: true
                            text: row.title
                            color: row.isCurrent ? theme.primary : theme.onSurface
                            font.pixelSize: 12
                            font.weight: row.isCurrent ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                            transformOrigin: Item.Left
                            scale: row.isCurrent ? 1.08 : 1.0
                            Behavior on color { ColorAnimation { duration: 220 } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.artist
                            color: theme.outline
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: library.formatDuration(row.duration)
                        color: theme.outline
                        font.pixelSize: 10
                        font.family: "monospace"
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }

                    Item {
                        id: addBtnSlot
                        Layout.preferredWidth: (rowHover.hovered && !row.canDrag) ? 22 : 0
                        Layout.preferredHeight: 22
                        Layout.rightMargin: 2
                        clip: true
                        Behavior on Layout.preferredWidth {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: theme.onSurface
                            opacity: addBtnHov.containsMouse ? 0.20 : 0.10
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue03b"
                            iconSize: 14
                            iconColor: theme.onBackground
                        }

                        MouseArea {
                            id: addBtnHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                library.requestCloseSearch()
                                const pOverlay = addBtnHov.mapToItem(Overlay.overlay, 0, 0)
                                const pContent = addBtnHov.mapToItem(list.contentItem, 0, 0)
                                playlistRoot.openAddMenu(library.tracks.pathAt(row.index),
                                                         pOverlay.x + addBtnHov.width,
                                                         pContent.y,
                                                         addBtnHov.height)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sortScrim
        parent: Overlay.overlay
        anchors.fill: parent
        color: "transparent"
        visible: opacity > 0.01
        enabled: sortPopup.shown
        opacity: sortPopup.shown ? 1 : 0
        z: 8990
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        HoverHandler { blocking: true }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: sortPopup.shown = false
        }
    }

    Rectangle {
        id: sortPopup
        parent: Overlay.overlay
        property bool shown: false

        width: 220
        height: sortContent.implicitHeight + 12
        radius: 14
        color: theme.surface
        border.color: theme.outline
        border.width: 1
        z: 9000

        visible: opacity > 0.01
        enabled: shown
        opacity: shown ? 1 : 0
        scale: shown ? 1.0 : 0.95
        transformOrigin: Item.TopRight

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

        function reposition(slot) {
            if (!slot) return
            const p = slot.mapToItem(Overlay.overlay, slot.width, slot.height)
            const w = Overlay.overlay ? Overlay.overlay.width : 800
            x = Math.max(12, Math.min(p.x - width, w - width - 12))
            y = p.y + 6
        }

        HoverHandler { blocking: true }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }

        ColumnLayout {
            id: sortContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            Text {
                text: "SORT BY"
                color: theme.outline
                font.pixelSize: 9
                font.letterSpacing: 1.4
                Layout.leftMargin: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    { key: "custom",   label: "Custom" },
                    { key: "title",    label: "Title" },
                    { key: "artist",   label: "Artist" },
                    { key: "album",    label: "Album" },
                    { key: "duration", label: "Duration" },
                    { key: "path",     label: "File name" }
                ]

                delegate: Rectangle {
                    id: sortItem

                    required property var modelData

                    readonly property bool active: library.sortField === modelData.key
                    readonly property bool isCustom: modelData.key === "custom"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: theme.onSurface
                        opacity: sortItemHov.containsMouse ? 0.08 : (sortItem.active ? 0.06 : 0)
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        visible: sortItem.isCustom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: sortItem.active ? theme.primary : theme.outline
                        opacity: sortItem.active ? 1 : 0.4
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: sortItem.modelData.label
                            color: sortItem.active ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: sortItem.active ? Font.DemiBold : Font.Normal
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            visible: sortItem.active && !sortItem.isCustom
                            glyph: library.sortAscending ? "\ue5d8" : "\ue5db"
                            iconSize: 14
                            iconColor: theme.primary
                            opacity: sortItem.active ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            visible: sortItem.active && sortItem.isCustom
                            glyph: "\ue25d"
                            iconSize: 14
                            iconColor: theme.primary
                        }
                    }

                    MouseArea {
                        id: sortItemHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sortItem.isCustom) {
                                library.applySort("custom", true)
                                sortPopup.shown = false
                            } else if (sortItem.active) {
                                library.applySort(sortItem.modelData.key, !library.sortAscending)
                            } else {
                                library.applySort(sortItem.modelData.key, true)
                            }
                        }
                    }
                }
            }
        }
    }
}