import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rail

    signal infoToggled
    signal pageChanged(int page)
    signal searchRequested
    signal settingsRequested
    signal metadataRequested
    signal lyricsRequested

    property bool settingsOpen: false
    property bool searchOpen: false
    property bool panelActive: settingsOpen || searchOpen
    property int currentIndex: 0

    implicitHeight: contentCol.implicitHeight + 20
    radius: 18
    color: theme.surface

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.18)
        border.width: 1
    }

    component RailBtn: Item {
        id: rb
        property string glyph: ""
        property string tip: ""
        property bool active: false
        signal clicked

        Layout.preferredWidth: 38
        Layout.preferredHeight: 38

        Rectangle {
            anchors.fill: parent
            radius: 11
            color: theme.primary
            opacity: rb.active ? 0.16 : 0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            radius: 11
            color: theme.onSurface
            opacity: (rbHov.containsMouse && !rb.active) ? 0.09 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Icon {
            id: rbIcon
            anchors.centerIn: parent
            glyph: rb.glyph
            iconSize: 20
            filled: rb.active
            iconColor: rb.active ? theme.primary : theme.onBackground
            scale: rbHov.containsMouse ? 1.08 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.8
                }
            }
            Behavior on iconColor { ColorAnimation { duration: 250 } }
        }

        MouseArea {
            id: rbHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                rbIcon.spin()
                rb.clicked()
            }
        }

        Rectangle {
            anchors.left: parent.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: rbTip.implicitWidth + 20
            height: 26
            radius: 9
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 1.0)
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
            border.width: 1
            opacity: rbHov.containsMouse ? 1 : 0
            visible: opacity > 0
            z: 100
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                id: rbTip
                anchors.centerIn: parent
                text: rb.tip
                color: theme.onSurface
                font.pixelSize: 11
            }
        }
    }

    component RailDivider: Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 5
        Layout.bottomMargin: 5
        Layout.preferredWidth: 20
        Layout.preferredHeight: 1
        color: theme.outline
        opacity: 0.3
    }

    component MenuItemBtn: Rectangle {
        id: mi
        property string icon: ""
        property string label: ""
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 10
        color: miHov.containsMouse
            ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.14)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 8
                color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.14)

                Icon {
                    anchors.centerIn: parent
                    glyph: mi.icon
                    iconSize: 15
                    filled: true
                    iconColor: theme.primary
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: mi.label
                color: theme.onBackground
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: miHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                panelMenu.menuOpen = false
                mi.clicked()
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        RailBtn {
            glyph: "\ue88a"
            tip: "Home (Ctrl+1)"
            active: rail.currentIndex === 0
            onClicked: {
                rail.currentIndex = 0
                rail.pageChanged(0)
            }
        }

        RailBtn {
            glyph: "\ue8ef"
            tip: "Browse (Ctrl+2)"
            active: rail.currentIndex === 1
            onClicked: {
                rail.currentIndex = 1
                rail.pageChanged(2)
            }
        }

        RailDivider {}

        RailBtn {
            glyph: "\ue88e"
            tip: "Now playing (Ctrl+Q)"
            active: library.infoPanelVisible
            onClicked: rail.infoToggled()
        }

        Item {
            id: panelBtn
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: theme.primary
                opacity: rail.panelActive ? 0.16 : 0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: theme.onSurface
                opacity: (panelBtnHov.containsMouse && !rail.panelActive) ? 0.09 : 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Icon {
                id: panelIcon
                anchors.centerIn: parent
                glyph: "\ue5d2"
                iconSize: 20
                filled: rail.panelActive
                iconColor: rail.panelActive ? theme.primary : theme.onBackground
                scale: panelBtnHov.containsMouse ? 1.08 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on iconColor { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: panelBtnHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    panelMenu.menuOpen = true
                    closeTimer.stop()
                }
                onExited: {
                    closeTimer.restart()
                }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: {
            if (!panelBtnHov.containsMouse && !panelMenu.hovered && !bridgeHov.hovered)
                panelMenu.menuOpen = false
        }
    }

    Item {
        id: panelMenu
        property bool menuOpen: false
        property bool hovered: menuHov.hovered

        readonly property real btnX: contentCol.x + panelBtn.x
        readonly property real btnY: contentCol.y + panelBtn.y
        readonly property real btnW: panelBtn.width
        readonly property real btnH: panelBtn.height

        readonly property real btnCX: btnX + btnW / 2
        readonly property real btnCY: btnY + btnH / 2
        readonly property real targetW: 200
        readonly property real targetH: menuContent.implicitHeight + 16

        x: btnX + btnW + 6
        y: {
            const natural = Math.min(btnY, btnCY - targetH / 2)
            if (!rail.parent) return natural
            const safeBottom = rail.parent.height - 82
            const maxY = safeBottom - targetH - rail.y
            return Math.max(0, Math.min(natural, maxY))
        }
        width: targetW
        height: targetH
        opacity: menuOpen ? 1 : 0
        scale: menuOpen ? 1.0 : 0.9
        transformOrigin: Item.Left
        visible: opacity > 0.01
        z: 50

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.22)
            border.width: 1
        }

        Item {
            anchors.fill: parent
            anchors.margins: 8
            opacity: panelMenu.menuOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            clip: true

            ColumnLayout {
                id: menuContent
                width: parent.width
                spacing: 4

                MenuItemBtn { icon: "\ue8b8"; label: "Settings"; onClicked: rail.settingsRequested() }
                MenuItemBtn { icon: "\ue8b6"; label: "Search";   onClicked: rail.searchRequested() }
                MenuItemBtn { icon: "\ue3c9"; label: "Metadata"; onClicked: rail.metadataRequested() }
                MenuItemBtn { icon: "\ue405"; label: "Lyrics";   onClicked: rail.lyricsRequested() }
            }
        }

        HoverHandler {
            id: menuHov
            onHoveredChanged: {
                if (hovered) { panelMenu.menuOpen = true; closeTimer.stop() }
                else closeTimer.restart()
            }
        }
    }

    Item {
        id: hoverBridge
        readonly property real bridgeX: panelMenu.x - 8
        readonly property real bridgeW: 10
        x: bridgeX
        y: panelMenu.y
        width: bridgeW
        height: panelMenu.height
        visible: panelMenu.menuOpen && panelMenu.opacity > 0.01
        HoverHandler {
            id: bridgeHov
            onHoveredChanged: {
                if (hovered) closeTimer.stop()
                else closeTimer.restart()
            }
        }
    }
}
