import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal artistSelected(string name)
    signal artistActivated

    onVisibleChanged: {
        if (visible && library.editMode) library.toggleReorderMode()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "ARTISTS"
                color: theme.outline
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: sortChip
                Layout.preferredWidth: sortRow.implicitWidth + 22
                Layout.preferredHeight: 26
                radius: 8
                color: sortChipHov.containsMouse
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                Behavior on color { ColorAnimation { duration: 200 } }

                scale: sortChipHov.pressed ? 0.93 : (sortChipHov.containsMouse ? 1.05 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }

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

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: library.artistsAscending ? "\ue5d8" : "\ue5db"
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

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            reuseItems: false
            flickDeceleration: 500
            maximumFlickVelocity: 8000

            model: library.artists

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
                    wheelAnim.duration = Math.min(
                        550,
                        Math.max(240, Math.abs(target - list.contentY) * 1.2)
                    )
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

                width: list.width
                height: 48
                radius: 12
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: theme.onSurface
                    opacity: hov.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: theme.primary
                        opacity: hov.containsMouse ? 0.22 : 0.14
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            glyph: "\ue7fd"
                            iconSize: 18
                            filled: hov.containsMouse
                            iconColor: theme.primary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData
                        color: hov.containsMouse ? theme.primary : theme.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                    MaterialIcon {
                        glyph: "\ue5cc"
                        iconSize: 16
                        iconColor: theme.outline
                        opacity: hov.containsMouse ? 1 : 0
                        x: hov.containsMouse ? 0 : -10
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
            Layout.fillWidth: true
            text: library.artists.length === 0 ? "No artists" : library.artists.length + " artists"
            color: theme.outline
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            visible: library.artists.length > 0
        }
    }
}