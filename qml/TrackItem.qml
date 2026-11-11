import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
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

    signal activated()
    signal addMenuRequested(string path, real rightX, real anchorContentY, real btnHeight)
    signal trackRemovalRequested(var removalFn)
    signal reorderFinished()

    readonly property string rowPath: path

    readonly property bool canDrag: library.editMode
        && library.filterArtist === ""
        && library.filterAlbum === ""
        && library.filterText === ""
        && !library.showOnlyLiked

    readonly property bool isCurrent: library.currentFilePath === rowPath
    readonly property bool isDragging: listView && listView.dragIndex === row.index

    readonly property bool liked: {
        library.likedRevision
        return library.isLiked(row.index)
    }

    HoverHandler {
        id: rowHover
        enabled: !row.canDrag
        cursorShape: Qt.PointingHandCursor
    }

    width: listView ? (listView.width - 12) : 0
    height: 42
    color: "transparent"
    opacity: isDragging ? 0.5 : 1.0

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle {
        id: rowBg
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        color: row.isCurrent
            ? theme.primary
            : (rowHover.hovered && !row.canDrag ? theme.onSurface : "transparent")
        opacity: row.isCurrent
            ? 0.14
            : (rowHover.hovered && !row.canDrag ? 0.07 : 0)
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    MouseArea {
        id: ma
        anchors.fill: rowBg
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: row.canDrag
        cursorShape: row.canDrag
            ? (ma.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            : Qt.PointingHandCursor

        property bool dragging: false

        function updateDrop(mx, my) {
            if (!row.listView) return
            const gp = ma.mapToItem(null, mx, my)
            const lp = row.listView.mapFromItem(null, gp.x, gp.y)
            const vx = Math.max(0, Math.min(row.listView.width  - 1, lp.x))
            const vy = Math.max(0, Math.min(row.listView.height - 1, lp.y))
            row.listView.lastViewportX = vx
            row.listView.lastViewportY = vy
            row.listView.computeDropFromCursor()
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                mouse.accepted = true
                if (!row.canDrag) {
                    row.trackRemovalRequested(function() {
                        library.toggleLikeByPath(row.path)
                    })
                }
                return
            }
            if (mouse.button !== Qt.LeftButton) return

            if (row.canDrag) {
                dragging = true
                row.listView.dragIndex = row.index
                updateDrop(mouse.x, mouse.y)
            }
        }

        onPositionChanged: (mouse) => {
            if (!dragging) return
            updateDrop(mouse.x, mouse.y)
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.MiddleButton) return

            if (dragging) {
                updateDrop(mouse.x, mouse.y)
                const lv = row.listView
                const from = lv.dragIndex
                const slot = lv.dropIndex
                let to = -1
                if (from < slot)      to = slot - 1
                else if (from > slot) to = slot
                lv.dragIndex = -1
                lv.dropIndex = -1
                dragging = false

                if (from >= 0 && to >= 0 && to !== from) {
                    library.moveTrack(from, to)
                    row.reorderFinished()
                }
                return
            }

            if (row.canDrag) return
            if (mouse.button !== Qt.LeftButton) return

            if (row.isCurrent) library.togglePlayPause()
            else               library.playIndex(row.index)
            row.activated()
        }

        onCanceled: {
            dragging = false
        }
    }

    Rectangle {
        anchors.left: rowBg.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 2
        width: 3
        height: row.isCurrent ? 16 : 0
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
        anchors.rightMargin: (rowHover.hovered && !row.canDrag) ? 44 : 10
        spacing: 10

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        Item {
            Layout.preferredWidth: row.canDrag ? 16 : 0
            Layout.preferredHeight: 16
            clip: true
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Icon {
                anchors.centerIn: parent
                glyph: "\ue25d"
                iconSize: 15
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
                radius: 7
                color: theme.surfaceVariant
            }

            Image {
                id: thumbImg
                anchors.fill: parent
                source: row.thumb ? library.toFileUrl(row.thumb) + "?v=" + library.coverVersion : ""
                sourceSize.width: 60
                sourceSize.height: 60
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: false
                visible: status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                glyph: "\ue405"
                iconSize: 14
                iconColor: theme.outline
                visible: !row.thumb || thumbImg.status !== Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: "#000"
                opacity: (rowHover.hovered && !row.canDrag) ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Icon {
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

                Icon {
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
        width: (rowHover.hovered && !row.canDrag) ? 40 : 0
        clip: true
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 8
            color: addBtnHov.containsMouse
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.28)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Icon {
            anchors.centerIn: parent
            glyph: "\ue03b"
            iconSize: 15
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
