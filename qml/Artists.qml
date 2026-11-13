import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root

    signal artistSelected(string name)
    signal artistActivated

    onVisibleChanged: {
        if (visible && library.editMode) library.toggleEditMode()
    }

    Item {
        anchors.fill: parent
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            reuseItems: false
            flickDeceleration: 500
            maximumFlickVelocity: 8000

            model: library.artists

            ScrollBar.vertical: ScrollBar {
                id: artScrollBar
                policy: list.contentHeight > list.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 10
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: theme.outline
                    opacity: artScrollBar.pressed ? 0.8 : (artScrollBar.hovered ? 0.55 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                background: Item {}
            }

            Connections {
                target: library
                function onFilterTextChanged() {
                    list.contentY = 0
                    list.positionViewAtBeginning()
                    list.forceLayout()
                }
                function onArtistsChanged() {
                    list.contentY = 0
                    list.positionViewAtBeginning()
                    list.forceLayout()
                }
            }

            NumberAnimation {
                id: wheelAnim
                target: list
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, list.contentHeight - list.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) {
                        dy = event.pixelDelta.y * 3.5
                    } else {
                        dy = (event.angleDelta.y / 120.0) * 140
                    }
                    const currentTarget = wheelAnim.running ? wheelAnim.to : list.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    wheelAnim.stop()
                    wheelAnim.from = list.contentY
                    wheelAnim.to = target
                    wheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - list.contentY) * 1.2))
                    wheelAnim.start()
                    event.accepted = true
                }
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: 320; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"; from: -16; to: 0
                    duration: 360; easing.type: Easing.OutCubic
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 280; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: row

                required property string modelData
                required property int index

                width: list.width - 12
                height: 46
                radius: 10
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 10
                    color: theme.onSurface
                    opacity: hov.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 10
                        color: theme.primary
                        opacity: hov.containsMouse ? 0.22 : 0.14
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        Icon {
                            anchors.centerIn: parent
                            glyph: ""
                            iconSize: 17
                            filled: hov.containsMouse
                            iconColor: theme.primary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData
                        color: hov.containsMouse ? theme.primary : theme.onSurface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.artistSelected(row.modelData)
                        root.artistActivated()
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "No artists"
            visible: library.artists.length === 0
            color: theme.outline
            font.pixelSize: 12
            opacity: 0.6
        }

        Rectangle {
            id: sortChip
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 16
            z: 100
            width: sortRow.implicitWidth + 24
            height: 34
            radius: 14
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.96)
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
            border.width: 1

            SequentialAnimation {
                id: flipAnim
                NumberAnimation {
                    target: sortChip
                    property: "opacity"
                    to: 0.2
                    duration: 110
                    easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: library.artistsAscending = !library.artistsAscending
                }
                NumberAnimation {
                    target: sortChip
                    property: "opacity"
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: sortRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: library.artistsAscending ? "" : ""
                    iconSize: 13
                    iconColor: theme.primary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: library.artistsAscending ? "A-Z" : "Z-A"
                    color: theme.primary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                }
            }

            MouseArea {
                id: sortChipHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: flipAnim.start()
            }
        }
    }
}
