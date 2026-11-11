import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: opacity > 0.01
    opacity: isActive ? 1 : 0
    enabled: isActive
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    signal folderRequested

    property bool restartOpen: false

    readonly property bool lightLocked: theme.matugenEnabled
    readonly property bool matugenLocked: theme.lightTheme || !theme.matugenAvailable

    function shapeR(sz, shape) {
        var hsz = sz / 2
        if (shape === "pentagon") return hsz * 0.97
        if (shape === "hexagon") return hsz * 0.98
        if (shape === "octagon") return hsz * 0.99
        if (shape === "sun") return hsz * 0.99
        if (shape === "star") return hsz * 0.97
        if (shape === "flower") return hsz * 0.99
        if (shape === "blob") return hsz * 0.90
        return hsz - 1
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
        if (color) {
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

    component ShapePreviewBtn: Rectangle {
        id: spb
        property string shapeKey: ""
        readonly property bool isActive: theme.coverShape === shapeKey

        Layout.preferredWidth: 30
        Layout.preferredHeight: 28
        radius: 8
        color: spb.isActive
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
            : (spbHov.containsMouse
                ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05))
        Behavior on color { ColorAnimation { duration: 160 } }

        Canvas {
            id: spbCanvas
            anchors.fill: parent
            anchors.margins: -10
            opacity: spb.isActive ? 1.0 : 0.55
            Behavior on opacity { NumberAnimation { duration: 160 } }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var sz = 14
                tab.drawShapePath(ctx, width / 2, height / 2, sz, spb.shapeKey, theme.primary)
            }
            Connections {
                target: spb
                function onIsActiveChanged() { spbCanvas.requestPaint() }
            }
            Connections {
                target: theme
                function onCoverShapeChanged() { spbCanvas.requestPaint() }
                function onChanged() { spbCanvas.requestPaint() }
            }
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: spbHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: theme.coverShape = spb.shapeKey
        }
    }

    component ModalSection: ColumnLayout {
        id: secRoot
        property string title: ""
        property string icon: ""
        default property alias content: secBox.data

        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.leftMargin: 2
            spacing: 10

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.20)
                }

                Icon {
                    anchors.centerIn: parent
                    glyph: secRoot.icon
                    iconSize: 15
                    iconColor: theme.onBackground
                }
            }

            Text {
                text: secRoot.title
                color: theme.onBackground
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            id: secBox
            Layout.fillWidth: true
            spacing: 4
        }
    }

    component GroupedList: Rectangle {
        id: groupedList
        default property alias items: innerCol.data

        Layout.fillWidth: true
        implicitHeight: innerCol.implicitHeight + 8
        radius: 14
        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.03)
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
        border.width: 1

        ColumnLayout {
            id: innerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 0
        }
    }

    component SettingRow: Rectangle {
        id: setRow
        property string icon: ""
        property string label: ""
        property string description: ""
        property bool   rowChecked: false
        property bool   rowEnabled: true
        signal toggled

        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 10
        color: setRowHov.containsMouse && setRow.rowEnabled
            ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        opacity: setRow.rowEnabled ? 1.0 : 0.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Icon {
                glyph: setRow.icon
                iconSize: 18
                iconColor: theme.onBackground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: setRow.label
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: setRow.description
                    color: theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 21
                radius: 11
                color: setRow.rowChecked
                    ? theme.primary
                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.20)
                Behavior on color { ColorAnimation { duration: 220 } }

                Rectangle {
                    width: 15
                    height: 15
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: setRow.rowChecked ? parent.width - width - 3 : 3
                    color: setRow.rowChecked ? theme.surface : theme.onBackground
                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        MouseArea {
            id: setRowHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: setRow.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: setRow.rowEnabled
            onClicked: setRow.toggled()
        }
    }

    component BackendBtn: Rectangle {
        id: btn
        property string label: ""
        property string key: ""
        readonly property bool isActive: theme.renderBackend === btn.key

        Layout.preferredWidth: 72
        Layout.preferredHeight: 30
        radius: 10
        color: btn.isActive
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
            : (btnHov.containsMouse
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
        Behavior on color { ColorAnimation { duration: 200 } }

        scale: btnHov.pressed ? 0.94 : (btnHov.containsMouse ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.isActive ? theme.primary : theme.onBackground
            font.pixelSize: 11
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            id: btnHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: {
                if (theme.renderBackend === btn.key) return
                theme.renderBackend = btn.key
                Qt.callLater(function() { tab.restartOpen = true })
            }
        }
    }

    component NavPosBtn: Rectangle {
        id: npb
        property string label: ""
        property string key: ""
        readonly property bool isActive: theme.navBarPosition === npb.key

        Layout.preferredWidth: npbLabel.implicitWidth + 24
        Layout.preferredHeight: 30
        radius: 10
        color: npb.isActive
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
            : (npbHov.containsMouse
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
        Behavior on color { ColorAnimation { duration: 200 } }

        scale: npbHov.pressed ? 0.94 : (npbHov.containsMouse ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        Text {
            id: npbLabel
            anchors.centerIn: parent
            text: npb.label
            color: npb.isActive ? theme.primary : theme.onBackground
            font.pixelSize: 11
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            id: npbHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: theme.navBarPosition = npb.key
        }
    }

    component NavBarPositionRow: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 10
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Icon {
                                glyph: "\ue3c9"
                iconSize: 18
                iconColor: theme.onBackground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Navigation position"
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: "Where the navigation rail sits"
                    color: theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 6
                NavPosBtn { label: "Top";    key: "top" }
                NavPosBtn { label: "Center"; key: "center" }
                NavPosBtn { label: "Bottom"; key: "bottom" }
            }
        }
    }

    component PanelPosBtn: Rectangle {
        id: ppb
        property string label: ""
        property string key: ""
        readonly property bool isActive: theme.infoPanelPosition === ppb.key

        Layout.preferredWidth: ppbLabel.implicitWidth + 24
        Layout.preferredHeight: 30
        radius: 10
        color: ppb.isActive
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
            : (ppbHov.containsMouse
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
        Behavior on color { ColorAnimation { duration: 200 } }

        scale: ppbHov.pressed ? 0.94 : (ppbHov.containsMouse ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        Text {
            id: ppbLabel
            anchors.centerIn: parent
            text: ppb.label
            color: ppb.isActive ? theme.primary : theme.onBackground
            font.pixelSize: 11
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            id: ppbHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: theme.infoPanelPosition = ppb.key
        }
    }

    component PanelPositionRow: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: 10
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Icon {
                                glyph: "\ue5d2"
                iconSize: 18
                iconColor: theme.onBackground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Panel position"
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: "Where the Now Playing panel sits"
                    color: theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 6
                PanelPosBtn { label: "Top";    key: "top" }
                PanelPosBtn { label: "Center"; key: "center" }
                PanelPosBtn { label: "Bottom"; key: "bottom" }
            }
        }
    }

    component RendererRow: Rectangle {
        id: rRow
        readonly property bool isWindows: Qt.platform.os === "windows"

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 10
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Icon {
                glyph: "\ue333"
                iconSize: 18
                iconColor: theme.onBackground
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Renderer backend"
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: "Active: " + (tab.Window.window && tab.Window.window.activeRenderer
                                       ? tab.Window.window.activeRenderer
                                       : "initializing…")
                    color: theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 6

                BackendBtn { label: "OpenGL"; key: "opengl"; visible: !rRow.isWindows; Layout.preferredWidth: visible ? 72 : 0 }
                BackendBtn { label: "Vulkan"; key: "vulkan" }
                BackendBtn { label: "D3D11";  key: "d3d11";  visible: rRow.isWindows;  Layout.preferredWidth: visible ? 72 : 0 }
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(col.implicitHeight + 40, flick.height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 300
        maximumFlickVelocity: 8000

        ScrollBar.vertical: ScrollBar {
            id: settingsScrollBar
            policy: ScrollBar.AsNeeded
            visible: flick.contentHeight > flick.height + 1
            width: 10
            z: 2
            contentItem: Rectangle {
                implicitWidth: 5
                radius: 2.5
                color: theme.outline
                opacity: settingsScrollBar.pressed ? 0.8 : (settingsScrollBar.hovered ? 0.55 : 0.3)
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            background: Item {}
        }

        NumberAnimation {
            id: settingsWheelAnim
            target: flick
            property: "contentY"
            duration: 260
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => {
                const maxY = Math.max(0, flick.contentHeight - flick.height)
                let dy = 0
                if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                else dy = (event.angleDelta.y / 120.0) * 140
                const currentTarget = settingsWheelAnim.running ? settingsWheelAnim.to : flick.contentY
                const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                if (Math.abs(target - flick.contentY) < 0.5) {
                    event.accepted = true
                    return
                }
                settingsWheelAnim.stop()
                settingsWheelAnim.from = flick.contentY
                settingsWheelAnim.to = target
                settingsWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - flick.contentY) * 1.2))
                settingsWheelAnim.start()
                event.accepted = true
            }
        }

        TapHandler {
            onTapped: {
                const w = tab.Window.window
                if (w && w.activeFocusItem) w.activeFocusItem.focus = false
            }
        }

        ColumnLayout {
            id: col
            x: 24
            y: 20
            width: flick.width - 48
            spacing: 18

            ModalSection {
                title: "Application"
                icon: "\ue8b8"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 10
                    color: restartHov.containsMouse
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Icon {
                            glyph: "\ue5d5"
                            iconSize: 18
                            iconColor: theme.onBackground
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: "Restart player"
                                color: theme.onBackground
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Close and relaunch the application"
                                color: theme.outline
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Icon {
                            glyph: "\ue5cc"
                            iconSize: 16
                            iconColor: theme.outline
                        }
                    }

                    MouseArea {
                        id: restartHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: theme.restartApplication()
                    }
                }
            }

            ModalSection {
                title: "Library"
                icon: "\ue2c7"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 10
                    color: folderHov.containsMouse
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Icon {
                            glyph: "\ue2c7"
                            iconSize: 18
                            iconColor: theme.onBackground
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: "Music folder"
                                color: theme.onBackground
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: library.folderName.length > 0 ? library.folderName : "Not selected"
                                color: theme.outline
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 55
                            Layout.preferredHeight: 20
                            radius: 6
                            color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Ctrl+O"
                                color: theme.onBackground
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }

                        Icon {
                            glyph: "\ue5cc"
                            iconSize: 16
                            iconColor: theme.outline
                        }
                    }

                    MouseArea {
                        id: folderHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.folderRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 2
                    text: "Scans recursively for .mp3, .flac, .ogg, .opus, .wav, .m4a, .aac"
                    color: theme.outline
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    opacity: 0.8
                }
            }

            ModalSection {
                title: "Integrations"
                icon: ""

                GroupedList {
                    SettingRow {
                        icon: ""
                        label: "Discord Rich Presence"
                        description: "Show current track in Discord status"
                        rowChecked: library.discordRpcEnabled
                        onToggled: library.discordRpcEnabled = !library.discordRpcEnabled
                    }
                }
            }

            ModalSection {
                title: "Appearance"
                icon: "\ue40a"

                GroupedList {
                    SettingRow {
                        icon: "\ue518"
                        label: "Light theme"
                        description: tab.lightLocked
                            ? "Disabled while Matugen is on"
                            : "Switch between light and dark"
                        rowEnabled: !tab.lightLocked
                        rowChecked: theme.lightTheme
                        onToggled: theme.lightTheme = !theme.lightTheme
                    }

                    SettingRow {
                        icon: "\ue3b1"
                        label: "Matugen"
                        description: !theme.matugenAvailable
                            ? "Config not found in ~/.config/kute/matugen/"
                            : theme.lightTheme
                                ? "Disabled while Light theme is on"
                                : "Theme colors from wallpaper"
                        rowEnabled: theme.matugenAvailable && !theme.lightTheme
                        rowChecked: theme.matugenEnabled
                        onToggled: theme.matugenEnabled = !theme.matugenEnabled
                    }



                    SettingRow {
                                                icon: "\ue050"
                        label: "Audio visualizer"
                        description: "Show live spectrum next to volume slider"
                        rowChecked: library.visualizerEnabled
                        onToggled: library.visualizerEnabled = !library.visualizerEnabled
                    }

                    PanelPositionRow {}
                    NavBarPositionRow {}

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: 10
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            Icon {
                                                                glyph: "\ue405"
                                iconSize: 18
                                iconColor: theme.onBackground
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: "Cover shape"
                                    color: theme.onBackground
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Shape mask for Now Playing cover"
                                    color: theme.outline
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                spacing: 3
                                ShapePreviewBtn { shapeKey: "circle" }
                                ShapePreviewBtn { shapeKey: "pentagon" }
                                ShapePreviewBtn { shapeKey: "hexagon" }
                                ShapePreviewBtn { shapeKey: "octagon" }
                                ShapePreviewBtn { shapeKey: "sun" }
                                ShapePreviewBtn { shapeKey: "flower" }
                                ShapePreviewBtn { shapeKey: "star" }
                                ShapePreviewBtn { shapeKey: "blob" }
                            }
                        }
                    }
                }
            }

            ModalSection {
                title: "Rendering"
                icon: "\ue333"

                GroupedList {
                    RendererRow {}
                }
            }
        }
    }

    Rectangle {
        id: restartScrim
        parent: Overlay.overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: opacity > 0.01
        opacity: tab.restartOpen ? 1 : 0
        z: 20000
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: tab.restartOpen = false
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            blocking: true
            onWheel: (event) => { event.accepted = true }
        }
    }

    Rectangle {
        id: restartPanel
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        implicitHeight: contentRestart.implicitHeight
        height: implicitHeight
        radius: 14
        color: theme.surface
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.20)
        border.width: 1
        z: 20001
        visible: opacity > 0.01
        opacity: tab.restartOpen ? 1 : 0
        scale: tab.restartOpen ? 1.0 : 0.94
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        ColumnLayout {
            id: contentRestart
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Restart required"
                    color: theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: theme.outline
                opacity: 0.15
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Renderer backend change will apply after restart."
                    color: theme.outline
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                spacing: 6

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: laterTxt.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: 8
                    color: laterHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: laterTxt
                        anchors.centerIn: parent
                        text: "Later"
                        color: theme.onBackground
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: laterHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.restartOpen = false
                    }
                }

                Rectangle {
                    Layout.preferredWidth: restartTxt.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: 8
                    color: restartHov2.pressed
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.30)
                        : (restartHov2.containsMouse
                            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.24)
                            : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.16))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: restartTxt
                        anchors.centerIn: parent
                        text: "Restart"
                        color: theme.primary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: restartHov2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: theme.restartApplication()
                    }
                }
            }
        }
    }
}