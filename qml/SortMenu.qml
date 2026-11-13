import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: menuRoot
    property bool shown: false
    property bool hovered: menuHover.hovered
    property Item anchorItem: null

    function show(item) {
        anchorItem = item
        if (!item) return
        shown = true
    }

    function close() { shown = false }

    Shortcut {
        sequence: "Escape"
        enabled: menuRoot.shown
        onActivated: menuRoot.close()
    }

    Rectangle {
        id: popup
        parent: Overlay.overlay
        width: 200
        height: contentCol.implicitHeight + 16
        radius: 14
        color: theme.surface
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.22)
        border.width: 1
        z: 9000
        visible: opacity > 0.01
        opacity: menuRoot.shown ? 1 : 0
        scale: menuRoot.shown ? 1.0 : 0.92
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        x: {
            if (!menuRoot.anchorItem) return 0
            const _dep = menuRoot.anchorItem.x + menuRoot.anchorItem.y
            const p = menuRoot.anchorItem.mapToItem(Overlay.overlay, menuRoot.anchorItem.width, menuRoot.anchorItem.height)
            const w = Overlay.overlay ? Overlay.overlay.width : 800
            return Math.max(12, Math.min(p.x - width, w - width - 12))
        }
        y: {
            if (!menuRoot.anchorItem) return 0
            const _dep = menuRoot.anchorItem.x + menuRoot.anchorItem.y
            const p = menuRoot.anchorItem.mapToItem(Overlay.overlay, 0, menuRoot.anchorItem.height)
            return p.y + 6
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: false
            onPressed: (m) => m.accepted = true
        }

        HoverHandler {
            id: menuHover
            blocking: true
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            Text {
                text: "SORT BY"
                color: theme.outline
                font.pixelSize: 9
                font.letterSpacing: 1.4
                Layout.leftMargin: 8
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                opacity: menuRoot.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            Repeater {
                model: [
                    { key: "custom",   label: "Custom",    icon: "" },
                    { key: "title",    label: "Title",     icon: "" },
                    { key: "artist",   label: "Artist",    icon: "" },
                    { key: "album",    label: "Album",     icon: "" },
                    { key: "duration", label: "Duration",  icon: "" },
                    { key: "path",     label: "File name", icon: "" }
                ]

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool active: library.sortField === modelData.key
                    readonly property bool isCustom: modelData.key === "custom"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: itemHover.hovered
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    opacity: 0
                    Component.onCompleted: appearAnim.start()

                    SequentialAnimation {
                        id: appearAnim
                        PauseAnimation { duration: index * 40 }
                        NumberAnimation {
                            target: item
                            property: "opacity"
                            to: 1.0
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    HoverHandler {
                        id: itemHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            if (item.isCustom) {
                                library.applySort("custom", true)
                            } else if (item.active) {
                                library.applySort(item.modelData.key, !library.sortAscending)
                            } else {
                                library.applySort(item.modelData.key, true)
                            }
                            menuRoot.close()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Icon {
                            glyph: item.modelData.icon
                            iconSize: 16
                            filled: item.active
                            iconColor: item.active ? theme.primary : theme.onBackground
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData.label
                            color: item.active ? theme.primary : theme.onBackground
                            font.pixelSize: 12
                            font.weight: item.active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Icon {
                            visible: item.active && !item.isCustom
                            glyph: library.sortAscending ? "" : ""
                            iconSize: 14
                            iconColor: theme.primary
                        }
                    }
                }
            }
        }
    }
}
