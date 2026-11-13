import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: panel
    color: theme.surface
    radius: 16
    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)
    border.width: 1
    clip: true

    signal requestHide


    readonly property int coverSize: 165
    readonly property real dpr: Screen.devicePixelRatio > 0
        ? Screen.devicePixelRatio : 1
    readonly property int coverDecodeSize: Math.min(500, Math.ceil(coverSize * dpr * 2))
    readonly property int ringGap: 9
    readonly property int ringRectSize: coverSize + ringGap * 2
    readonly property int waveAmp: 5
    readonly property int waveLineWidth: 3
    readonly property int ringPad: Math.ceil(waveAmp + waveLineWidth / 2 + 1)
    readonly property int ringCanvasSize: ringRectSize + ringPad * 2
    implicitHeight: 254 + infoWrap.height

    readonly property int currentRingRadius: ringRectSize / 2
    readonly property string coverShape: theme.coverShape
    property real shapeRotation: 0

    function shapeSides() {
        if (coverShape === "pentagon") return 5
        if (coverShape === "hexagon") return 6
        if (coverShape === "octagon") return 8
        if (coverShape === "decagon") return 10
        if (coverShape === "dodecagon") return 12
        if (coverShape === "hexadecagon") return 16
        return 0
    }

    function shapeR(sz, shape) {
        var hsz = sz / 2
        if (shape === "pentagon") return hsz * 1.05
        if (shape === "hexagon") return hsz * 1.05
        if (shape === "octagon") return hsz * 1
        if (shape === "sun") return hsz * 1
        if (shape === "star") return hsz * 1
        if (shape === "flower") return hsz * 1
        if (shape === "blob") return hsz * 0.87
        return hsz - 2
    }

    function drawShapePath(ctx, cx, cy, sz, shape, color) {
        var r = shapeR(sz, shape)
        ctx.beginPath()
        if (shape === "circle") {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        } else if (shape === "pentagon") {
            drawRoundedPoly(ctx, cx, cy, r, 5, sz * 0.08)
        } else if (shape === "hexagon") {
            drawRoundedPoly(ctx, cx, cy, r, 6, sz * 0.08)
        } else if (shape === "octagon") {
            drawRoundedPoly(ctx, cx, cy, r, 8, sz * 0.08)
        } else if (shape === "sun") {
            drawHarmonic(ctx, cx, cy, r, 16, 0.05)
        } else if (shape === "star") {
            drawHarmonic(ctx, cx, cy, r, 5, 0.10)
        } else if (shape === "flower") {
            drawHarmonic(ctx, cx, cy, r, 12, 0.05)
        } else if (shape === "blob") {
            drawBlob(ctx, cx, cy, r, 0.55)
        } else {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        }
        ctx.closePath()
        if (color !== null && color !== undefined) {
            ctx.fillStyle = color
            ctx.fill()
        }
    }

    function drawHarmonic(ctx, cx, cy, r, lobes, depth) {
        var steps = 240
        for (var i = 0; i <= steps; i++) {
            var a = i / steps * Math.PI * 2
            var rr = r * (1 - depth + depth * Math.cos(lobes * a))
            var x = cx + rr * Math.cos(a)
            var y = cy + rr * Math.sin(a)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
    }

    function drawRoundedPoly(ctx, cx, cy, r, sides, rad) {
        var pts = []
        var start = -Math.PI / 2
        for (var i = 0; i < sides; i++) {
            var a = start + i * 2 * Math.PI / sides
            pts.push({x: cx + r * Math.cos(a), y: cy + r * Math.sin(a)})
        }
        var m0x = (pts[sides - 1].x + pts[0].x) / 2
        var m0y = (pts[sides - 1].y + pts[0].y) / 2
        ctx.moveTo(m0x, m0y)
        for (var j = 0; j < sides; j++) {
            var cur = pts[j]
            var nxt = pts[(j + 1) % sides]
            var mnx = (cur.x + nxt.x) / 2
            var mny = (cur.y + nxt.y) / 2
            ctx.arcTo(cur.x, cur.y, mnx, mny, rad)
        }
    }

    function drawSpiked(ctx, cx, cy, r, spikes, innerRatio) {
        var total = spikes * 2
        var start = -Math.PI / 2
        for (var i = 0; i < total; i++) {
            var a = start + i * Math.PI / spikes
            var rr = (i % 2 === 0) ? r : r * innerRatio
            var x = cx + rr * Math.cos(a)
            var y = cy + rr * Math.sin(a)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
    }

    function drawFlower(ctx, cx, cy, r, petals, depth) {
        var steps = 180
        for (var i = 0; i <= steps; i++) {
            var a = i / steps * Math.PI * 2
            var rr = r * (1 - depth + depth * Math.cos(petals * a))
            var x = cx + rr * Math.cos(a)
            var y = cy + rr * Math.sin(a)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
    }

    function drawBlob(ctx, cx, cy, r, e) {
        var steps = 240
        for (var i = 0; i <= steps; i++) {
            var a = i / steps * Math.PI * 2
            var c = Math.cos(a)
            var sn = Math.sin(a)
            var x = cx + r * Math.sign(c) * Math.pow(Math.abs(c), e)
            var y = cy + r * Math.sign(sn) * Math.pow(Math.abs(sn), e)
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
        }
    }

    NumberAnimation {
        target: panel
        property: "shapeRotation"
        from: 0
        to: 360
        duration: 24000
        loops: Animation.Infinite
        running: true
        paused: !library.isPlaying
    }

    property bool seeking: false

    property string dTitle: library.currentTitle
    property string dArtist: library.currentArtist
    property string dAlbum: library.currentAlbum
    property bool dHasCurrent: library.hasCurrent

    property string _lastInfoSig: ""

    function _infoSig() {
        return library.currentFilePath + "|" + library.currentTitle + "|"
             + library.currentArtist + "|" + library.currentAlbum
    }

    function snapshot() {
        dTitle = library.currentTitle
        dArtist = library.currentArtist
        dAlbum = library.currentAlbum
        dHasCurrent = library.hasCurrent
    }

    function isOnCover(mx, my) {
        const cx = coverBox.x + coverBox.width / 2
        const cy = coverBox.y + coverBox.height / 2
        const half = coverBox.width / 2
        const dx = mx - cx
        const dy = my - cy
        const dist = Math.sqrt(dx * dx + dy * dy)
        var shapeRad = half * 0.93
        if (panel.coverShape === "pentagon") shapeRad = half * 0.95
        else if (panel.coverShape === "hexagon") shapeRad = half * 0.96
        else if (panel.coverShape === "star") shapeRad = half * 0.95
        else if (panel.coverShape === "blob") shapeRad = half * 0.85
        else if (panel.coverShape === "flower") shapeRad = half * 0.97
        return dist <= shapeRad
    }

    Component.onCompleted: {
        snapshot()
        _lastInfoSig = _infoSig()
    }

    Connections {
        target: library
        function onCurrentChanged() {
            const s = panel._infoSig()
            if (s === panel._lastInfoSig) return
            panel._lastInfoSig = s
            infoAnim.restart()
            coverBox.startCrossfade()
        }
        function onCoverVersionChanged() { coverBox.startCrossfade() }
    }

    SequentialAnimation {
        id: infoAnim
        ParallelAnimation {
            NumberAnimation { target: infoWrap; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: infoShift; property: "y"; to: 6; duration: 120; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { panel.snapshot(); infoShift.y = -6 } }
        ParallelAnimation {
            NumberAnimation { target: infoWrap; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: infoShift; property: "y"; to: 0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }

    Rectangle {
        id: nowPlayingChip
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: chipRow.implicitWidth + 22
        height: 24
        radius: 12
        color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.14)
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
        border.width: 1
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: library.isPlaying ? "" : ""
                iconSize: 11
                iconColor: theme.primary
                filled: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "NOW PLAYING"
                color: theme.primary
                font.pixelSize: 9
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
            }
        }
    }

    Item {
        id: contentStack
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: coverArea.height + infoWrap.height - 4

        property real _targetY: {
            const topMin = 44
            const avail = panel.height - contentStack.height
            if (avail <= topMin) return topMin
            switch (theme.infoPanelPosition) {
                case "center": return Math.max(topMin, avail / 2)
                case "bottom": return Math.max(topMin, avail - 8)
                default:       return topMin
            }
        }

        y: _targetY

        Behavior on y {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        Item {
            id: coverArea
            y: 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.ringCanvasSize
            height: panel.ringCanvasSize

        Canvas {
            id: ringCanvas
            anchors.centerIn: parent
            width: panel.ringCanvasSize
            height: panel.ringCanvasSize
            z: 3
            property real phase: 0
            property real progress: 0
            property string _lastPath: ""

            Behavior on progress {
                id: ringProgressBehavior
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Component.onCompleted: {
                _lastPath = library.currentFilePath
                ringProgressBehavior.enabled = false
                progress = library.duration > 0
                    ? Math.min(1, Math.max(0, library.position / library.duration))
                    : 0
                ringProgressBehavior.enabled = true
            }

            Connections {
                target: library
                function onPositionChanged() {
                    ringCanvas.progress = library.duration > 0
                        ? Math.min(1, Math.max(0, library.position / library.duration))
                        : 0
                }
                function onDurationChanged() {
                    ringCanvas.progress = library.duration > 0
                        ? Math.min(1, Math.max(0, library.position / library.duration))
                        : 0
                }
                function onCurrentChanged() {
                    if (library.currentFilePath === ringCanvas._lastPath) return
                    ringCanvas._lastPath = library.currentFilePath
                    ringProgressBehavior.enabled = false
                    ringCanvas.progress = 0
                    Qt.callLater(function() { ringProgressBehavior.enabled = true })
                }
            }

            Timer {
                interval: 55
                running: library.isPlaying
                repeat: true
                onTriggered: { ringCanvas.phase += 0.13; ringCanvas.requestPaint() }
            }

            onProgressChanged: requestPaint()
            onPhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: panel
                function onCurrentRingRadiusChanged() { ringCanvas.requestPaint() }
            }

            function segLens(w, h, r) {
                var arc = Math.PI * r / 2
                var lw = Math.max(0, w - 2 * r)
                var lh = Math.max(0, h - 2 * r)
                return [lw, arc, lh, arc, lw, arc, lh, arc]
            }

            function segPoint(s, local, x0, y0, w, h, r) {
                var a
                switch (s) {
                    case 0: return { x: x0 + r + local, y: y0, nx: 0, ny: -1 }
                    case 1:
                        a = -Math.PI / 2 + local / r
                        return { x: x0 + w - r + Math.cos(a) * r, y: y0 + r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                    case 2: return { x: x0 + w, y: y0 + r + local, nx: 1, ny: 0 }
                    case 3:
                        a = local / r
                        return { x: x0 + w - r + Math.cos(a) * r, y: y0 + h - r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                    case 4: return { x: x0 + w - r - local, y: y0 + h, nx: 0, ny: 1 }
                    case 5:
                        a = Math.PI / 2 + local / r
                        return { x: x0 + r + Math.cos(a) * r, y: y0 + h - r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                    case 6: return { x: x0, y: y0 + h - r - local, nx: -1, ny: 0 }
                    case 7:
                        a = Math.PI + local / r
                        return { x: x0 + r + Math.cos(a) * r, y: y0 + r + Math.sin(a) * r, nx: Math.cos(a), ny: Math.sin(a) }
                }
                return { x: 0, y: 0, nx: 0, ny: 0 }
            }

            function pointAt(d, x0, y0, w, h, r, lens, perim) {
                d = ((d % perim) + perim) % perim
                var cum = 0
                for (var s = 0; s < 8; s++) {
                    if (d <= cum + lens[s] + 0.0001) return segPoint(s, d - cum, x0, y0, w, h, r)
                    cum += lens[s]
                }
                return segPoint(7, lens[7], x0, y0, w, h, r)
            }

            function clickToProgress(mx, my) {
                var pad = panel.ringPad
                var x0 = pad
                var y0 = pad
                var w = width - 2 * pad
                var h = height - 2 * pad
                var r = panel.currentRingRadius - 2
                var lens = segLens(w, h, r)
                var perim = 0
                for (var i = 0; i < 8; i++) perim += lens[i]

                var bestDist2 = 1e18
                var bestArc = 0
                var cum = 0
                for (var s = 0; s < 8; s++) {
                    var segLen = lens[s]
                    if (segLen <= 0) { cum += segLen; continue }
                    var samples = Math.max(4, Math.ceil(segLen / 3))
                    for (var k = 0; k <= samples; k++) {
                        var local = k / samples * segLen
                        var p = segPoint(s, local, x0, y0, w, h, r)
                        var ddx = p.x - mx
                        var ddy = p.y - my
                        var d2 = ddx * ddx + ddy * ddy
                        if (d2 < bestDist2) {
                            bestDist2 = d2
                            bestArc = cum + local
                        }
                    }
                    cum += segLen
                }
                var adjusted = ((bestArc - lens[0] / 2) % perim + perim) % perim
                return Math.max(0, Math.min(1, adjusted / perim))
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                if (width < 4 || height < 4) return

                var pad = panel.ringPad
                var x0 = pad
                var y0 = pad
                var w = width - 2 * pad
                var h = height - 2 * pad
                var r = panel.currentRingRadius - 2
                if (w < 4 || h < 4) return

                var lens = segLens(w, h, r)
                var perim = 0
                for (var i = 0; i < 8; i++) perim += lens[i]

                var startOffset = lens[0] / 2
                var gap = 8

                if (progress < 0.999) {
                    var bgStart = startOffset + perim * progress + gap
                    var bgLen = perim * (1 - progress) - 2 * gap
                    if (bgLen > 4) {
                        var bgSteps = Math.max(120, Math.floor(bgLen / 2))

                        ctx.beginPath()
                        ctx.strokeStyle = theme.surfaceVariant
                        ctx.lineWidth = panel.waveLineWidth
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"

                        for (var j = 0; j <= bgSteps; j++) {
                            var dj = bgStart + (j / bgSteps) * bgLen
                            var pj = pointAt(dj, x0, y0, w, h, r, lens, perim)
                            if (j === 0) ctx.moveTo(pj.x, pj.y)
                            else ctx.lineTo(pj.x, pj.y)
                        }
                        ctx.stroke()
                    }
                }

                if (progress > 0.001) {
                    var progLen = perim * progress
                    var steps = Math.max(120, Math.floor(progLen / 2))

                    ctx.beginPath()
                    ctx.strokeStyle = theme.primary
                    ctx.lineWidth = panel.waveLineWidth
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    for (var i = 0; i <= steps; i++) {
                        var t = i / steps
                        var d = startOffset + t * progLen
                        var p = pointAt(d, x0, y0, w, h, r, lens, perim)
                        var wave = Math.sin(d / 8 + phase) * panel.waveAmp
                        var x = p.x + p.nx * wave
                        var y = p.y + p.ny * wave
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
        }

        Item {
            id: coverBox
            anchors.centerIn: parent
            width: panel.coverSize
            height: panel.coverSize

            property string liveSource: ""
            property string prevSource: ""
            property bool pendingFade: false
            property real prevAlpha: 0
            property real liveAlpha: 1

            function currentCoverSource() {
                return library.currentCover ? library.toFileUrl(library.currentCover) + "?v=" + library.coverVersion : ""
            }

            function startCrossfade() {
                const newSrc = currentCoverSource()
                if (newSrc === liveSource) return
                prevSource = liveSource
                liveSource = newSrc
                prevAlpha = 1
                liveAlpha = 0
                pendingFade = true
                tryStartFade()
            }

            function tryStartFade() {
                if (!pendingFade) return
                const ready = (liveSource === "") || (liveImg.status === Image.Ready)
                if (!ready) return
                pendingFade = false
                crossfadeAnim.restart()
            }

            Component.onCompleted: liveSource = currentCoverSource()

            Image {
                id: prevImg
                anchors.centerIn: parent
                width: panel.coverSize + 20
                height: panel.coverSize + 20
                source: coverBox.prevSource
                sourceSize.width: panel.coverDecodeSize
                sourceSize.height: panel.coverDecodeSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: false
                onStatusChanged: renderCanvas.requestPaint()
            }

            Image {
                id: liveImg
                anchors.centerIn: parent
                width: panel.coverSize + 20
                height: panel.coverSize + 20
                source: coverBox.liveSource
                sourceSize.width: panel.coverDecodeSize
                sourceSize.height: panel.coverDecodeSize
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: false
                onStatusChanged: { coverBox.tryStartFade(); renderCanvas.requestPaint() }
            }

            Canvas {
                id: renderCanvas
                anchors.centerIn: parent
                width: panel.coverSize + 20
                height: panel.coverSize + 20
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var sz = width
                    var cx = sz / 2
                    var cy = sz / 2

                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(panel.shapeRotation * Math.PI / 180)
                    panel.drawShapePath(ctx, 0, 0, panel.coverSize, panel.coverShape, null)
                    ctx.clip()

                    var hasPrev = prevImg.status === Image.Ready && coverBox.prevAlpha > 0.001
                    var hasLive = liveImg.status === Image.Ready && coverBox.liveAlpha > 0.001

                    ctx.setTransform(1, 0, 0, 1, 0, 0)

                    var shapeRad = panel.shapeR(panel.coverSize, panel.coverShape)
                    var iszMul = 1.05
                    if (panel.coverShape === "blob") iszMul = 1.25
                    var isz = shapeRad * 2 * iszMul
                    var ioff = (sz - isz) / 2

                    if (!hasPrev && !hasLive) {
                        ctx.fillStyle = theme.surfaceVariant
                        ctx.fillRect(ioff, ioff, isz, isz)
                        ctx.fillStyle = theme.outline
                        ctx.globalAlpha = 0.45
                        ctx.font = Math.round(panel.coverSize * 0.30) + "px " + String.fromCharCode(39) + "Material Symbols Rounded" + String.fromCharCode(39)
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText(String.fromCharCode(0xE405), cx, cy)
                        ctx.globalAlpha = 1
                    } else {
                        if (hasPrev) {
                            ctx.globalAlpha = coverBox.prevAlpha
                            ctx.drawImage(prevImg, ioff, ioff, isz, isz)
                        }
                        if (hasLive) {
                            ctx.globalAlpha = coverBox.liveAlpha
                            ctx.drawImage(liveImg, ioff, ioff, isz, isz)
                        }
                        ctx.globalAlpha = 1
                    }
                    ctx.restore()
                }
                Connections {
                    target: panel
                    function onShapeRotationChanged() { renderCanvas.requestPaint() }
                    function onCoverShapeChanged() { renderCanvas.requestPaint() }
                }
                Connections {
                    target: coverBox
                    function onPrevAlphaChanged() { renderCanvas.requestPaint() }
                    function onLiveAlphaChanged() { renderCanvas.requestPaint() }
                    function onPrevSourceChanged() { renderCanvas.requestPaint() }
                    function onLiveSourceChanged() { renderCanvas.requestPaint() }
                }
                Connections {
                    target: theme
                    function onChanged() { renderCanvas.requestPaint() }
                }
                Component.onCompleted: requestPaint()
            }

            ParallelAnimation {
                id: crossfadeAnim
                NumberAnimation { target: coverBox; property: "prevAlpha"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { target: coverBox; property: "liveAlpha"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: coverMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: panel.isOnCover(mouseX, mouseY) ? Qt.ArrowCursor : Qt.PointingHandCursor

            onPressed: (mouse) => {
                if (!panel.isOnCover(mouse.x, mouse.y)) {
                    panel.seeking = true
                    if (library.duration > 0) {
                        var p = ringCanvas.clickToProgress(mouse.x, mouse.y)
                        library.seek(library.duration * p)
                    }
                }
            }
            onPositionChanged: (mouse) => {
                if (panel.seeking && pressed && library.duration > 0) {
                    var p = ringCanvas.clickToProgress(mouse.x, mouse.y)
                    library.seek(library.duration * p)
                }
            }
            onReleased: (mouse) => { panel.seeking = false }
        }
    }

    Item {
        id: infoWrap
        anchors.top: coverArea.bottom
        anchors.topMargin: -4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: infoCol.implicitHeight

            transform: Translate { id: infoShift; y: 0 }

            ColumnLayout {
                id: infoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: panel.dHasCurrent ? panel.dTitle : "Nothing playing"
                    color: theme.onBackground
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    text: panel.dHasCurrent ? panel.dArtist : "—"
                    color: theme.outline
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: (panel.dHasCurrent && panel.dAlbum !== "Unknown Album") ? panel.dAlbum : ""
                    color: theme.outline
                    font.pixelSize: 11
                    opacity: 0.7
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                }
            }
        }
        }
}
