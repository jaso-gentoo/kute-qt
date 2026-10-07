import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: menuRoot
    property bool shown: false
    property string path: ""
    property real anchorContentY: 0
    property real anchorOffset: 0
    property var listView: null

    function open(p, rightX, anchorContentYArg, btnHeight, lv) {
        if (shown && path === p) { close(); return }
        path = p
        anchorContentY = anchorContentYArg
        listView = lv

        const ow = Overlay.overlay ? Overlay.overlay.width  : 800
        const oh = Overlay.overlay ? Overlay.overlay.height : 600
        const mw = 240
        const mh = popup.contentH

        const listTopInOverlay = lv ? lv.mapToItem(Overlay.overlay, 0, 0).y : 0
        const btnWindowY = listTopInOverlay + anchorContentY - (lv ? lv.contentY : 0)

        let offset = btnHeight + 4
        if (btnWindowY + offset + mh > oh - 12) {
            const above = -mh - 8
            if (btnWindowY + above >= 12) offset = above
            else offset = Math.max(12 - btnWindowY, oh - mh - 12 - btnWindowY)
        }

        anchorOffset = offset
        popup.x = Math.max(12, Math.min(rightX - mw, ow - mw - 12))
        shown = true
    }

    function close() { shown = false }

    Shortcut {
        sequence: "Escape"
        enabled: menuRoot.shown
        onActivated: menuRoot.close()
    }

    Rectangle {
        id: scrim
        parent: Overlay.overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0.01
        opacity: menuRoot.shown ? 1 : 0
        z: 9998
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: menuRoot.close()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }
    }

    Rectangle {
        id: popup
        parent: Overlay.overlay
        readonly property real contentH: addMenuCol.implicitHeight + 16

        width: 240
        height: Math.min(contentH, (parent ? parent.height : 600) - 24)
        radius: 14
        color: theme.surface
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.20)
        border.width: 1
        z: 9999
        transformOrigin: Item.TopRight

        visible: opacity > 0.01
        opacity: menuRoot.shown ? 1 : 0
        scale: menuRoot.shown ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        y: {
            if (!parent || !menuRoot.listView) return 0
            const listTopInOverlay = menuRoot.listView.mapToItem(Overlay.overlay, 0, 0).y
            return listTopInOverlay + menuRoot.anchorContentY
                   - menuRoot.listView.contentY + menuRoot.anchorOffset
        }

        onVisibleChanged: if (!visible) newNameField.text = ""

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: (mouse) => mouse.accepted = true
        }

        function submitNew() {
            const name = newNameField.text.trim()
            if (name.length === 0) return
            library.createPlaylistWithTrack(name, menuRoot.path)
            menuRoot.close()
        }

        Flickable {
            id: addMenuFlick
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: addMenuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: addMenuCol
                width: addMenuFlick.width
                spacing: 4

                TextField {
                    id: newNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    placeholderText: "New playlist…"
                    placeholderTextColor: theme.outline
                    color: theme.onBackground
                    font.pixelSize: 12
                    leftPadding: 10
                    rightPadding: 10
                    selectByMouse: true

                    background: Rectangle {
                        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
                        radius: 8
                        border.color: newNameField.activeFocus ? theme.primary : "transparent"
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                    }

                    onAccepted: popup.submitNew()
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    Layout.preferredHeight: 1
                    color: theme.outline
                    opacity: 0.15
                    visible: library.playlists.length > 0
                }

                Repeater {
                    id: plRepeater
                    model: library.playlists

                    // Пробрасываем outer-scope в свойства — биндинги видят menuRoot,
                    // JS-хэндлеры делегата — нет (особенность Qt6).
                    property string addPath: menuRoot.path
                    property Item menuRef: menuRoot

                    delegate: Rectangle {
                        id: plItem
                        required property string playlistId
                        required property string playlistName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: "transparent"

                        // Это property-биндинги, они scope видят.
                        readonly property string trackPath: plRepeater.addPath
                        readonly property var    menu:      plRepeater.menuRef

                        readonly property bool alreadyIn:
                            library.isPathInPlaylist(plItem.playlistId, plItem.trackPath)

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: theme.onSurface
                            opacity: plItemHov.hovered ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: plItem.playlistName
                                color: theme.onBackground
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                visible: plItem.alreadyIn
                                glyph: plItem.alreadyIn ? "\ue5ca" : ""
                                iconSize: 13
                                iconColor: theme.primary
                            }
                        }

                        HoverHandler { id: plItemHov; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            onTapped: {
                                if (plItem.alreadyIn) {
                                    library.removeTrackFromPlaylist(
                                        plItem.playlistId,
                                        library.playlistIndexOf(plItem.playlistId, plItem.trackPath))
                                } else {
                                    library.addTrackToPlaylist(plItem.playlistId, plItem.trackPath)
                                }
                                plItem.menu.close()
                            }
                        }
                    }
                }
            }
        }
    }
}