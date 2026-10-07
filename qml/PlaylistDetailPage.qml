import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: page

    signal backRequested
    signal playlistActivated

    property string playlistId: ""
    property string playlistName: ""
    property bool   pendingRemoveCover: false

    readonly property bool showCover: page.height > 340

    readonly property bool hasCover: {
        library.coverVersion
        return library.playlistCover(page.playlistId) !== ""
    }

    FileDialog {
        id: coverDialog
        title: "Select playlist cover"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp)"]
        onAccepted: {
            library.setPlaylistCover(page.playlistId, selectedFile.toString())
            page.pendingRemoveCover = false
        }
    }

    FileDialog {
        id: saveCoverDialog
        title: "Save playlist cover"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "jpg"
        nameFilters: ["JPEG (*.jpg *.jpeg)", "PNG (*.png)", "WebP (*.webp)"]

        readonly property string suggestedName: {
            const s = String(page.playlistName || "playlist")
            return s.replace(/[\\/:*?"<>|]/g, "_") + ".jpg"
        }

        onVisibleChanged: if (visible) currentFile = suggestedName

        onAccepted: {
            let p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            library.savePlaylistCoverTo(page.playlistId, p)
        }
    }

    component CoverBtn: Item {
        id: cb
        width: 40
        height: 30

        property string glyph: ""
        property string tip: ""
        property bool danger: false
        property bool confirming: false
        property bool active: false
        signal clicked

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: cb.confirming
                ? Qt.rgba(0.75, 0.22, 0.17, 0.28)
                : cb.active
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                    : (cbHover.hovered && cb.enabled
                        ? (cb.danger
                            ? Qt.rgba(0.9, 0.35, 0.35, 0.22)
                            : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22))
                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
            border.color: cb.active
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.55)
                : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b,
                          (cbHover.hovered && cb.enabled) ? 0.35 : 0.18)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            MaterialIcon {
                anchors.centerIn: parent
                glyph: cb.glyph
                iconSize: 15
                iconColor: cb.confirming
                    ? "#e57373"
                    : cb.active
                        ? theme.primary
                        : (cb.danger && cbHover.hovered && cb.enabled ? "#e57373" : theme.onBackground)
                Behavior on iconColor { ColorAnimation { duration: 200 } }
            }
        }

        HoverHandler {
            id: cbHover
            enabled: cb.enabled
            cursorShape: cb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: cb.enabled
            onTapped: cb.clicked()
        }

        Rectangle {
            id: tooltipRect
            parent: Overlay.overlay
            width: label2.implicitWidth + 16
            height: 24
            radius: 8
            color: theme.surface
            border.color: theme.outline
            border.width: 1
            z: 99999
            visible: opacity > 0.01
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            property real anchorX: 0
            property real anchorY: 0
            x: anchorX - width / 2
            y: anchorY

            Text {
                id: label2
                anchors.centerIn: parent
                text: cb.tip
                color: theme.onSurface
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Connections {
                target: cbHover
                function onHoveredChanged() {
                    if (cbHover.hovered && cb.tip.length > 0 && cb.enabled) {
                        const p = cb.mapToItem(Overlay.overlay, cb.width / 2, cb.height + 6)
                        if (p) {
                            tooltipRect.anchorX = p.x
                            tooltipRect.anchorY = p.y
                        }
                        tooltipRect.opacity = 1
                    } else {
                        tooltipRect.opacity = 0
                    }
                }
            }
        }
    }

    component CoverButtonsRow: Row {
        id: cbr
        spacing: 6

        Item {
            id: editGroup
            width: library.editMode ? innerRow.implicitWidth : 0
            height: 30
            clip: true
            Behavior on width {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            Row {
                id: innerRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                CoverBtn {
                    glyph: "\ue3f4"
                    tip: "Add cover"
                    enabled: library.editMode
                    onClicked: {
                        if (page.pendingRemoveCover) page.pendingRemoveCover = false
                        coverDialog.open()
                    }
                }

                CoverBtn {
                    glyph: "\ue2c4"
                    tip: "Save cover"
                    enabled: library.editMode && page.hasCover
                    visible: page.hasCover
                    onClicked: saveCoverDialog.open()
                }

                CoverBtn {
                    glyph: page.pendingRemoveCover ? "\ue8f4" : "\ue872"
                    tip: page.pendingRemoveCover ? "Cancel remove" : "Remove cover"
                    danger: true
                    confirming: page.pendingRemoveCover
                    enabled: library.editMode && page.hasCover
                    visible: page.hasCover
                    onClicked: page.pendingRemoveCover = !page.pendingRemoveCover
                }

                Rectangle {
                    width: 1
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.outline
                    opacity: 0.3
                }
            }
        }

        CoverBtn {
            id: editBtn
            glyph: library.editMode ? "\ue5ca" : "\ue3c9"
            tip: library.editMode ? "Exit edit mode" : "Edit mode"
            active: library.editMode
            onClicked: library.toggleReorderMode()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 8
                color: backHov.containsMouse
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                Behavior on color { ColorAnimation { duration: 180 } }

                scale: backHov.pressed ? 0.9 : (backHov.containsMouse ? 1.06 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue5c4"
                    iconSize: 15
                    iconColor: "white"
                    x: backHov.containsMouse ? -1 : 0
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: backHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.backRequested()
                }
            }

            Text {
                text: "PLAYLIST"
                color: theme.outline
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            spacing: 14

            Item {
                id: coverBox
                Layout.preferredWidth: page.showCover ? 110 : 0
                Layout.preferredHeight: page.showCover ? 110 : 0
                Layout.alignment: Qt.AlignTop
                clip: true
                opacity: page.showCover ? 1 : 0
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: theme.surfaceVariant
                    visible: detailCover.status !== Image.Ready
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue8ef"
                    iconSize: 44
                    iconColor: theme.outline
                    opacity: 0.5
                    visible: detailCover.status !== Image.Ready
                }

                Image {
                    id: detailCover
                    anchors.fill: parent
                    source: {
                        library.coverVersion
                        return library.playlistCover(page.playlistId)
                    }
                    sourceSize.width: 220
                    sourceSize.height: 220
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "#000"
                    opacity: page.pendingRemoveCover ? 0.55 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            glyph: "\ue872"
                            iconSize: 22
                            iconColor: "white"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Will be removed"
                            color: "white"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Item {
                id: headerBlock
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: page.showCover
                    ? (nameCol.implicitHeight + 10 + buttonsRow.height + 4)
                    : Math.max(nameCol.implicitHeight, buttonsRow.height)

                ColumnLayout {
                    id: nameCol
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: page.showCover
                        ? parent.width
                        : Math.max(0, parent.width - buttonsRow.width - 12)
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: page.playlistName
                        color: theme.onBackground
                        font.pixelSize: page.showCover ? 20 : 17
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Behavior on font.pixelSize {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        text: library.activePlaylistTrackCount
                              + (library.activePlaylistTrackCount === 1 ? " track" : " tracks")
                        color: theme.outline
                        font.pixelSize: 11
                    }
                }

                CoverButtonsRow {
                    id: buttonsRow
                    x: headerBlock.width - width
                    y: page.showCover
                        ? (nameCol.implicitHeight + 10)
                        : Math.round((nameCol.implicitHeight - height) / 2)
                    Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 6
            Layout.bottomMargin: 2
            color: theme.outline
            opacity: 0.15
        }

        ListView {
            id: trackList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.DragOverBounds
            boundsMovement: Flickable.StopAtBounds
            cacheBuffer: 300
            reuseItems: false
            model: library.playlistTracks

            property int dragIndex: -1
            property int dropIndex: -1
            property real _bottomComp: 0

            bottomMargin: _bottomComp

            NumberAnimation {
                id: bottomCompAnim
                target: trackList
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
                trackList._bottomComp = trackList._bottomComp + stride

                removalFn()

                bottomCompAnim.from = trackList._bottomComp
                bottomCompAnim.to   = 0
                bottomCompAnim.restart()
            }

            NumberAnimation {
                id: trackWheel
                target: trackList
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, trackList.contentHeight - trackList.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                    else dy = (event.angleDelta.y / 120.0) * 140
                    const currentTarget = trackWheel.running ? trackWheel.to : trackList.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    trackWheel.stop()
                    trackWheel.from = trackList.contentY
                    trackWheel.to = target
                    trackWheel.duration = Math.min(550, Math.max(240, Math.abs(target - trackList.contentY) * 1.2))
                    trackWheel.start()
                    event.accepted = true
                }
            }

            Text {
                anchors.centerIn: parent
                text: library.filterText.length > 0
                    ? "No matches"
                    : "Empty playlist\nClick + on tracks in Home to add them"
                color: theme.outline
                opacity: 0.5
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                visible: trackList.count === 0
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

            delegate: PlaylistTrackRow {
                listView: trackList
                onActivated: page.playlistActivated()
                onTrackRemovalRequested: (removalFn) => {
                    trackList.removeWithSmoothScroll(removalFn)
                }
            }
        }
    }
}