import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: plRowWrap

    required property string playlistId
    required property string playlistName
    required property int playlistTrackCount
    required property string playlistCover
    required property int index

    property ListView listView

    signal opened(string id, string name)
    signal renameRequested(string id, string name, real px, real py)
    signal deleteRequested(string id, string name)
    signal reorderFinished()

    width: listView ? listView.width : 0
    height: 48
    clip: true

    Item {
        id: contentItem
        width: parent.width
        height: 48
        anchors.top: parent.top

        HoverHandler { id: plHov }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: theme.onSurface
            opacity: plHov.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: plArea
            anchors.fill: parent
            z: -2
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: library.editMode
                ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                : Qt.PointingHandCursor
            preventStealing: library.editMode

            property real pressY: 0
            property bool didDrag: false

            function updateDrop(mx, my) {
                if (!plRowWrap.listView) return
                const gp = plArea.mapToItem(null, mx, my)
                const lp = plRowWrap.listView.mapFromItem(null, gp.x, gp.y)
                const vx = Math.max(0, Math.min(plRowWrap.listView.width  - 1, lp.x))
                const vy = Math.max(0, Math.min(plRowWrap.listView.height - 1, lp.y))
                plRowWrap.listView.lastViewportX = vx
                plRowWrap.listView.lastViewportY = vy
                plRowWrap.listView.computeDropFromCursor()
            }

            onPressed: (mouse) => {
                pressY = mouse.y
                didDrag = false
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                if (!library.editMode) return
                if (library.filterText.length > 0) return
                if (!didDrag) {
                    if (Math.abs(mouse.y - pressY) < 6) return
                    didDrag = true
                    plRowWrap.listView.dragIndex = plRowWrap.index
                    plRowWrap.listView.dropIndex = plRowWrap.index
                }
                updateDrop(mouse.x, mouse.y)
            }

            onReleased: (mouse) => {
                if (didDrag) updateDrop(mouse.x, mouse.y)
                const from = plRowWrap.listView.dragIndex
                const slot = plRowWrap.listView.dropIndex
                let to = -1
                if (from >= 0 && slot >= 0) {
                    if (from < slot)      to = slot - 1
                    else if (from > slot) to = slot
                }
                const moved = from >= 0 && to >= 0 && to !== from
                plRowWrap.listView.dragIndex = -1
                plRowWrap.listView.dropIndex = -1
                if (moved) {
                    library.movePlaylist(from, to)
                    plRowWrap.reorderFinished()
                }
            }

            onCanceled: {
                plRowWrap.listView.dragIndex = -1
                plRowWrap.listView.dropIndex = -1
                didDrag = false
            }

            onClicked: {
                if (didDrag) return
                if (library.editMode) return
                plRowWrap.opened(plRowWrap.playlistId, plRowWrap.playlistName)
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: library.editMode ? 56 : 10
            spacing: 10

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            Item {
                Layout.preferredWidth: library.editMode ? 12 : 0
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
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: theme.surfaceVariant
                    visible: coverImg.status !== Image.Ready
                }

                Icon {
                    anchors.centerIn: parent
                    glyph: "\ue8ef"
                    iconSize: 17
                    iconColor: theme.outline
                    opacity: 0.5
                    visible: coverImg.status !== Image.Ready
                }

                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: plRowWrap.playlistCover || ""
                    sourceSize.width: 68
                    sourceSize.height: 68
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    visible: status === Image.Ready
                }
            }

            Item {
                Layout.preferredWidth: library.editMode ? 16 : 0
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                clip: true
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Icon {
                    anchors.centerIn: parent
                    glyph: "\ue3c9"
                    iconSize: 15
                    iconColor: theme.primary
                    opacity: library.editMode ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }
            }

            Text {
                id: plNameText
                Layout.fillWidth: true
                Layout.minimumWidth: 40
                Layout.alignment: Qt.AlignVCenter
                text: plRowWrap.playlistName
                color: plHov.hovered ? theme.primary : theme.onSurface
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 220 } }

                TapHandler {
                    enabled: library.editMode
                    gesturePolicy: TapHandler.DragThreshold
                    onTapped: {
                        const p = plNameText.mapToItem(null, 0, 0)
                        plRowWrap.renameRequested(plRowWrap.playlistId,
                                                  plRowWrap.playlistName,
                                                  p.x,
                                                  p.y + plNameText.height + 4)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: plRowWrap.playlistTrackCount
                      + (plRowWrap.playlistTrackCount === 1 ? " track" : " tracks")
                color: theme.outline
                font.pixelSize: 10
            }
        }

        Rectangle {
            id: removeBtn
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 2
            width: (library.editMode && !listView.dragActive) ? 42 : 0
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
                enabled: library.editMode && !listView.dragActive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    library.requestCloseSearch()
                    plRowWrap.deleteRequested(plRowWrap.playlistId,
                                              plRowWrap.playlistName)
                }
            }
        }
    }
}
