import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: menuRoot
    property bool shown: false

    function show(anchorItem) {
        if (!anchorItem) return
        const p = anchorItem.mapToItem(Overlay.overlay, anchorItem.width, anchorItem.height)
        const w = Overlay.overlay ? Overlay.overlay.width : 800
        popup.x = Math.max(12, Math.min(p.x - popup.width, w - popup.width - 12))
        popup.y = p.y + 6
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
        color: "transparent"
        visible: opacity > 0.01
        enabled: menuRoot.shown
        opacity: menuRoot.shown ? 1 : 0
        z: 8990
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        HoverHandler { blocking: true }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: menuRoot.close()
        }
    }

    Rectangle {
        id: popup
        parent: Overlay.overlay
        width: 220
        height: sortContent.implicitHeight + 12
        radius: 14
        color: theme.surface
        border.color: theme.outline
        border.width: 1
        z: 9000

        visible: opacity > 0.01
        enabled: menuRoot.shown
        opacity: menuRoot.shown ? 1 : 0
        scale: menuRoot.shown ? 1.0 : 0.95
        transformOrigin: Item.TopRight

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

        HoverHandler { blocking: true }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }

        ColumnLayout {
            id: sortContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            Text {
                text: "SORT BY"
                color: theme.outline
                font.pixelSize: 9
                font.letterSpacing: 1.4
                Layout.leftMargin: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    { key: "custom",   label: "Custom" },
                    { key: "title",    label: "Title" },
                    { key: "artist",   label: "Artist" },
                    { key: "album",    label: "Album" },
                    { key: "duration", label: "Duration" },
                    { key: "path",     label: "File name" }
                ]

                delegate: Rectangle {
                    id: sortItem
                    required property var modelData
                    readonly property bool active: library.sortField === modelData.key
                    readonly property bool isCustom: modelData.key === "custom"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: theme.onSurface
                        opacity: sortItemHov.containsMouse ? 0.08 : (sortItem.active ? 0.06 : 0)
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        visible: sortItem.isCustom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: sortItem.active ? theme.primary : theme.outline
                        opacity: sortItem.active ? 1 : 0.4
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: sortItem.modelData.label
                            color: sortItem.active ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: sortItem.active ? Font.DemiBold : Font.Normal
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            visible: sortItem.active && !sortItem.isCustom
                            glyph: library.sortAscending ? "\ue5d8" : "\ue5db"
                            iconSize: 14
                            iconColor: theme.primary
                            opacity: sortItem.active ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        MaterialIcon {
                            visible: sortItem.active && sortItem.isCustom
                            glyph: "\ue25d"
                            iconSize: 14
                            iconColor: theme.primary
                        }
                    }

                    MouseArea {
                        id: sortItemHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sortItem.isCustom) {
                                library.applySort("custom", true)
                                menuRoot.close()
                            } else if (sortItem.active) {
                                library.applySort(sortItem.modelData.key, !library.sortAscending)
                            } else {
                                library.applySort(sortItem.modelData.key, true)
                            }
                        }
                    }
                }
            }
        }
    }
}