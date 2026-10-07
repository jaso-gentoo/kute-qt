import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: page

    signal playlistOpened(string id, string name)

    clip: true

    property string pendingDeleteId: ""
    property string pendingDeleteName: ""

    function closeDialogs() {
        if (nameDialog.opened) nameDialog.close()
        if (deleteDialog.opened) deleteDialog.close()
    }

    Connections {
        target: library
        function onPlaylistsChanged() {
            if (nameDialog.opened) nameDialog.close()
            if (deleteDialog.opened) deleteDialog.close()
        }
    }

    Rectangle {
        parent: Overlay.overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: opacity > 0.01
        opacity: nameDialog.visible ? 1 : 0
        z: 9980
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: nameDialog.close()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }
    }

    Rectangle {
        parent: Overlay.overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: opacity > 0.01
        opacity: deleteDialog.visible ? 1 : 0
        z: 9980
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: deleteDialog.close()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }
    }

    Popup {
        id: nameDialog
        parent: Overlay.overlay
        width: 280
        height: contentCol.implicitHeight + 16
        padding: 8
        modal: false
        dim: false
        focus: true
        z: 9990
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string mode: "create"
        property string playlistId: ""

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130; easing.type: Easing.InCubic }
        }

        transformOrigin: Item.TopRight

        background: Rectangle {
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.20)
            border.width: 1
            radius: 14
        }

        contentItem: ColumnLayout {
            id: contentCol
            spacing: 6

            TextField {
                id: nameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                placeholderText: nameDialog.mode === "create" ? "Playlist name…" : "Rename playlist…"
                placeholderTextColor: theme.outline
                color: theme.onBackground
                font.pixelSize: 13
                leftPadding: 12
                rightPadding: 12
                selectByMouse: true

                background: Rectangle {
                    color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
                    radius: 9
                    border.color: nameInput.activeFocus ? theme.primary : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                }

                onAccepted: nameDialog.doConfirm()
                HoverHandler { cursorShape: Qt.IBeamCursor }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: cancelTxt.implicitWidth + 22
                    Layout.preferredHeight: 28
                    radius: 8
                    color: cancelHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.onBackground
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nameDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: confirmTxt.implicitWidth + 22
                    Layout.preferredHeight: 28
                    radius: 8
                    color: confirmHov.pressed
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.30)
                        : (confirmHov.containsMouse
                            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.24)
                            : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: confirmTxt
                        anchors.centerIn: parent
                        text: nameDialog.mode === "create" ? "Create" : "Save"
                        color: theme.primary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: confirmHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nameDialog.doConfirm()
                    }
                }
            }
        }

        function doConfirm() {
            const name = nameInput.text.trim()
            if (name.length === 0) return
            if (nameDialog.mode === "create") {
                library.createPlaylistWithTrack(name, "")
            } else {
                library.renamePlaylist(nameDialog.playlistId, name)
            }
            nameDialog.close()
        }
    }

    Popup {
        id: deleteDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: 320
        height: contentDel.implicitHeight + 24
        padding: 0
        modal: false
        dim: false
        focus: true
        z: 9990
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130; easing.type: Easing.InCubic }
        }

        background: Rectangle {
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.20)
            border.width: 1
            radius: 14
        }

        contentItem: ColumnLayout {
            id: contentDel
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Delete \"" + page.pendingDeleteName + "\"?"
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: theme.outline
                opacity: 0.15
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                spacing: 6

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: delCancelTxt.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: 8
                    color: delCancelHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: delCancelTxt
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.onBackground
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: delCancelHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: delConfirmTxt.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: 8
                    color: delConfirmHov.pressed
                        ? Qt.rgba(0.85, 0.30, 0.28, 0.28)
                        : (delConfirmHov.containsMouse
                            ? Qt.rgba(0.85, 0.30, 0.28, 0.22)
                            : Qt.rgba(0.85, 0.30, 0.28, 0.14))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: delConfirmTxt
                        anchors.centerIn: parent
                        text: "Delete"
                        color: "#e57373"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: delConfirmHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            library.deletePlaylist(page.pendingDeleteId)
                            deleteDialog.close()
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 6

            Text {
                text: "PLAYLISTS"
                color: theme.outline
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: editListBtn
                Layout.preferredWidth: editListRow.implicitWidth + 20
                Layout.preferredHeight: 26
                Layout.rightMargin: 5
                radius: 8
                color: library.editMode
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                Behavior on color { ColorAnimation { duration: 220 } }

                scale: editListHov.pressed ? 0.94 : (editListHov.containsMouse ? 1.05 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                }

                Item {
                    id: editListRow
                    anchors.centerIn: parent
                    implicitWidth: Math.max(editRowEdit.implicitWidth, editRowDone.implicitWidth)
                    implicitHeight: Math.max(editRowEdit.implicitHeight, editRowDone.implicitHeight)

                    Row {
                        id: editRowEdit
                        anchors.centerIn: parent
                        spacing: 5
                        opacity: library.editMode ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "\ue3c9"
                            iconSize: 13
                            iconColor: theme.onBackground
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Edit"
                            color: theme.onBackground
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    Row {
                        id: editRowDone
                        anchors.centerIn: parent
                        spacing: 5
                        opacity: library.editMode ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "\ue5ca"
                            iconSize: 13
                            iconColor: theme.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Done"
                            color: theme.primary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }

                MouseArea {
                    id: editListHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.toggleReorderMode()
                }
            }

            Rectangle {
                id: newPlaylistBtn
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 8
                color: newBtnHov.containsMouse
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                Behavior on color { ColorAnimation { duration: 200 } }

                scale: newBtnHov.pressed ? 0.9 : (newBtnHov.containsMouse ? 1.1 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.8 }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue145"
                    iconSize: 16
                    iconColor: theme.primary
                }

                MouseArea {
                    id: newBtnHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        library.requestCloseSearch()
                        const p = newPlaylistBtn.mapToItem(null, 0, 0)
                        nameDialog.x = Math.max(12,
                            Math.min(p.x + newPlaylistBtn.width - nameDialog.width,
                                     page.width - nameDialog.width - 12))
                        nameDialog.y = p.y + newPlaylistBtn.height + 6
                        nameDialog.mode = "create"
                        nameInput.text = ""
                        nameDialog.open()
                        Qt.callLater(() => nameInput.forceActiveFocus())
                    }
                }
            }
        }

        ListView {
            id: plList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.DragOverBounds
            boundsMovement: Flickable.StopAtBounds
            reuseItems: false
            model: library.filterText.length === 0
                ? library.playlists
                : library.playlistsFiltered

            property int dragFrom: -1
            property int dragTo: -1
            property bool dragActive: false

            NumberAnimation {
                id: wheelAnim
                target: plList
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, plList.contentHeight - plList.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                    else dy = (event.angleDelta.y / 120.0) * 140
                    const currentTarget = wheelAnim.running ? wheelAnim.to : plList.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    wheelAnim.stop()
                    wheelAnim.from = plList.contentY
                    wheelAnim.to = target
                    wheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - plList.contentY) * 1.2))
                    wheelAnim.start()
                    event.accepted = true
                }
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: -60; to: 0; duration: 340; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; to: -60; duration: 420; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 380; easing.type: Easing.OutCubic }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
            }

            delegate: PlaylistRow {
                listView: plList
                onOpened: (id, name) => page.playlistOpened(id, name)
                onRenameRequested: (id, name, px, py) => {
                    nameDialog.x = Math.max(12, Math.min(px, page.width - nameDialog.width - 12))
                    nameDialog.y = py
                    nameDialog.mode = "rename"
                    nameDialog.playlistId = id
                    nameInput.text = name
                    nameDialog.open()
                    Qt.callLater(() => nameInput.forceActiveFocus())
                }
                onDeleteRequested: (id, name, idx) => {
                    page.pendingDeleteId = id
                    page.pendingDeleteName = name
                    deleteDialog.open()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: library.playlistsFiltered.count === 0
                ? (library.filterText.length > 0
                    ? "No matches"
                    : "No playlists yet — press +")
                : library.playlistsFiltered.count
                  + (library.playlistsFiltered.count === 1 ? " playlist" : " playlists")
            color: theme.outline
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}