import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: bar
    radius: 16
    color: theme.surface

    signal coverClicked
    signal likeClicked

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
                trackAnim.stop()
                bar.opacity = 1
                coverWrap.opacity = 1
                textCol.opacity = 1
                coverShift.y = 0
                textShift.y = 0
                snapshot()
                return
            }
            trackAnim.stop()
            bar.opacity = 1
            coverWrap.opacity = 1
            textCol.opacity = 1
            coverShift.y = 0
            textShift.y = 0
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
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            Layout.maximumWidth: 250
            Layout.fillHeight: true
            spacing: 10

            Item {
                id: coverWrap
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                transformOrigin: Item.Center

                transform: Translate { id: coverShift; y: 0 }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
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
                    readonly property real dpr: Screen.devicePixelRatio > 0
                                                    ? Screen.devicePixelRatio : 1
                    readonly property int decodeSize: Math.ceil(48 * dpr)
                    anchors.fill: parent
                    source: bar.sCover ? library.toFileUrl(bar.sCover) + "?v=" + library.coverVersion : ""
                    sourceSize.width: decodeSize
                    sourceSize.height: decodeSize
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
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
                        radius: 10
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
                    radius: 10
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
        }

        Item {
            id: progArea
            Layout.fillWidth: true
            Layout.minimumWidth: 160
            Layout.fillHeight: true

            Canvas {
                id: progressBar
                anchors.fill: parent
                anchors.bottomMargin: 14
                property real progress: library.duration > 0 ? library.position / library.duration : 0
                property real wavePhase: 0
                property bool hovering: progHover.hovered || progMouse.pressed

                property real lineW: 3
                property real maxAmp: 3
                property real phH: 12
                property real phW: 4

                onProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onLineWChanged: requestPaint()
                onMaxAmpChanged: requestPaint()
                onPhHChanged: requestPaint()
                onPhWChanged: requestPaint()

                onHoveringChanged: {
                    lineWAnim.to  = hovering ? 4 : 3
                    maxAmpAnim.to = hovering ? 4 : 3
                    phHAnim.to    = hovering ? 16 : 12
                    phWAnim.to    = hovering ? 6 : 4
                    lineWAnim.restart()
                    maxAmpAnim.restart()
                    phHAnim.restart()
                    phWAnim.restart()
                }

                NumberAnimation { id: lineWAnim;  target: progressBar; property: "lineW";  duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { id: maxAmpAnim; target: progressBar; property: "maxAmp"; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { id: phHAnim;    target: progressBar; property: "phH";    duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { id: phWAnim;    target: progressBar; property: "phW";    duration: 180; easing.type: Easing.OutCubic }

                Timer {
                    interval: 50
                    running: library.isPlaying
                    repeat: true
                    onTriggered: {
                        progressBar.wavePhase += 0.12
                        progressBar.requestPaint()
                    }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cy = height / 2
                    var waveLen = 30

                    ctx.beginPath()
                    ctx.strokeStyle = theme.surfaceVariant
                    ctx.lineWidth = progressBar.lineW
                    ctx.lineCap = "round"
                    ctx.moveTo(0, cy)
                    ctx.lineTo(width, cy)
                    ctx.stroke()

                    if (progress > 0) {
                        var endX = width * progress
                        var steps = Math.max(30, Math.floor(endX / 2))

                        ctx.beginPath()
                        ctx.strokeStyle = theme.primary
                        ctx.lineWidth = progressBar.lineW
                        ctx.lineCap = "round"

                        for (var i = 0; i <= steps; i++) {
                            var x = (i / steps) * endX
                            var fadeIn = Math.min(1, x / 30)
                            var wave = Math.sin(x / waveLen * Math.PI * 2 + wavePhase) * progressBar.maxAmp * fadeIn
                            var y = cy + wave
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        var phX = endX - progressBar.phW / 2 + 2
                        if (phX < 5) phX = 5
                        var phY = cy - progressBar.phH / 2
                        var phR = progressBar.phW / 2
                        ctx.beginPath()
                        ctx.fillStyle = theme.primary
                        ctx.moveTo(phX + phR, phY)
                        ctx.lineTo(phX + progressBar.phW - phR, phY)
                        ctx.arcTo(phX + progressBar.phW, phY, phX + progressBar.phW, phY + phR, phR)
                        ctx.lineTo(phX + progressBar.phW, phY + progressBar.phH - phR)
                        ctx.arcTo(phX + progressBar.phW, phY + progressBar.phH, phX + progressBar.phW - phR, phY + progressBar.phH, phR)
                        ctx.lineTo(phX + phR, phY + progressBar.phH)
                        ctx.arcTo(phX, phY + progressBar.phH, phX, phY + progressBar.phH - phR, phR)
                        ctx.lineTo(phX, phY + phR)
                        ctx.arcTo(phX, phY, phX + phR, phY, phR)
                        ctx.closePath()
                        ctx.fill()
                    }

                    var smH = 12
                    var smW = 4
                    var smX = 0
                    var smY = cy - smH / 2
                    var smR = smW / 2
                    ctx.beginPath()
                    ctx.fillStyle = theme.primary
                    ctx.moveTo(smX + smR, smY)
                    ctx.lineTo(smX + smW - smR, smY)
                    ctx.arcTo(smX + smW, smY, smX + smW, smY + smR, smR)
                    ctx.lineTo(smX + smW, smY + smH - smR)
                    ctx.arcTo(smX + smW, smY + smH, smX + smW - smR, smY + smH, smR)
                    ctx.lineTo(smX + smR, smY + smH)
                    ctx.arcTo(smX, smY + smH, smX, smY + smH - smR, smR)
                    ctx.lineTo(smX, smY + smR)
                    ctx.arcTo(smX, smY, smX + smR, smY, smR)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 12

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

            HoverHandler {
                id: progHover
                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                id: progMouse
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
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

        RowLayout {
            Layout.preferredWidth: 200
            Layout.minimumWidth: 200
            Layout.maximumWidth: 220
            Layout.fillHeight: true
            spacing: 4

            Item {
                id: likeBtn
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                visible: library.hasCurrent

                Item {
                    anchors.fill: parent
                    opacity: bar.currentLiked ? 1.0 : 0.45
                    scale: likeHov.pressed ? 0.8 : (likeHov.containsMouse ? 1.15 : 1.0)

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
                    id: likeHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.likeClicked()
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: hovPrev.containsMouse
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 180 } }

                scale: hovPrev.pressed ? 0.9 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue045"
                    iconSize: 18
                    iconColor: theme.onSurface
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
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                color: theme.primary

                scale: hovPlay.pressed ? 0.9 : (hovPlay.containsMouse ? 1.04 : 1.0)
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
                        iconSize: 22
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
                        iconSize: 22
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
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: hovNext.containsMouse
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 180 } }

                scale: hovNext.pressed ? 0.9 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue044"
                    iconSize: 18
                    iconColor: theme.onSurface
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
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: library.repeatMode > 0
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.18)
                    : (hovRepeat.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                        : "transparent")
                Behavior on color { ColorAnimation { duration: 220 } }

                scale: hovRepeat.pressed ? 0.9 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 3.0
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: library.repeatMode === 2 ? "\ue041" : "\ue040"
                    iconSize: 17
                    iconColor: library.repeatMode > 0 ? theme.primary : theme.onSurface
                    Behavior on iconColor { ColorAnimation { duration: 220 } }
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
            Layout.preferredWidth: 128
            Layout.minimumWidth: 128
            Layout.maximumWidth: 128
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
                readonly property int barWidth: 2
                readonly property int barSpacing: 1

                Row {
                    id: volWave
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -13
                    height: 12
                    spacing: volArea.barSpacing
                    clip: true

                    readonly property var spec: library.visualizer.spectrum
                    readonly property int specLen: spec ? spec.length : 0
                    readonly property int barSlotWidth: volArea.barWidth + volArea.barSpacing
                    readonly property int visibleBars: Math.max(0,
                        Math.floor((width + volArea.barSpacing) / barSlotWidth))
                    readonly property int halfBars: Math.floor(visibleBars / 2)

                    opacity: library.isPlaying ? 1.0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: volWave.visibleBars
                        delegate: Item {
                            required property int index
                            width: volArea.barWidth
                            height: volWave.height

                            readonly property int mirrorIdx: {
                                const hb = volWave.halfBars
                                if (hb <= 0) return index
                                if (index < hb) return index
                                return volWave.visibleBars - 1 - index
                            }
                            readonly property int srcIdx: {
                                const hb = volWave.halfBars
                                if (hb <= 0 || volWave.specLen <= 0) return -1
                                return Math.min(volWave.specLen - 1,
                                                Math.floor(mirrorIdx * volWave.specLen / hb))
                            }
                            readonly property real level: {
                                if (srcIdx < 0) return 0
                                const s = volWave.spec[srcIdx]
                                return s === undefined ? 0 : s
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                height: Math.max(2, level * parent.height)
                                radius: width / 2
                                color: theme.onSurface
                                Behavior on height {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: volBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: volHover.hovered ? 6 : 4
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
                    width: volHover.hovered || volMouse.pressed ? 10 : 0
                    height: width
                    radius: width / 2
                    color: theme.onSurface
                    x: volBar.x + volBar.width * volArea.vol - width / 2
                    y: volBar.y + volBar.height / 2 - height / 2
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
                target: coverWrap; property: "opacity"
                to: 0.0; duration: 180; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: textCol; property: "opacity"
                to: 0.0; duration: 180; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: coverShift; property: "y"
                to: -10; duration: 200; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: textShift; property: "y"
                to: -10; duration: 200; easing.type: Easing.InCubic
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
                target: coverWrap; property: "opacity"
                to: 1.0; duration: 320; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: textCol; property: "opacity"
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
