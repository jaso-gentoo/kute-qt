import QtQuick
import QtQuick.Layouts

Item {
    id: modal
    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 1000

    property bool open: false
    property int  currentTab: 0

    readonly property int tabSettings: 0
    readonly property int tabTrack:    1
    readonly property int tabLyrics:   2

    readonly property var tabs: [
        { label: "Settings", icon: "\ue8b8" },
        { label: "Track",    icon: "\ue3c9" },
        { label: "Lyrics",   icon: "\ue405" }
    ]

    signal closeRequested
    signal saved
    signal folderRequested

    function performTrackSave() { trackTab.performSave() }

    function previousSubTab() {
        if (currentTab === tabTrack) trackTab.previousSubTab()
        else if (currentTab === tabLyrics) lyricsTab.previousSubTab()
    }
    function nextSubTab() {
        if (currentTab === tabTrack) trackTab.nextSubTab()
        else if (currentTab === tabLyrics) lyricsTab.nextSubTab()
    }

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    HoverHandler { blocking: true }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: true
        onWheel: (event) => { event.accepted = true }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000"; opacity: 0.55
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            onClicked: modal.closeRequested()
        }
    }

    FocusScope {
        id: panel
        focus: true
        anchors.centerIn: parent
        width: Math.min(760, parent.width - 80)

        readonly property int preferredHeight: {
            switch (modal.currentTab) {
                case modal.tabSettings: return 400
                case modal.tabTrack:    return 370
                case modal.tabLyrics:   return 640
            }
            return 560
        }
        height: Math.min(preferredHeight, parent.height - 80)
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        opacity: modal.open ? 1 : 0
        scale:   modal.open ? 1.0 : 0.96
        y:       modal.open ? 0 : 16

        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on scale   { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on y       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: theme.surface
            border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.4)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    const w = panel.Window.window
                    if (w && w.activeFocusItem) w.activeFocusItem.focus = false
                    panel.forceActiveFocus()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20; anchors.rightMargin: 12
                        spacing: 4

                        Row {
                            spacing: 0
                            Repeater {
                                model: modal.tabs
                                delegate: Item {
                                    id: tabItem
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: modal.currentTab === index
                                    width: tabRow.implicitWidth + 28
                                    height: 44

                                    Row {
                                        id: tabRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            glyph: tabItem.modelData.icon
                                            iconSize: 16
                                            iconColor: tabItem.active ? theme.primary : theme.outline
                                            Behavior on iconColor { ColorAnimation { duration: 200 } }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tabItem.modelData.label
                                            color: tabItem.active ? theme.primary : theme.onBackground
                                            opacity: tabItem.active ? 1.0 : 0.6
                                            font.pixelSize: 13
                                            font.weight: tabItem.active ? Font.DemiBold : Font.Medium
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: tabItem.active ? tabRow.implicitWidth + 12 : 0
                                        height: 2; radius: 1
                                        color: theme.primary
                                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modal.currentTab = tabItem.index
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: closeHov.containsMouse
                                ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.10)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            MaterialIcon {
                                anchors.centerIn: parent
                                glyph: "\ue5cd"; iconSize: 18
                                iconColor: theme.onBackground
                            }
                            MouseArea {
                                id: closeHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modal.closeRequested()
                            }
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: theme.outline; opacity: 0.15
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    SettingsTab {
                        anchors.fill: parent
                        isActive: modal.open && modal.currentTab === modal.tabSettings
                        visible: opacity > 0.01
                        opacity: (modal.open && modal.currentTab === modal.tabSettings) ? 1 : 0
                        x: (modal.open && modal.currentTab === modal.tabSettings) ? 0 : -12
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        onFolderRequested: {
                            modal.closeRequested()
                            modal.folderRequested()
                        }
                    }

                    TrackTab {
                        id: trackTab
                        anchors.fill: parent
                        isActive: modal.open && modal.currentTab === modal.tabTrack
                        visible: opacity > 0.01
                        opacity: (modal.open && modal.currentTab === modal.tabTrack) ? 1 : 0
                        x: (modal.open && modal.currentTab === modal.tabTrack) ? 0 : -12
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        onCloseRequested: modal.closeRequested()
                        onSaved: modal.saved()
                    }

                    LyricsTab {
                        id: lyricsTab
                        anchors.fill: parent
                        isActive: modal.open && modal.currentTab === modal.tabLyrics
                        visible: opacity > 0.01
                        opacity: (modal.open && modal.currentTab === modal.tabLyrics) ? 1 : 0
                        x: (modal.open && modal.currentTab === modal.tabLyrics) ? 0 : -12
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: modal.open
        onActivated: modal.closeRequested()
    }
}