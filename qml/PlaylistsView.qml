import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    signal playlistActivated
    signal contextChanged

    clip: true

    property string viewing: ""
    property string viewingName: ""
    property string pendingDeleteId: ""
    property string pendingDeleteName: ""
    property int    pendingDeleteIndex: -1
    property bool pendingRemoveCover: false

    readonly property bool showCover: root.height > 340

    readonly property bool hasCover: {
        library.coverVersion
        return library.playlistCover(root.viewing) !== ""
    }

    function closeDialogs() {
        if (nameDialog.opened) nameDialog.close()
        if (deleteDialog.opened) deleteDialog.close()
    }

    onViewingChanged: {
        pendingRemoveCover = false
        root.contextChanged()
    }

    Connections {
        target: library
        function onEditModeChanged() {
            if (!library.editMode && root.pendingRemoveCover && root.viewing !== "") {
                library.clearPlaylistCover(root.viewing)
                root.pendingRemoveCover = false
            }
        }
    }

    Connections {
        target: library
        function onPlaylistsChanged() {
            if (nameDialog.opened) nameDialog.close()
            if (deleteDialog.opened) deleteDialog.close()
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
                        if (root.pendingRemoveCover) root.pendingRemoveCover = false
                        coverDialog.open()
                    }
                }

                CoverBtn {
                    glyph: "\ue2c4"
                    tip: "Save cover"
                    enabled: library.editMode && root.hasCover
                    visible: root.hasCover
                    onClicked: saveCoverDialog.open()
                }

                CoverBtn {
                    glyph: root.pendingRemoveCover ? "\ue8f4" : "\ue872"
                    tip: root.pendingRemoveCover ? "Cancel remove" : "Remove cover"
                    danger: true
                    confirming: root.pendingRemoveCover
                    enabled: library.editMode && root.hasCover
                    visible: root.hasCover
                    onClicked: root.pendingRemoveCover = !root.pendingRemoveCover
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

    FileDialog {
        id: coverDialog
        title: "Select playlist cover"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp)"]
        onAccepted: {
            library.setPlaylistCover(root.viewing, selectedFile.toString())
            root.pendingRemoveCover = false
        }
    }

    FileDialog {
        id: saveCoverDialog
        title: "Save playlist cover"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "jpg"
        nameFilters: ["JPEG (*.jpg *.jpeg)", "PNG (*.png)", "WebP (*.webp)"]

        readonly property string suggestedName: {
            const s = String(root.viewingName || "playlist")
            return s.replace(/[\\/:*?"<>|]/g, "_") + ".jpg"
        }

        onVisibleChanged: {
            if (visible) currentFile = suggestedName
        }

        onAccepted: {
            let p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            library.savePlaylistCoverTo(root.viewing, p)
        }
    }

    // Scrim for nameDialog
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

    // Scrim for deleteDialog
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
                if (root.viewing === nameDialog.playlistId)
                    root.viewingName = name
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
                    text: "Delete \"" + root.pendingDeleteName + "\"?"
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
                            if (root.pendingDeleteIndex >= 0) {
                                plList.deleteInProgress = true
                                plList.deletingIndex = root.pendingDeleteIndex
                                root.pendingDeleteIndex = -1
                            } else {
                                library.deletePlaylist(root.pendingDeleteId)
                            }
                            if (root.viewing === root.pendingDeleteId) root.viewing = ""
                            deleteDialog.close()
                        }
                    }
                }
            }
        }
    }

    Item {
        id: listPage
        anchors.fill: parent
        visible: opacity > 0.01
        x: root.viewing === "" ? 0 : -width
        opacity: root.viewing === "" ? 1 : 0
        Behavior on x       { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

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
                            const p = newPlaylistBtn.mapToItem(null, 0, 0)
                            nameDialog.x = Math.max(12,
                                Math.min(p.x + newPlaylistBtn.width - nameDialog.width,
                                         root.width - nameDialog.width - 12))
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
                property int deletingIndex: -1
                property bool deleteInProgress: false

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
                        if (Math.abs(event.pixelDelta.y) > 0) {
                            dy = event.pixelDelta.y * 3.5
                        } else {
                            dy = (event.angleDelta.y / 120.0) * 140
                        }
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
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 280; easing.type: Easing.OutCubic }
                }
                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: plRowWrap
                    required property string playlistId
                    required property string playlistName
                    required property int playlistTrackCount
                    required property string playlistCover
                    required property int index

                    property real animHeight: plList.deletingIndex === index ? 0 : 46

                    width: plList.width
                    height: animHeight
                    opacity: plList.deletingIndex === index ? 0 : 1
                    clip: true

                    Behavior on animHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity    { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onAnimHeightChanged: plList.forceLayout()

                    Timer {
                        running: plList.deletingIndex === plRowWrap.index
                        interval: 320
                        onTriggered: {
                            const id = plRowWrap.playlistId
                            plList.deletingIndex = -1
                            library.deletePlaylist(id)
                            plList.deleteInProgress = false
                        }
                    }

                    Item {
                        id: contentItem
                        width: parent.width
                        height: 46
                        anchors.top: parent.top

                        readonly property bool dragging: plList.dragActive && plList.dragFrom === index
                        readonly property bool dropAbove: plList.dragActive
                                       && plList.dragFrom >= 0 && plList.dragTo >= 0
                                       && plList.dragTo === index
                                       && plList.dragFrom > index
                        readonly property bool dropBelow: plList.dragActive
                                       && plList.dragFrom >= 0 && plList.dragTo >= 0
                                       && plList.dragTo === index
                                       && plList.dragFrom < index

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
                            cursorShape: library.editMode ? Qt.OpenHandCursor : Qt.PointingHandCursor
                            preventStealing: true

                            property real pressY: 0
                            property bool didDrag: false

                            onPressed: (mouse) => {
                                pressY = mouse.y
                                didDrag = false
                                if (library.editMode && library.filterText.length === 0) {
                                    plList.dragFrom = plRowWrap.index
                                    plList.dragTo = plRowWrap.index
                                }
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                if (!library.editMode || library.filterText.length > 0) return
                                if (plList.dragFrom < 0) return
                                const dy = mouse.y - pressY
                                if (!plList.dragActive && Math.abs(dy) < 6) return
                                plList.dragActive = true
                                didDrag = true
                                const pt = mapToItem(plList, mouse.x, mouse.y)
                                const stride = plRowWrap.height + plList.spacing
                                let idx = Math.floor((pt.y + plList.contentY) / stride)
                                idx = Math.max(0, Math.min(plList.count - 1, idx))
                                plList.dragTo = idx
                            }

                            onReleased: {
                                if (plList.dragActive && plList.dragFrom >= 0 && plList.dragTo >= 0
                                    && plList.dragFrom !== plList.dragTo) {
                                    library.movePlaylist(plList.dragFrom, plList.dragTo)
                                }
                                plList.dragFrom = -1
                                plList.dragTo = -1
                                plList.dragActive = false
                            }

                            onCanceled: {
                                plList.dragFrom = -1
                                plList.dragTo = -1
                                plList.dragActive = false
                                didDrag = false
                            }

                            onExited: {
                                if (!pressed) {
                                    plList.dragFrom = -1
                                    plList.dragTo = -1
                                    plList.dragActive = false
                                }
                            }

                            onClicked: {
                                if (didDrag) return
                                if (library.editMode) return
                                root.viewing = plRowWrap.playlistId
                                root.viewingName = plRowWrap.playlistName
                                library.setActivePlaylist(plRowWrap.playlistId)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

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
                                    mipmap: true
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
                                        nameDialog.x = Math.max(12,
                                            Math.min(p.x, root.width - nameDialog.width - 12))
                                        nameDialog.y = p.y + plNameText.height + 4
                                        nameDialog.mode = "rename"
                                        nameDialog.playlistId = plRowWrap.playlistId
                                        nameInput.text = plRowWrap.playlistName
                                        nameDialog.open()
                                        Qt.callLater(() => nameInput.forceActiveFocus())
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

                            Item {
                                Layout.preferredWidth: library.editMode ? 26 : 0
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                clip: true
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: deleteBtnHov.containsMouse
                                        ? Qt.rgba(0.9, 0.35, 0.35, 0.22)
                                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    glyph: "\ue872"
                                    iconSize: 14
                                    iconColor: deleteBtnHov.containsMouse ? "#e57373" : theme.onBackground
                                    Behavior on iconColor { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: deleteBtnHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (plList.deleteInProgress) return
                                        root.pendingDeleteId = plRowWrap.playlistId
                                        root.pendingDeleteName = plRowWrap.playlistName
                                        root.pendingDeleteIndex = plRowWrap.index
                                        deleteDialog.open()
                                    }
                                }
                            }
                        }
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

    Item {
        id: detailPage
        anchors.fill: parent
        visible: opacity > 0.01
        x: root.viewing !== "" ? 0 : width
        opacity: root.viewing !== "" ? 1 : 0
        Behavior on x       { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

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
                        onClicked: root.closeDetail()
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
                    Layout.preferredWidth: root.showCover ? 110 : 0
                    Layout.preferredHeight: root.showCover ? 110 : 0
                    Layout.alignment: Qt.AlignTop
                    clip: true
                    opacity: root.showCover ? 1 : 0
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
                            return library.playlistCover(root.viewing)
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
                        opacity: root.pendingRemoveCover ? 0.55 : 0
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
                    Layout.preferredHeight: root.showCover
                        ? (nameCol.implicitHeight + 10 + buttonsRow.height + 4)
                        : Math.max(nameCol.implicitHeight, buttonsRow.height)

                    ColumnLayout {
                        id: nameCol
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: root.showCover
                            ? parent.width
                            : Math.max(0, parent.width - buttonsRow.width - 12)
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.viewingName
                            color: theme.onBackground
                            font.pixelSize: root.showCover ? 20 : 17
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
                        y: root.showCover
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
                property int deletingIndex: -1
                property bool deleteInProgress: false

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
                        if (Math.abs(event.pixelDelta.y) > 0) {
                            dy = event.pixelDelta.y * 3.5
                        } else {
                            dy = (event.angleDelta.y / 120.0) * 140
                        }
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
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: -60; to: 0; duration: 340; easing.type: Easing.OutCubic }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 280; easing.type: Easing.OutCubic }
                }
                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                }

                delegate: Rectangle {
                    id: trackRow
                    required property int index
                    required property string title
                    required property string artist
                    required property string thumb
                    required property real duration
                    required property string path

                    readonly property bool isCurrent: library.currentFilePath === library.playlistTracks.pathAt(index)
                    readonly property bool isDragging: trackList.dragIndex === index
                    readonly property bool dropAbove: trackList.dropIndex === index
                                   && trackList.dragIndex > index
                                   && trackList.dragIndex !== index
                    readonly property bool dropBelow: trackList.dropIndex === index
                                   && trackList.dragIndex < index
                                   && trackList.dragIndex !== index

                    readonly property bool liked: {
                        library.likedRevision
                        return library.isPathLiked(trackRow.path)
                    }

                    property real animHeight: trackList.deletingIndex === index ? 0 : 42

                    width: trackList.width
                    height: animHeight
                    radius: 10
                    color: "transparent"
                    opacity: isDragging ? 0.35 : (trackList.deletingIndex === index ? 0 : 1)
                    clip: true

                    Behavior on animHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity    { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onAnimHeightChanged: trackList.forceLayout()

                    Timer {
                        running: trackList.deletingIndex === trackRow.index
                        interval: 320
                        onTriggered: {
                            const idx = trackList.deletingIndex
                            trackList.deletingIndex = -1
                            if (idx >= 0)
                                library.removeTrackFromPlaylist(library.activePlaylistId, idx)
                            trackList.deleteInProgress = false
                        }
                    }

                    Item {
                        id: trackContent
                        width: parent.width
                        height: 42
                        anchors.top: parent.top

                        HoverHandler { id: trackHover }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: library.editMode
                            cursorShape: library.editMode ? Qt.OpenHandCursor : Qt.PointingHandCursor

                            onClicked: {
                                if (library.editMode) return
                                library.playPlaylistIndex(trackRow.index)
                                root.playlistActivated()
                            }

                            onPressed: (mouse) => {
                                if (!library.editMode) return
                                if (mouse.button !== Qt.LeftButton) return
                                if (library.filterText.length > 0) return
                                trackList.dragIndex = trackRow.index
                                trackList.dropIndex = trackRow.index
                            }

                            onPositionChanged: (mouse) => {
                                if (!library.editMode || trackList.dragIndex < 0) return
                                if (library.filterText.length > 0) return
                                const pt = mapToItem(trackList, mouse.x, mouse.y)
                                const stride = trackRow.height + trackList.spacing
                                let idx = Math.floor((pt.y + trackList.contentY) / stride)
                                idx = Math.max(0, Math.min(trackList.count - 1, idx))
                                trackList.dropIndex = idx
                            }

                            onReleased: {
                                if (!library.editMode) return
                                if (trackList.dragIndex >= 0 && trackList.dropIndex >= 0
                                    && trackList.dragIndex !== trackList.dropIndex) {
                                    library.moveTrackInPlaylist(library.activePlaylistId,
                                                                 trackList.dragIndex,
                                                                 trackList.dropIndex)
                                }
                                trackList.dragIndex = -1
                                trackList.dropIndex = -1
                            }

                            onCanceled: {
                                trackList.dragIndex = -1
                                trackList.dropIndex = -1
                            }
                        }

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
                            radius: trackRow.radius
                            color: trackRow.isCurrent ? theme.primary : theme.onSurface
                            opacity: trackRow.isCurrent
                                ? 0.14
                                : (trackHover.hovered && !library.editMode ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

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
                                    Layout.fillWidth: true
                                    text: trackRow.title
                                    color: trackRow.isCurrent ? theme.primary : theme.onSurface
                                    font.pixelSize: 12
                                    font.weight: trackRow.isCurrent ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 220 } }
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

                            Item {
                                Layout.preferredWidth: (library.editMode && !trackRow.isDragging) ? 24 : 0
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                clip: true
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: removeHov.containsMouse
                                        ? Qt.rgba(0.9, 0.35, 0.35, 0.28)
                                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    glyph: "\ue872"
                                    iconSize: 14
                                    iconColor: removeHov.containsMouse ? "#e57373" : theme.onBackground
                                    Behavior on iconColor { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: removeHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: library.editMode
                                    onClicked: {
                                        if (trackList.deleteInProgress) return
                                        trackList.deleteInProgress = true
                                        trackList.deletingIndex = trackRow.index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}