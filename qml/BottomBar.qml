import QtQuick
import QtQuick.Layouts

Rectangle {
    id: bar
    radius: 20
    color: theme.surface

    signal coverClicked

    readonly property string displayTitle: {
        if (!library.hasCurrent) return "—"
        const t = library.currentTitle
        return t.length > 34 ? t.substring(0, 32) + "…" : t
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: theme.outline
        border.width: 1
        opacity: 0.18
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 16

        RowLayout {
            Layout.preferredWidth: 200
            Layout.minimumWidth: 80
            Layout.maximumWidth: 220
            Layout.fillHeight: true
            spacing: 10

            Item {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: theme.surfaceVariant
                    clip: true

                    Image {
                        id: miniCover
                        anchors.fill: parent
                        source: library.currentCover ? "file://" + library.currentCover + "?v=" + library.coverVersion : ""
                        sourceSize.width: 60
                        sourceSize.height: 60
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        visible: status === Image.Ready
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue405"
                        iconSize: 20
                        iconColor: theme.outline
                        visible: !library.currentCover || miniCover.status !== Image.Ready
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: "#000"
                    opacity: hovCover.containsMouse ? 0.45 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue88e"
                        iconSize: 20
                        iconColor: "white"
                        scale: hovCover.containsMouse ? 1.0 : 0.7
                        opacity: hovCover.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.5
                            }
                        }
                    }
                }

                MouseArea {
                    id: hovCover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.coverClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: bar.displayTitle
                    color: theme.onSurface
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: library.hasCurrent ? library.currentArtist : ""
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: library.formatDuration(library.position)
                    color: theme.outline
                    font.pixelSize: 10
                    font.family: "monospace"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: library.formatDuration(library.duration)
                    color: theme.outline
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }

            Item {
                id: progArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real progress: library.duration > 0
                                                 ? library.position / library.duration
                                                 : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: progHover.hovered ? 8 : 5
                    radius: height / 2
                    color: theme.surfaceVariant
                    Behavior on height { NumberAnimation { duration: 180 } }

                    Rectangle {
                        width: parent.width * progArea.progress
                        height: parent.height
                        radius: parent.radius
                        color: theme.primary
                    }
                }

                Rectangle {
                    width: progHover.hovered || progMouse.pressed ? 14 : 0
                    height: width
                    radius: width / 2
                    color: theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * progArea.progress - width / 2
                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                }

                HoverHandler {
                    id: progHover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    id: progMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (library.duration > 0)
                            library.seek(library.duration * mouse.x / width)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && library.duration > 0)
                            library.seek(library.duration * mouse.x / width)
                    }
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: 210
            Layout.minimumWidth: 210
            Layout.maximumWidth: 210
            Layout.fillHeight: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 19
                color: theme.surfaceVariant

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue045"
                    iconSize: 20
                    iconColor: theme.onSurface
                }

                scale: hovPrev.pressed ? 0.9 : (hovPrev.containsMouse ? 1.06 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MouseArea {
                    id: hovPrev
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.prev()
                }
            }

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                Layout.alignment: Qt.AlignVCenter
                radius: 23
                color: theme.primary

                scale: hovPlay.pressed ? 0.88 : (hovPlay.containsMouse ? 1.06 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: 22
                    height: 22

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue037"
                        iconSize: 24
                        iconColor: theme.background
                        opacity: library.isPlaying ? 0 : 1
                        scale: library.isPlaying ? 0.6 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.5
                            }
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue034"
                        iconSize: 24
                        iconColor: theme.background
                        opacity: library.isPlaying ? 1 : 0
                        scale: library.isPlaying ? 1.0 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.5
                            }
                        }
                    }
                }

                MouseArea {
                    id: hovPlay
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.togglePlayPause()
                }
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 19
                color: theme.surfaceVariant

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue044"
                    iconSize: 20
                    iconColor: theme.onSurface
                }

                scale: hovNext.pressed ? 0.9 : (hovNext.containsMouse ? 1.06 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MouseArea {
                    id: hovNext
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.next()
                }
            }

            Rectangle {
                id: repeatBtn
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 19
                color: library.repeatMode > 0 ? theme.primary : theme.surfaceVariant

                Behavior on color { ColorAnimation { duration: 220 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: library.repeatMode === 2 ? "\ue041" : "\ue040"
                    iconSize: 18
                    iconColor: library.repeatMode > 0 ? theme.background : theme.onSurface
                    Behavior on iconColor { ColorAnimation { duration: 220 } }
                }

                scale: hovRepeat.pressed ? 0.9 : (hovRepeat.containsMouse ? 1.06 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MouseArea {
                    id: hovRepeat
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.cycleRepeat()
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: 140
            Layout.minimumWidth: 100
            Layout.maximumWidth: 140
            Layout.fillHeight: true
            spacing: 8

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue04f"
                    iconSize: 18
                    iconColor: theme.outline
                    opacity: library.volume === 0 ? 1 : 0
                    scale: library.volume === 0 ? 1.0 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue050"
                    iconSize: 18
                    iconColor: theme.outline
                    opacity: library.volume === 0 ? 0 : 1
                    scale: library.volume === 0 ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                }
            }

            Item {
                id: volArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real vol: library.volume / 100

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: volHover.hovered ? 8 : 5
                    radius: height / 2
                    color: theme.surfaceVariant
                    Behavior on height { NumberAnimation { duration: 180 } }

                    Rectangle {
                        width: parent.width * volArea.vol
                        height: parent.height
                        radius: parent.radius
                        color: theme.onSurface
                    }
                }

                Rectangle {
                    width: volHover.hovered || volMouse.pressed ? 12 : 0
                    height: width
                    radius: width / 2
                    color: theme.onSurface
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * volArea.vol - width / 2
                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                }

                HoverHandler {
                    id: volHover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => { library.volume = Math.round(mouse.x / width * 100) }
                    onPositionChanged: (mouse) => {
                        if (pressed) library.volume = Math.round(mouse.x / width * 100)
                    }
                }
            }
        }
    }
}