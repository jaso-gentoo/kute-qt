import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: page

    signal backRequested
    signal trackActivated

    readonly property color tipText: theme.onBackground

    function openAddMenu(path, rightX, anchorContentY, btnHeight) {
        addMenu.open(path, rightX, anchorContentY, btnHeight, list)
    }
    function closeAddMenu() { addMenu.close() }
    function closeSort()    { sortMenu.close() }

    function deleteCurrentLikedTrack() {
        list.deleteCurrentLikedTrack()
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
                        font.variableAxes: ({ "FILL": 0, "wght": 400, "GRAD": 0, "opsz": 24 })
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
                            page.backRequested()
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
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
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
                            opacity: library.editMode ? 0.22 : (reorderHov.containsMouse ? 0.22 : 0.10)
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
                                NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
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
                            color: page.tipText
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
                            color: sortMenu.shown ? theme.primary : theme.onSurface
                            opacity: sortMenu.shown ? 0.22 : (sortHov.containsMouse ? 0.22 : 0.10)
                            border.color: sortMenu.shown ? theme.primary : "transparent"
                            border.width: 1
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue8d5"
                            iconSize: 18
                            iconColor: sortMenu.shown ? theme.primary : theme.onBackground
                            scale: sortHov.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                            }
                        }

                        MouseArea {
                            id: sortHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (sortMenu.shown) sortMenu.close()
                                else sortMenu.show(sortBtnSlot)
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
                        opacity: sortHov.containsMouse && !sortMenu.shown ? 1 : 0
                        visible: opacity > 0
                        z: 9999
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            id: sortTipText
                            anchors.centerIn: parent
                            text: "Sort options"
                            color: page.tipText
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
                      && (library.trackCount > 0 || library.likedCount > 0 || library.showOnlyLiked)

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

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: library.showOnlyLiked = false }
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

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: library.showOnlyLiked = true }
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
            property real _bottomComp: 0

            model: library.tracks

            bottomMargin: _bottomComp

            NumberAnimation {
                id: bottomCompAnim
                target: list
                property: "_bottomComp"
                to: 0
                duration: 320
                easing.type: Easing.OutCubic
            }

            function removeWithSmoothScroll(removalFn) {
                const yBefore = contentY
                const hBefore = contentHeight
                const stride  = 42 + spacing
                const nearBot = (yBefore + height >= hBefore - stride - 0.5)

                if (!nearBot) {
                    removalFn()
                    return
                }

                bottomCompAnim.stop()
                list._bottomComp = list._bottomComp + stride

                removalFn()

                bottomCompAnim.from = list._bottomComp
                bottomCompAnim.to   = 0
                bottomCompAnim.restart()
            }

            function deleteCurrentLikedTrack() {
                const path = library.currentFilePath
                if (path.length === 0) return
                for (let i = 0; i < library.tracks.count; ++i) {
                    if (library.tracks.pathAt(i) === path) {
                        removeWithSmoothScroll(function() {
                            library.toggleLikeByPath(path)
                        })
                        return
                    }
                }
            }

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
                    if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                    else dy = (event.angleDelta.y / 120.0) * 140
                    const currentTarget = wheelAnim.running ? wheelAnim.to : list.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    wheelAnim.stop()
                    wheelAnim.from = list.contentY
                    wheelAnim.to = target
                    wheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - list.contentY) * 1.2))
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
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: -60; to: 0; duration: 360; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; to: -60; duration: 360; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 420; easing.type: Easing.OutCubic }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
            }

            delegate: TrackRow {
                listView: list
                autoScrollTimer: autoScrollTimer
                onActivated: {
                    if (window.floatingSearchOpen) window.closeFloatingSearch()
                    page.trackActivated()
                }
                onAddMenuRequested: (path, rightX, anchorContentY, btnHeight) => {
                    page.openAddMenu(path, rightX, anchorContentY, btnHeight)
                }
                onTrackRemovalRequested: (removalFn) => {
                    list.removeWithSmoothScroll(removalFn)
                }
            }
        }
    }

    TrackSortMenu     { id: sortMenu }
    AddToPlaylistMenu { id: addMenu }
}