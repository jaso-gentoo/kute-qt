import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: bar
    radius: 20
    color: theme.surface

    signal coverClicked

    property string sTitle: ""
    property string sArtist: ""
    property string sCover: ""

    function snapshot() {
        sTitle = library.currentTitle
        sArtist = library.currentArtist
        sCover = library.currentCover
    }

    Component.onCompleted: snapshot()

    Connections {
        target: library
        function onCurrentChanged() {
            if (!library.hasCurrent) {
                snapshot()
                return
            }
            trackAnim.restart()
        }
    }

    readonly property string displayTitle: {
        if (!library.hasCurrent) return "—"
        const t = sTitle
        return t.length > 34 ? t.substring(0, 32) + "…" : t
    }

    readonly property bool currentLiked: {
        library.likedRevision
        library.currentIndex
        return library.isCurrentLiked()
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
            Layout.preferredWidth: 230
            Layout.minimumWidth: 80
            Layout.maximumWidth: 250
            Layout.fillHeight: true
            spacing: 10

            Item {
                id: coverWrap
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                Layout.alignment: Qt.AlignVCenter
                transformOrigin: Item.Center

                transform: Translate { id: coverShift; y: 0 }

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: theme.surfaceVariant
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue405"
                    iconSize: 20
                    iconColor: theme.outline
                    visible: !bar.sCover || coverImg.status !== Image.Ready
                    z: 2
                }

                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: bar.sCover ? library.toFileUrl(bar.sCover) + "?v=" + library.coverVersion : ""
                    sourceSize.width: 92
                    sourceSize.height: 92
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    visible: false
                }

                Item {
                    id: coverMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: "white"
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: coverImg
                    maskEnabled: true
                    maskSource: coverMask
                    visible: coverImg.status === Image.Ready
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
                id: textCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                clip: true

                transform: Translate { id: textShift; y: 0 }

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
                    text: library.hasCurrent ? bar.sArtist : ""
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                visible: library.hasCurrent

                Item {
                    id: heartIconWrap
                    anchors.fill: parent
                    opacity: bar.currentLiked ? 1.0 : 0.45
                    scale: hovLike.pressed ? 0.8 : (hovLike.containsMouse ? 1.15 : 1.0)

                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.8
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        glyph: "\ue87d"
                        iconSize: 18
                        filled: bar.currentLiked
                        iconColor: bar.currentLiked ? theme.primary : theme.onSurface
                        Behavior on iconColor { ColorAnimation { duration: 240 } }
                    }
                }

                MouseArea {
                    id: hovLike
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: library.toggleCurrentLike()
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 4
                    width: likeTipTxt.implicitWidth + 16
                    height: 24
                    radius: 8
                    color: theme.surface
                    border.color: theme.outline
                    border.width: 1
                    opacity: hovLike.containsMouse ? 1 : 0
                    visible: opacity > 0
                    z: 9999
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        id: likeTipTxt
                        anchors.centerIn: parent
                        text: bar.currentLiked ? "Remove from Liked (Ctrl+W)" : "Add to Liked (Ctrl+W)"
                        color: theme.onSurface
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
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
                    id: progDot
                    readonly property bool paused: library.hasCurrent
                                                   && !library.isPlaying
                                                   && library.position > 0

                    width: progHover.hovered || progMouse.pressed
                           ? 14
                           : (paused ? 10 : 0)
                    height: width
                    radius: width / 2
                    color: theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * progArea.progress - width / 2

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }

                    SequentialAnimation on scale {
                        running: progDot.paused && !progHover.hovered && !progMouse.pressed
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 1.25
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0.85
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }

                    Behavior on scale {
                        enabled: !(progDot.paused && !progHover.hovered && !progMouse.pressed)
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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

    SequentialAnimation {
        id: trackAnim

        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "opacity"
                to: 0.15; duration: 220; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: coverShift; property: "y"
                to: -10; duration: 240; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: textShift; property: "y"
                to: -10; duration: 240; easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                bar.snapshot()
                coverShift.y = 10
                textShift.y = 10
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: bar; property: "opacity"
                to: 1.0; duration: 320; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: coverShift; property: "y"
                to: 0; duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
            NumberAnimation {
                target: textShift; property: "y"
                to: 0; duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }
    }
}