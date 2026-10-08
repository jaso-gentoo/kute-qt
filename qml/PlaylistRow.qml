import QtQuick
import QtQuick.Controls.Basic
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
    signal deleteRequested(string id, string name, int idx)

    width: listView ? listView.width : 0
    height: 46
    clip: true

    Item {
        id: contentItem
        width: parent.width
        height: 46
        anchors.top: parent.top

        readonly property bool dropAbove: listView.dragActive
                       && listView.dragFrom >= 0 && listView.dragTo >= 0
                       && listView.dragTo === plRowWrap.index
                       && listView.dragFrom > plRowWrap.index
        readonly property bool dropBelow: listView.dragActive
                       && listView.dragFrom >= 0 && listView.dragTo >= 0
                       && listView.dragTo === plRowWrap.index
                       && listView.dragFrom < plRowWrap.index

        HoverHandler { id: plHov }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 10
            color: theme.onSurface
            opacity: plHov.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 2
            radius: 1
            color: theme.primary
            y: contentItem.dropAbove ? 0
               : contentItem.dropBelow ? parent.height - 2
               : 0
            visible: contentItem.dropAbove || contentItem.dropBelow
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
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
            preventStealing: true

            property real pressY: 0
            property bool didDrag: false

            onPressed: (mouse) => {
                pressY = mouse.y
                didDrag = false
                if (library.editMode && library.filterText.length === 0) {
                    listView.dragFrom = plRowWrap.index
                    listView.dragTo = plRowWrap.index
                }
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                if (!library.editMode || library.filterText.length > 0) return
                if (listView.dragFrom < 0) return
                const dy = mouse.y - pressY
                if (!listView.dragActive && Math.abs(dy) < 6) return
                listView.dragActive = true
                didDrag = true
                const pt = mapToItem(listView, mouse.x, mouse.y)
                const stride = plRowWrap.height + listView.spacing
                let idx = Math.floor((pt.y + listView.contentY) / stride)
                idx = Math.max(0, Math.min(listView.count - 1, idx))
                listView.dragTo = idx
            }

            onReleased: {
                if (listView.dragActive && listView.dragFrom >= 0 && listView.dragTo >= 0
                    && listView.dragFrom !== listView.dragTo) {
                    const savedY = listView.contentY
                    library.movePlaylist(listView.dragFrom, listView.dragTo)
                    Qt.callLater(function() { listView.contentY = savedY })
                }
                listView.dragFrom = -1
                listView.dragTo = -1
                listView.dragActive = false
            }

            onCanceled: {
                listView.dragFrom = -1
                listView.dragTo = -1
                listView.dragActive = false
                didDrag = false
            }

            onExited: {
                if (!pressed) {
                    listView.dragFrom = -1
                    listView.dragTo = -1
                    listView.dragActive = false
                }
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
            anchors.leftMargin: 8
            anchors.rightMargin: library.editMode ? 56 : 8
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
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: theme.surfaceVariant
                    visible: coverImg.status !== Image.Ready
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue8ef"
                    iconSize: 18
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
                    fillMode: Image.PreserveAspectFit
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
                MaterialIcon {
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
                font.pixelSize: 13
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
            width: (library.editMode && !listView.dragActive) ? 46 : 0
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
                enabled: library.editMode && !listView.dragActive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    library.requestCloseSearch()
                    plRowWrap.deleteRequested(plRowWrap.playlistId,
                                              plRowWrap.playlistName,
                                              plRowWrap.index)
                }
            }
        }
    }
}