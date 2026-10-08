import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: isActive

    signal folderRequested

    property bool restartOpen: false

    readonly property bool lightLocked: theme.matugenEnabled
    readonly property bool matugenLocked: theme.lightTheme || !theme.matugenAvailable

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

                MaterialIcon {
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

            MaterialIcon {
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

            MaterialIcon {
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
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 300
        maximumFlickVelocity: 8000

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

                        MaterialIcon {
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

                        MaterialIcon {
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
                    color: restartHov.pressed
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.30)
                        : (restartHov.containsMouse
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
                        id: restartHov
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