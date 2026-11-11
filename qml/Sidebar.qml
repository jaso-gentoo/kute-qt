import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
    id: sidebar
    width: 240
    radius: 16
    color: theme.surface
    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
    border.width: 1

    property int currentTab: 0
    property int trackSubTab: 0
    property bool trackTextIsLrc: true
    property bool lyricsIsLrc: true

    signal tabRequested(int tab)
    signal trackSubTabRequested(int sub)
    signal trackTextIsLrcRequested(bool lrc)
    signal lyricsIsLrcRequested(bool lrc)
    signal closeRequested

    function clearFocus() {
        var w = sidebar.Window.window
        if (!w) return
        var it = w.activeFocusItem
        if (it && it.focus) it.focus = false
    }

    component SideButton: Rectangle {
        id: sb
        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property bool hasSub: false
        property bool subExpanded: false
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: 12
        color: sb.active
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12)
            : Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.4)
        Behavior on color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: sb.active
                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                    : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.14)
                Behavior on color { ColorAnimation { duration: 180 } }

                Icon {
                    anchors.centerIn: parent
                    glyph: sb.icon
                    iconSize: 17
                    filled: sb.active
                    iconColor: theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: sb.label
                    color: sb.active ? theme.primary : theme.onBackground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Text {
                    Layout.fillWidth: true
                    text: sb.subtitle
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            Icon {
                visible: sb.hasSub
                glyph: ""
                iconSize: 16
                iconColor: sb.active ? theme.primary : theme.outline
                rotation: sb.subExpanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on iconColor { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            z: 100
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: sb.clicked()
        }
    }

    component TreeLeaf: Item {
        id: tl
        property int    depth: 1
        property string label: ""
        property bool   active: false
        property bool   shown: true
        property bool   hasPrev: false
        property bool   hasNext: false
        property int    extraBelow: 0
        signal clicked

        readonly property int indentX: depth === 1 ? 8 : 32
        readonly property int rowH: 26
        readonly property int midY: 13
        readonly property int cornerR: 4
        readonly property int elbowLen: 14

        width: parent ? parent.width : 0
        height: shown ? rowH : 0
        opacity: shown ? 1 : 0

        Behavior on height  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Rectangle {
            x: tl.indentX - 0.5
            y: 0
            width: 1
            height: tl.hasPrev ? (tl.midY - tl.cornerR) : 0
            color: theme.outline
            opacity: 0.35
        }

        Shape {
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            opacity: 0.35

            ShapePath {
                strokeColor: theme.outline
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: tl.indentX
                startY: tl.midY - tl.cornerR
                PathQuad { x: tl.indentX + tl.cornerR; y: tl.midY; controlX: tl.indentX; controlY: tl.midY }
                PathLine { x: tl.indentX + tl.elbowLen; y: tl.midY }
            }
        }

        Rectangle {
            x: tl.indentX - 0.5
            y: tl.midY - tl.cornerR
            width: 1
            height: tl.hasNext ? (tl.rowH - tl.midY + tl.cornerR + tl.extraBelow) : 0
            color: theme.outline
            opacity: 0.35
        }

        Rectangle {
            x: tl.indentX + tl.elbowLen + 2
            y: tl.midY - 3
            width: 6
            height: 6
            radius: 1
            rotation: 45
            color: tl.active ? theme.primary : theme.outline
            opacity: tl.active ? 1 : 0.55
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            x: tl.indentX + tl.elbowLen + 12
            y: 2
            width: tl.width - x - 8
            height: tl.rowH - 4
            radius: 6
            color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, tl.active ? 0.10 : 0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            x: tl.indentX + tl.elbowLen + 18
            anchors.verticalCenter: parent.verticalCenter
            text: tl.label
            font.pixelSize: 11
            font.weight: tl.active ? Font.DemiBold : Font.Medium
            color: tl.active ? theme.primary : theme.onBackground
            opacity: tl.active ? 1.0 : 0.78
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: flickWheelAnim.stop()
            onClicked: tl.clicked()
        }
    }

    component TreeOffsetLeaf: Item {
        id: tol
        property bool shown: true
        width: parent ? parent.width : 0
        height: shown ? 26 : 0
        opacity: shown ? 1 : 0
        Behavior on height  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        readonly property int indentX: 32
        readonly property int midY: 13
        readonly property int cornerR: 4
        readonly property int elbowLen: 14

        Shape {
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            opacity: 0.35

            ShapePath {
                strokeColor: theme.outline
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: tol.indentX
                startY: tol.midY - tol.cornerR
                PathQuad { x: tol.indentX + tol.cornerR; y: tol.midY; controlX: tol.indentX; controlY: tol.midY }
                PathLine { x: tol.indentX + tol.elbowLen; y: tol.midY }
            }
        }

        Rectangle {
            x: tol.indentX + tol.elbowLen + 2
            y: tol.midY - 3
            width: 6
            height: 6
            radius: 1
            rotation: 45
            color: theme.outline
            opacity: 0.55
        }

        Text {
            x: tol.indentX + tol.elbowLen + 18
            anchors.verticalCenter: parent.verticalCenter
            text: "Offset"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: theme.onBackground
            opacity: 0.78
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 22
            radius: 6
            color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
            border.width: 1
            border.color: offsetInput.activeFocus
                ? theme.primary
                : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.2)
            Behavior on border.color { ColorAnimation { duration: 180 } }

            TextInput {
                id: offsetInput
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: theme.onBackground
                font.pixelSize: 11
                font.family: "monospace"
                selectByMouse: true
                clip: true
                selectionColor: theme.primary
                selectedTextColor: theme.background
                validator: DoubleValidator { bottom: -60.0; top: 60.0; decimals: 2 }

                HoverHandler { cursorShape: Qt.IBeamCursor }

                function syncValue() {
                    if (activeFocus) return
                    text = library.getLrcOffset(library.currentIndex).toFixed(2)
                }
                function commitValue() {
                    var v = parseFloat(String(text).replace(",", ".").trim())
                    if (isNaN(v)) { syncValue(); return }
                    v = Math.max(-60, Math.min(60, v))
                    library.setLrcOffset(library.currentIndex, v)
                    text = v.toFixed(2)
                }

                Component.onCompleted: syncValue()
                onAccepted: commitValue()
                onEditingFinished: commitValue()

                Connections {
                    target: library
                    function onCurrentChanged() { offsetInput.syncValue() }
                    function onOffsetRevisionChanged() { offsetInput.syncValue() }
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentWrapper.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        NumberAnimation {
            id: flickWheelAnim
            target: flick
            property: "contentY"
            duration: 260
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            onWheel: event => {
                var maxY = Math.max(0, flick.contentHeight - flick.height)
                var dy = event.angleDelta.y / 120 * 60
                var target = Math.max(0, Math.min(maxY, flick.contentY - dy))
                if (Math.abs(target - flick.contentY) < 0.5) {
                    event.accepted = true
                    return
                }
                flickWheelAnim.stop()
                flickWheelAnim.from = flick.contentY
                flickWheelAnim.to = target
                flickWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - flick.contentY) * 1.2))
                flickWheelAnim.start()
                event.accepted = true
            }
        }

        Item {
            id: contentWrapper
            width: flick.width
            height: mainLayout.implicitHeight + 16

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: sidebar.clearFocus()
            }

            ColumnLayout {
                id: mainLayout
                x: 8
                y: 8
                width: parent.width - 16
                spacing: 4

                Rectangle {
                    id: backBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: backHover.hovered
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Icon {
                            glyph: "\ue314"
                            iconSize: 16
                            iconColor: theme.onBackground
                            x: backHover.hovered ? -2 : 0
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Back"
                            color: theme.onBackground
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }

                    HoverHandler {
                        id: backHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        property bool _armed: false
                        property real _px: 0
                        property real _py: 0
                        onPressed: (mouse) => {
                            mouse.accepted = true
                            flickWheelAnim.stop()
                            _armed = true
                            _px = mouse.x
                            _py = mouse.y
                        }
                        onReleased: (mouse) => {
                            if (_armed && Math.abs(mouse.x - _px) < 10 && Math.abs(mouse.y - _py) < 10) {
                                sidebar.closeRequested()
                            }
                            _armed = false
                        }
                        onCanceled: _armed = false
                    }
                }

                SideButton {
                    icon: "\ue8b8"
                    label: "Settings"
                    subtitle: "Theme, audio, library"
                    active: sidebar.currentTab === 0
                    hasSub: false
                    onClicked: sidebar.tabRequested(0)
                }

                SideButton {
                    icon: "\ue8b6"
                    label: "Search"
                    subtitle: "Find music"
                    active: sidebar.currentTab === 1
                    hasSub: false
                    onClicked: sidebar.tabRequested(1)
                }

                SideButton {
                    icon: "\ue3c9"
                    label: "Metadata"
                    subtitle: "Edit tags & artwork"
                    active: sidebar.currentTab === 2
                    hasSub: true
                    subExpanded: sidebar.currentTab === 2
                    onClicked: sidebar.tabRequested(2)
                }

                Item {
                    id: metaTree
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    property real _h: sidebar.currentTab === 2
                        ? (sidebar.trackSubTab === 1 ? 26 * 4 : 26 * 2)
                        : 0
                    Behavior on _h {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    Layout.preferredHeight: _h
                    visible: _h > 0.01
                    clip: true

                    Column {
                        id: metaCol
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: parent.width
                        spacing: 0

                        TreeLeaf {
                            width: parent.width
                            depth: 1
                            label: "Fields"
                            active: sidebar.trackSubTab === 0
                            hasPrev: false
                            hasNext: true
                            onClicked: sidebar.trackSubTabRequested(0)
                        }
                        TreeLeaf {
                            width: parent.width
                            depth: 1
                            label: "Text"
                            active: sidebar.trackSubTab === 1
                            hasPrev: true
                            hasNext: false
                            onClicked: sidebar.trackSubTabRequested(1)
                        }
                        TreeLeaf {
                            width: parent.width
                            depth: 2
                            label: "LRC"
                            shown: sidebar.trackSubTab === 1
                            active: sidebar.trackTextIsLrc
                            hasPrev: false
                            hasNext: true
                            onClicked: sidebar.trackTextIsLrcRequested(true)
                        }
                        TreeLeaf {
                            width: parent.width
                            depth: 2
                            label: "TAG"
                            shown: sidebar.trackSubTab === 1
                            active: !sidebar.trackTextIsLrc
                            hasPrev: true
                            hasNext: false
                            onClicked: sidebar.trackTextIsLrcRequested(false)
                        }
                    }
                }

                SideButton {
                    icon: "\ue405"
                    label: "Lyrics"
                    subtitle: "View lyrics"
                    active: sidebar.currentTab === 3
                    hasSub: true
                    subExpanded: sidebar.currentTab === 3
                    onClicked: sidebar.tabRequested(3)
                }

                Item {
                    id: lyricsTree
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    property real _h: sidebar.currentTab === 3
                        ? (sidebar.lyricsIsLrc ? 26 * 3 : 26 * 2)
                        : 0
                    Behavior on _h {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    Layout.preferredHeight: _h
                    visible: _h > 0.01
                    clip: true

                    Column {
                        id: lyricsCol
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: parent.width
                        spacing: 0

                        TreeLeaf {
                            width: parent.width
                            depth: 1
                            label: "LRC"
                            active: sidebar.lyricsIsLrc
                            hasPrev: false
                            hasNext: true
                            extraBelow: (sidebar.currentTab === 3 && sidebar.lyricsIsLrc) ? 26 : 0
                            onClicked: sidebar.lyricsIsLrcRequested(true)
                        }

                        TreeOffsetLeaf {
                            width: parent.width
                            shown: sidebar.lyricsIsLrc
                        }

                        TreeLeaf {
                            width: parent.width
                            depth: 1
                            label: "TXT"
                            active: !sidebar.lyricsIsLrc
                            hasPrev: true
                            hasNext: false
                            onClicked: sidebar.lyricsIsLrcRequested(false)
                        }
                    }
                }
            }
        }
    }
}
