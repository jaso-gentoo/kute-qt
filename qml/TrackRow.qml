import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: row

    required property int index
    required property string title
    required property string artist
    required property string thumb
    required property real duration
    required property string path

    property ListView listView
    property var autoScrollTimer

    signal activated()
    signal addMenuRequested(string path, real rightX, real anchorContentY, real btnHeight)
    signal trackRemovalRequested(var removalFn)

    readonly property string rowPath: path

    readonly property bool canDrag: library.editMode
        && library.filterArtist === ""
        && library.filterAlbum === ""
        && library.filterText === ""
        && !library.showOnlyLiked

    readonly property bool isCurrent: library.currentFilePath === rowPath
    readonly property bool isDragging: listView && listView.dragIndex === row.index
    readonly property bool isDropTargetAbove: listView
        && listView.dropIndex === row.index
        && listView.dragIndex > row.index
        && listView.dragIndex !== row.index
    readonly property bool isDropTargetBelow: listView
        && listView.dropIndex === row.index
        && listView.dragIndex < row.index
        && listView.dragIndex !== row.index

    readonly property bool liked: {
        library.likedRevision
        return library.isLiked(row.index)
    }

    HoverHandler { id: rowHover }

    width: listView ? listView.width : 0
    height: 42
    radius: 10
    color: "transparent"
    opacity: isDragging ? 0.35 : 1.0

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle {
        id: rowBg
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 20
        radius: 10
        color: theme.onSurface
        opacity: (rowHover.hovered && !row.canDrag) ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: rowBg
        radius: 10
        color: theme.primary
        opacity: row.isCurrent ? 0.10 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: hov4
        anchors.fill: rowBg
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: row.canDrag
            ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            : Qt.PointingHandCursor
        preventStealing: row.canDrag

        onPressed: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                mouse.accepted = true
                row.trackRemovalRequested(function() {
                    library.toggleLikeByPath(row.path)
                })
                return
            }
            if (mouse.button !== Qt.LeftButton) return
            if (!row.canDrag) return
            const pt = hov4.mapToItem(row.listView, mouse.x, mouse.y)
            row.listView.dragIndex = row.index
            row.listView.dropIndex = row.index
            row.listView.lastMouseY = pt.y
            if (row.autoScrollTimer) row.autoScrollTimer.start()
        }

        onPositionChanged: (mouse) => {
            if (!row.canDrag || row.listView.dragIndex < 0) return
            const pt = hov4.mapToItem(row.listView, mouse.x, mouse.y)
            row.listView.lastMouseY = pt.y
            const contentY = pt.y + row.listView.contentY
            const stride = row.height + row.listView.spacing
            let idx = Math.floor(contentY / stride)
            idx = Math.max(0, Math.min(library.tracks.count - 1, idx))
            if (idx !== row.listView.dropIndex) row.listView.dropIndex = idx
        }

        onReleased: (mouse) => {
            if (row.autoScrollTimer) row.autoScrollTimer.stop()
            if (mouse.button === Qt.MiddleButton) return
            if (!row.canDrag) {
                if (row.isCurrent) library.togglePlayPause()
                else               library.playIndex(row.index)
                row.activated()
                return
            }
            if (row.listView.dragIndex >= 0
                && row.listView.dropIndex >= 0
                && row.listView.dragIndex !== row.listView.dropIndex) {
                library.moveTrack(row.listView.dragIndex, row.listView.dropIndex)
            }
            row.listView.dragIndex = -1
            row.listView.dropIndex = -1
        }

        onCanceled: {
            if (row.autoScrollTimer) row.autoScrollTimer.stop()
            row.listView.dragIndex = -1
            row.listView.dropIndex = -1
        }
    }

    Rectangle {
        anchors.left: rowBg.left
        anchors.right: rowBg.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        height: 2
        radius: 1
        color: theme.primary
        y: row.isDropTargetAbove ? rowBg.y
           : row.isDropTargetBelow ? rowBg.y + rowBg.height - 2
           : rowBg.y
        visible: row.isDropTargetAbove || row.isDropTargetBelow
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.left: rowBg.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 2
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
        anchors.left: rowBg.left
        anchors.right: rowBg.right
        anchors.top: rowBg.top
        anchors.bottom: rowBg.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: (rowHover.hovered && !row.canDrag) ? 46 : 10
        spacing: 10

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

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
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
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
    }

    Item {
        id: addBtnSlot
        anchors.right: rowBg.right
        anchors.top: rowBg.top
        anchors.bottom: rowBg.bottom
        width: (rowHover.hovered && !row.canDrag) ? 42 : 0
        clip: true
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: addBtnHov.containsMouse
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.28)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MaterialIcon {
            anchors.centerIn: parent
            glyph: "\ue03b"
            iconSize: 16
            iconColor: addBtnHov.containsMouse ? theme.primary : theme.outline
            Behavior on iconColor { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: addBtnHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                library.requestCloseSearch()
                const pOverlay = addBtnHov.mapToItem(Overlay.overlay, 0, 0)
                const pContent = addBtnHov.mapToItem(row.listView.contentItem, 0, 0)
                row.addMenuRequested(row.path,
                                     pOverlay.x + addBtnHov.width,
                                     pContent.y,
                                     addBtnHov.height)
            }
        }
    }
}