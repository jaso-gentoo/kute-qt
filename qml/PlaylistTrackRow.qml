import QtQuick
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

    readonly property bool isCurrent: library.currentFilePath === trackRow.path
    readonly property bool isDragging: listView && listView.dragIndex === trackRow.index
    readonly property bool dropAbove: listView
        && listView.dropIndex === trackRow.index
        && listView.dragIndex > trackRow.index
        && listView.dragIndex !== trackRow.index
    readonly property bool dropBelow: listView
        && listView.dropIndex === trackRow.index
        && listView.dragIndex < trackRow.index
        && listView.dragIndex !== trackRow.index

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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 2
            radius: 1
            color: theme.primary
            y: trackRow.dropAbove ? 0
               : trackRow.dropBelow ? parent.height - 2
               : 0
            visible: trackRow.dropAbove || trackRow.dropBelow
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: trackRow.isCurrent ? theme.primary : theme.onSurface
            opacity: trackRow.isCurrent
                ? 0.14
                : (trackHover.hovered && !library.editMode ? 0.07 : 0)
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: (library.editMode && !trackRow.isDragging) ? 50 : 10
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

                MaterialIcon {
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
                    radius: 6
                    color: theme.surfaceVariant
                    visible: thumbImg.status !== Image.Ready
                }

                MaterialIcon {
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
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "#000"
                    opacity: trackHover.hovered && !library.editMode ? 0.5 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    MaterialIcon {
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
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: library.editMode
                ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                : Qt.PointingHandCursor
            preventStealing: library.editMode

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
                if (listView.dragIndex < 0) {
                    if (Math.abs(mouse.y - trackRow.pressY) < 6) return
                    listView.dragIndex = trackRow.pressIndex
                    listView.dropIndex = trackRow.pressIndex
                }
                const pt = mapToItem(listView, mouse.x, mouse.y)
                const stride = trackRow.height + listView.spacing
                let idx = Math.floor((pt.y + listView.contentY) / stride)
                idx = Math.max(0, Math.min(listView.count - 1, idx))
                listView.dropIndex = idx
            }

            onReleased: {
                trackRow.pressY = -1
                trackRow.pressIndex = -1
                if (!library.editMode) return
                if (listView.dragIndex < 0) return
                if (listView.dragIndex >= 0 && listView.dropIndex >= 0
                    && listView.dragIndex !== listView.dropIndex) {
                    const savedY = listView.contentY
                    library.moveTrackInPlaylist(library.activePlaylistId,
                                                 listView.dragIndex,
                                                 listView.dropIndex)
                    Qt.callLater(function() { listView.contentY = savedY })
                }
                listView.dragIndex = -1
                listView.dropIndex = -1
            }

            onCanceled: {
                trackRow.pressY = -1
                trackRow.pressIndex = -1
                listView.dragIndex = -1
                listView.dropIndex = -1
            }
        }

        Rectangle {
            id: removeBtn
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (library.editMode && !trackRow.isDragging) ? 42 : 0
            radius: 10
            clip: true
            color: removeHov.containsMouse
                ? Qt.rgba(0.9, 0.35, 0.35, 0.28)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            MaterialIcon {
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
                        library.removeTrackFromPlaylist(library.activePlaylistId, trackRow.index)
                    })
                }
            }
        }
    }
}