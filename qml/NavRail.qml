import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rail

    signal infoToggled
    signal pageChanged(int page)
    signal searchRequested
    signal settingsRequested

    property bool settingsOpen: false
    property bool searchOpen: false
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

        MaterialIcon {
            id: rbIcon
            anchors.centerIn: parent
            glyph: rb.glyph
            iconSize: 20
            filled: rb.active
            iconColor: rb.active ? theme.primary : theme.onBackground
            scale: rbHov.containsMouse ? 1.12 : 1.0
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

        RailBtn {
            glyph: "\ue8b6"
            tip: "Search (Ctrl+F)"
            active: rail.searchOpen
            onClicked: rail.searchRequested()
        }

        RailDivider {}

        RailBtn {
            glyph: "\ue8b8"
            tip: "Settings (Ctrl+E)"
            active: rail.settingsOpen
            onClicked: rail.settingsRequested()
        }

    }
}
