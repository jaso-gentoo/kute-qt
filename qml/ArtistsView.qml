import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal artistSelected(string name)
    signal artistActivated

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            text: "ARTISTS"
            color: theme.outline
            font.pixelSize: 10
            font.letterSpacing: 1.4
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            reuseItems: true
            flickDeceleration: 500
            maximumFlickVelocity: 8000

            model: library.artists

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
                    duration: 350; easing.type: Easing.OutCubic
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

                scale: hov.pressed ? 0.99 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: theme.onSurface
                    opacity: hov.containsMouse ? 0.06 : 0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
                        opacity: 0.14

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
                        color: theme.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        glyph: "\ue5cc"
                        iconSize: 16
                        iconColor: theme.outline
                        opacity: hov.containsMouse ? 1 : 0
                        x: hov.containsMouse ? 0 : -6
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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