import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: page

    signal backRequested
    signal trackActivated

    readonly property color tipText: theme.onBackground
    readonly property bool filtered: library.filterArtist.length > 0 || library.filterAlbum.length > 0

    function openAddMenu(path, rightX, anchorContentY, btnHeight) {
        addMenu.open(path, rightX, anchorContentY, btnHeight, list)
    }
    function closeAddMenu() { addMenu.close() }
    function closeSort()    { sortMenu.close() }

    function deleteCurrentLikedTrack() {
        const path = library.currentFilePath
        if (path.length === 0) return
        for (let i = 0; i < library.tracks.count; ++i) {
            if (library.tracks.pathAt(i) === path) {
                list.removeWithSmoothScroll(function() {
                    library.toggleLikeByPath(path)
                })
                return
            }
        }
        library.toggleCurrentLike()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 10
            z: 100

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16)
                Behavior on color { ColorAnimation { duration: 180 } }

                scale: headerHov.pressed && page.filtered ? 0.92 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.5
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: page.filtered ? "\ue5c4" : "\ue8f7"
                    iconSize: 19
                    iconColor: theme.primary
                    filled: !page.filtered
                }

                MouseArea {
                    id: headerHov
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: page.filtered
                    cursorShape: page.filtered ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        library.clearFilter()
                        page.backRequested()
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: page.filtered
                        ? (library.filterAlbum.length > 0 ? "Album" : "Artist")
                        : "Library"
                    color: theme.onBackground
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    text: page.filtered
                        ? (library.filterAlbum.length > 0 ? library.filterAlbum : library.filterArtist)
                        : (library.trackCount + (library.trackCount === 1 ? " track" : " tracks"))
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.maximumWidth: 320
                }
            }

            Item { Layout.preferredWidth: 8 }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                visible: !page.filtered && (library.trackCount > 0 || library.likedCount > 0 || library.showOnlyLiked)
                spacing: 6

                Rectangle {
                    id: allChip
                    readonly property bool active: !library.showOnlyLiked
                    property real chipW: allLabel.implicitWidth + 24
                    Layout.preferredWidth: chipW
                    Layout.preferredHeight: 30
                    radius: 9
                    Behavior on chipW {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    color: active
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (allHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        id: allLabel
                        anchors.centerIn: parent
                        text: "All"
                        color: allChip.active ? theme.primary : theme.onBackground
                        font.pixelSize: 11
                        font.weight: allChip.active ? Font.DemiBold : Font.Medium
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: allHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: library.showOnlyLiked = false
                    }
                }

                Rectangle {
                    id: likedChip
                    readonly property bool active: library.showOnlyLiked
                    property real chipW: likedRow.implicitWidth + 22
                    Layout.preferredWidth: chipW
                    Layout.preferredHeight: 30
                    radius: 9
                    Behavior on chipW {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    color: active
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                        : (likedHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Row {
                        id: likedRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "\ue87d"
                            iconSize: 13
                            filled: likedChip.active
                            iconColor: likedChip.active ? theme.primary : theme.outline
                            Behavior on iconColor { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Liked"
                            color: likedChip.active ? theme.primary : theme.onBackground
                            font.pixelSize: 11
                            font.weight: likedChip.active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: likedHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: library.showOnlyLiked = true
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Item {
                id: reorderBtnSlot
                readonly property bool reorderAvailable: library.trackCount > 0
                    && library.sortField === "custom"
                    && !library.showOnlyLiked
                    && library.filterText === ""
                    && library.filterArtist === ""
                    && library.filterAlbum === ""

                Layout.preferredWidth: reorderAvailable ? 32 : 0
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                visible: Layout.preferredWidth > 0.5
                opacity: reorderAvailable ? 1 : 0
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: reorderBtn
                    anchors.fill: parent
                    radius: 10
                    color: library.editMode
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                        : (reorderHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                            : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05))
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue25d"
                        iconSize: 16
                        iconColor: library.editMode ? theme.primary : theme.onBackground
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
                    height: 26
                    radius: 8
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 1.0)
                    border.color: theme.outline
                    border.width: 1
                    opacity: reorderHov.containsMouse ? 1 : 0
                    visible: opacity > 0
                    z: 9999
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        id: reorderTipText
                        anchors.centerIn: parent
                        text: library.editMode ? "Exit edit mode" : "Edit mode"
                        color: page.tipText
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }
            }

            Item {
                id: sortBtnSlot
                readonly property bool shown: library.filterArtist === "" && library.filterAlbum === "" && library.trackCount > 0
                Layout.preferredWidth: shown ? 32 : 0
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                visible: Layout.preferredWidth > 0.5
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: sortBtn
                    anchors.fill: parent
                    radius: 10
                    color: sortMenu.shown
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                        : (sortHov.containsMouse
                            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                            : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05))
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue8d5"
                        iconSize: 16
                        iconColor: sortMenu.shown ? theme.primary : theme.onBackground
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
                    height: 26
                    radius: 8
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 1.0)
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
                        font.pixelSize: 10
                        font.weight: Font.Medium
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
                    font.pixelSize: 15
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
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: library.trackCount > 0
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.DragOverBounds
                boundsMovement: Flickable.StopAtBounds
                cacheBuffer: 2000
                reuseItems: false
                interactive: !library.editMode
                flickDeceleration: 500
                maximumFlickVelocity: 8000

                property int  dragIndex: -1
                property int  dropIndex: -1
                property real lastViewportX: 0
                property real lastViewportY: 0
                property real _bottomComp: 0

                bottomMargin: _bottomComp

                function computeDropFromCursor() {
                    if (dragIndex < 0) return
                    if (count === 0) { dropIndex = 0; return }

                    const vy = Math.max(0, Math.min(height - 1, lastViewportY))
                    const stride = 42 + spacing

                    if (vy < 14) {
                        const s = Math.floor((contentY - originY) / stride)
                        dropIndex = Math.max(0, Math.min(count, s))
                        return
                    }
                    if (vy > height - 14) {
                        const s = Math.ceil((contentY - originY + height) / stride)
                        dropIndex = Math.max(0, Math.min(count, s))
                        return
                    }

                    const cpt = vy + contentY - originY
                    const idx = Math.floor(cpt / stride)
                    const ly = cpt - idx * stride
                    let slot = (ly < 21) ? idx : idx + 1

                    if (slot < 0) slot = 0
                    if (slot > count) slot = count
                    if (slot !== dropIndex) dropIndex = slot
                }

                function removeWithSmoothScroll(removalFn) {
                    const stride = 42 + spacing
                    const yBefore = contentY
                    const hBefore = contentHeight
                    const nearBot = (yBefore + height >= hBefore - stride - 0.5)

                    if (!nearBot) { removalFn(); return }

                    bottomCompAnim.stop()
                    scrollCompAnim.stop()

                    list._bottomComp = list._bottomComp + stride
                    removalFn()

                    const targetY = Math.max(0, hBefore - stride - height)

                    if (Math.abs(list.contentY - targetY) > 0.5) {
                        scrollCompAnim.from = list.contentY
                        scrollCompAnim.to = targetY
                        scrollCompAnim.start()
                    }

                    bottomCompAnim.from = list._bottomComp
                    bottomCompAnim.to   = 0
                    bottomCompAnim.restart()
                }

                NumberAnimation {
                    id: bottomCompAnim
                    target: list
                    property: "_bottomComp"
                    to: 0
                    duration: 320
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: scrollCompAnim
                    target: list
                    property: "contentY"
                    duration: 320
                    easing.type: Easing.OutCubic
                }

                onContentYChanged: {
                    if (dragIndex >= 0) computeDropFromCursor()
                    if (dropOverlay && dropOverlay.active) {
                        dropOverlay.yArmed = false
                        Qt.callLater(function() {
                            if (dropOverlay) {
                                dropOverlay.lastY = dropOverlay.y
                                dropOverlay.yArmed = true
                            }
                        })
                    }
                }

                model: library.tracks

                HoverHandler {
                    enabled: library.editMode
                    cursorShape: list.dragIndex >= 0 ? Qt.ClosedHandCursor : Qt.OpenHandCursor
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
                        list._bottomComp = 0
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
                    function onEditModeChanged() {
                        if (!library.editMode) {
                            list.dragIndex = -1
                            list.dropIndex = -1
                        }
                    }
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
                        let dy = 0
                        if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                        else dy = (event.angleDelta.y / 120.0) * 140

                        const maxY = Math.max(0, list.originY + list.contentHeight - list.height)
                        const minY = list.originY

                        if (list.contentY > maxY) list.contentY = maxY
                        if (list.contentY < minY) list.contentY = minY

                        const currentTarget = wheelAnim.running ? wheelAnim.to : list.contentY
                        let target = currentTarget - dy
                        if (target > maxY) target = maxY
                        if (target < minY) target = minY

                        if (Math.abs(target - list.contentY) < 0.5) {
                            event.accepted = true
                            return
                        }

                        wheelAnim.stop()
                        wheelAnim.from = list.contentY
                        wheelAnim.to = target
                        wheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - list.contentY) * 1.2))
                        wheelAnim.start()
                        event.accepted = true
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
                    NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                }
                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                }

                delegate: TrackRow {
                    listView: list
                    onActivated: {
                        if (window.floatingSearchOpen) window.closeFloatingSearch()
                        page.trackActivated()
                    }
                    onAddMenuRequested: (path, rightX, anchorContentY, btnHeight) => {
                        page.openAddMenu(path, rightX, anchorContentY, btnHeight)
                    }
                    onTrackRemovalRequested: (removalFn) => {
                        if (library.showOnlyLiked) {
                            list.removeWithSmoothScroll(removalFn)
                        } else {
                            removalFn()
                        }
                    }
                }
            }

            Rectangle {
                id: dropOverlay
                z: 300
                x: 20
                width: list.width - 40
                height: 2
                radius: 1
                color: theme.primary

                readonly property bool active: list.dragIndex >= 0 && list.dropIndex >= 0
                readonly property real rawY: active
                    ? list.dropIndex * (42 + list.spacing) - (list.contentY - list.originY) - 1
                    : 0

                property real lastY: 0
                property bool yArmed: false

                y: {
                    if (!active) return lastY
                    if (rawY < 0) return 0
                    if (rawY > list.height - 2) return list.height - 2
                    return rawY
                }

                onYChanged: if (active && yArmed) lastY = y

                opacity: active ? 1 : 0

                onActiveChanged: {
                    if (active) {
                        dropOverlay.yArmed = false
                        Qt.callLater(function() {
                            dropOverlay.lastY = dropOverlay.y
                            dropOverlay.yArmed = true
                        })
                    } else {
                        dropOverlay.yArmed = false
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y {
                    enabled: dropOverlay.yArmed
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    TrackSortMenu     { id: sortMenu }
    AddToPlaylistMenu { id: addMenu }
}
