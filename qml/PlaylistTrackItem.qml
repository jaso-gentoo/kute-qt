import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: trackRow

    required property int index
    required property string title
    required property string artist
    required property string thumb
    required property real duration
    required property string path

    property ListView listView

    signal activated()
    signal trackRemovalRequested(var removalFn)
    signal reorderFinished()

    readonly property bool isCurrent: library.currentFilePath === trackRow.path
    readonly property bool isDragging: listView && listView.dragIndex === trackRow.index

    readonly property bool liked: {
        library.likedRevision
        return library.isPathLiked(trackRow.path)
    }

    property real pressY: -1
    property int  pressIndex: -1

    width: listView ? listView.width : 0
    height: 42
    radius: 10
    color: "transparent"
    opacity: isDragging ? 0.35 : 1.0

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
        id: trackContent
        width: parent.width
        height: 42
        anchors.top: parent.top

        HoverHandler { id: trackHover }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: trackRow.isCurrent ? theme.primary : theme.onSurface
            opacity: trackRow.isCurrent
                ? 0.14
                : (trackHover.hovered && !library.editMode ? 0.07 : 0)
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            anchors.leftMargin: 10
            anchors.rightMargin: (library.editMode && !trackRow.isDragging) ? 48 : 10
            spacing: 10

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            Item {
                Layout.preferredWidth: library.editMode ? 14 : 0
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                clip: true
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Icon {
                    anchors.centerIn: parent
                    glyph: "\ue25d"
                    iconSize: 14
                    iconColor: theme.outline
                    opacity: library.editMode ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: theme.surfaceVariant
                    visible: thumbImg.status !== Image.Ready
                }

                Icon {
                    anchors.centerIn: parent
                    glyph: "\ue405"
                    iconSize: 14
                    iconColor: theme.outline
                    visible: thumbImg.status !== Image.Ready
                }

                Image {
                    id: thumbImg
                    anchors.fill: parent
                    source: trackRow.thumb
                        ? library.toFileUrl(trackRow.thumb) + "?v=" + library.coverVersion
                        : ""
                    sourceSize.width: 60
                    sourceSize.height: 60
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "#000"
                    opacity: trackHover.hovered && !library.editMode ? 0.5 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Icon {
                        anchors.centerIn: parent
                        glyph: trackRow.isCurrent && library.isPlaying ? "\ue034" : "\ue037"
                        iconSize: 14
                        iconColor: "white"
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

                    opacity: trackRow.liked ? 1 : 0
                    scale: trackRow.liked ? 1.0 : 0.3
                    rotation: trackRow.liked ? 0 : -30

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
                    id: trackTitle
                    Layout.fillWidth: true
                    text: trackRow.title
                    color: trackRow.isCurrent ? theme.primary : theme.onSurface
                    font.pixelSize: 12
                    font.weight: trackRow.isCurrent ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                    transformOrigin: Item.Left
                    scale: trackRow.isCurrent ? 1.08 : 1.0
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: trackRow.artist
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Text {
                text: library.formatDuration(trackRow.duration)
                color: theme.outline
                font.pixelSize: 10
                font.family: "monospace"
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: library.editMode
                ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                : Qt.PointingHandCursor
            preventStealing: library.editMode

            function updateDrop(mx, my) {
                if (!trackRow.listView) return
                const gp = ma.mapToItem(null, mx, my)
                const lp = trackRow.listView.mapFromItem(null, gp.x, gp.y)
                const vx = Math.max(0, Math.min(trackRow.listView.width  - 1, lp.x))
                const vy = Math.max(0, Math.min(trackRow.listView.height - 1, lp.y))
                trackRow.listView.lastViewportX = vx
                trackRow.listView.lastViewportY = vy
                trackRow.listView.computeDropFromCursor()
            }

            onClicked: (mouse) => {
                if (library.editMode) return
                if (mouse.button === Qt.MiddleButton) {
                    library.toggleLikeByPath(trackRow.path)
                    return
                }
                if (trackRow.isCurrent) {
                    library.togglePlayPause()
                } else {
                    library.playPlaylistIndex(trackRow.index)
                    trackRow.activated()
                }
            }

            onPressed: (mouse) => {
                if (!library.editMode) return
                if (mouse.button !== Qt.LeftButton) return
                if (library.filterText.length > 0) return
                trackRow.pressY = mouse.y
                trackRow.pressIndex = trackRow.index
            }

            onPositionChanged: (mouse) => {
                if (trackRow.pressY < 0) return
                if (!library.editMode) return
                if (library.filterText.length > 0) return
                if (trackRow.listView.dragIndex < 0) {
                    if (Math.abs(mouse.y - trackRow.pressY) < 6) return
                    trackRow.listView.dragIndex = trackRow.pressIndex
                    trackRow.listView.dropIndex = trackRow.pressIndex
                }
                updateDrop(mouse.x, mouse.y)
            }

            onReleased: (mouse) => {
                trackRow.pressY = -1
                trackRow.pressIndex = -1
                if (!library.editMode) return
                const lv = trackRow.listView
                const from = lv.dragIndex
                const slot = lv.dropIndex
                let to = -1
                if (from >= 0 && slot >= 0) {
                    if (from < slot)      to = slot - 1
                    else if (from > slot) to = slot
                }
                const moved = from >= 0 && to >= 0 && to !== from
                lv.dragIndex = -1
                lv.dropIndex = -1
                if (moved) {
                    library.moveTrackInPlaylist(library.activePlaylistId, from, to)
                    trackRow.reorderFinished()
                }
            }

            onCanceled: {
                trackRow.pressY = -1
                trackRow.pressIndex = -1
                trackRow.listView.dragIndex = -1
                trackRow.listView.dropIndex = -1
            }
        }

        Rectangle {
            id: removeBtn
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 2
            width: (library.editMode && !trackRow.isDragging) ? 40 : 0
            radius: 10
            clip: true
            color: removeHov.containsMouse
                ? Qt.rgba(0.9, 0.35, 0.35, 0.28)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            Icon {
                anchors.centerIn: parent
                glyph: "\ue872"
                iconSize: 16
                iconColor: removeHov.containsMouse ? "#e57373" : theme.outline
                Behavior on iconColor { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: removeHov
                anchors.fill: parent
                enabled: library.editMode && !trackRow.isDragging
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    library.requestCloseSearch()
                    trackRow.trackRemovalRequested(function() {
                        library.removeTrackFromPlaylist(library.activePlaylistId, trackRow.path)
                    })
                }
            }
        }
    }
}
