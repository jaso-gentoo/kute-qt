import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: panel

    signal editRequested

    readonly property int coverSize: {
        const availW = panel.width - 8
        const availH = panel.height * 0.34
        return Math.max(80, Math.min(220, Math.min(availW, availH)))
    }

    property string dTitle: library.currentTitle
    property string dArtist: library.currentArtist
    property string dAlbum: library.currentAlbum
    property string dFormat: library.currentFormat
    property string dFilePath: library.currentFilePath
    property int    dBitrate: library.currentBitrate
    property int    dSampleRate: library.currentSampleRate
    property int    dChannels: library.currentChannels
    property int    dYear: library.currentYear
    property real   dFileSize: library.currentFileSize
    property real   dTrackDuration: library.currentTrackDuration
    property bool   dHasCurrent: library.hasCurrent

    function snapshot() {
        dTitle = library.currentTitle
        dArtist = library.currentArtist
        dAlbum = library.currentAlbum
        dFormat = library.currentFormat
        dFilePath = library.currentFilePath
        dBitrate = library.currentBitrate
        dSampleRate = library.currentSampleRate
        dChannels = library.currentChannels
        dYear = library.currentYear
        dFileSize = library.currentFileSize
        dTrackDuration = library.currentTrackDuration
        dHasCurrent = library.hasCurrent
    }

    Component.onCompleted: snapshot()

    Connections {
        target: library
        function onCurrentChanged() { infoAnim.restart() }
    }

    SequentialAnimation {
        id: infoAnim

        ParallelAnimation {
            NumberAnimation {
                target: infoWrap; property: "opacity"
                to: 0; duration: 120; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: infoShift; property: "y"
                to: 6; duration: 120; easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                panel.snapshot()
                infoShift.y = -6
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: infoWrap; property: "opacity"
                to: 1; duration: 300; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: infoShift; property: "y"
                to: 0; duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
    }

    Rectangle {
        id: editBtn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        anchors.topMargin: 2
        width: 30
        height: 30
        radius: 8
        color: "transparent"
        z: 100
        visible: library.hasCurrent

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: theme.onBackground
            opacity: editHov.containsMouse ? 0.20 : 0.10
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MaterialIcon {
            anchors.centerIn: parent
            glyph: "\ue3c9"
            iconSize: 17
            iconColor: theme.onBackground
        }

        MouseArea {
            id: editHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.editRequested()
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.bottom
            anchors.topMargin: 6
            width: editTip.implicitWidth + 20
            height: 28
            radius: 8
            color: theme.surface
            border.color: theme.outline
            border.width: 1
            opacity: editHov.containsMouse ? 1 : 0
            visible: opacity > 0
            z: 9999

            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                id: editTip
                anchors.centerIn: parent
                text: "Edit metadata (Ctrl+X)"
                color: theme.onBackground
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 500
        maximumFlickVelocity: 8000

        ColumnLayout {
            id: content
            width: flick.width
            spacing: 8

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: panel.coverSize
                Layout.preferredHeight: panel.coverSize
                Layout.topMargin: 4

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: theme.surfaceVariant
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    glyph: "\ue405"
                    iconSize: panel.coverSize * 0.28
                    iconColor: theme.outline
                    opacity: (library.hasCurrent && library.currentCover) ? 0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }

                Image {
                    id: coverSrc
                    readonly property real dpr: Screen.devicePixelRatio > 0
                                                    ? Screen.devicePixelRatio : 1
                    readonly property int decodeSize: Math.ceil(220 * dpr)

                    anchors.fill: parent
                    source: library.currentCover
                                ? library.toFileUrl(library.currentCover) + "?v=" + library.coverVersion
                                : ""
                    sourceSize.width: decodeSize
                    sourceSize.height: decodeSize
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    visible: false
                }

                Item {
                    id: coverMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "white"
                    }
                }

                MultiEffect {
                    id: coverEffect
                    anchors.fill: parent
                    source: coverSrc
                    maskEnabled: true
                    maskSource: coverMask

                    visible: coverSrc.status === Image.Ready

                    opacity: 0
                    scale: 1.05

                    Behavior on opacity {
                        enabled: coverEffect.showing
                        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        enabled: coverEffect.showing
                        NumberAnimation { duration: 650; easing.type: Easing.OutCubic }
                    }

                    property bool showing: false
                }

                Connections {
                    target: coverSrc
                    function onSourceChanged() {
                        coverEffect.showing = false
                        coverEffect.opacity = 0
                        coverEffect.scale = 1.05
                    }
                    function onStatusChanged() {
                        if (coverSrc.status === Image.Ready) {
                            Qt.callLater(function() {
                                coverEffect.showing = true
                                coverEffect.opacity = 1.0
                                coverEffect.scale = 1.0
                            })
                        }
                    }
                }
            }

            Item {
                id: infoWrap
                Layout.fillWidth: true

                transform: Translate { id: infoShift; y: 0 }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: panel.dHasCurrent ? panel.dTitle : "Nothing playing"
                            color: theme.onBackground
                            font.pixelSize: 17
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
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (panel.dHasCurrent && panel.dAlbum !== "Unknown Album") ? panel.dAlbum : ""
                            color: theme.outline
                            font.pixelSize: 10
                            opacity: 0.6
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            visible: text.length > 0
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.preferredHeight: 1
                        color: theme.outline
                        opacity: 0.15
                        visible: panel.dHasCurrent
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 4
                        visible: panel.dHasCurrent

                        Text { text: "Format"; color: theme.outline; font.pixelSize: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: panel.dFormat || "—"
                            color: theme.onSurface; font.pixelSize: 10
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                        }

                        Text { text: "Bitrate"; color: theme.outline; font.pixelSize: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: panel.dBitrate > 0 ? panel.dBitrate + " kbps" : "—"
                            color: theme.onSurface; font.pixelSize: 10
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                        }

                        Text { text: "Sample rate"; color: theme.outline; font.pixelSize: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: library.formatSampleRate(panel.dSampleRate)
                            color: theme.onSurface; font.pixelSize: 10
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                        }

                        Text { text: "Size"; color: theme.outline; font.pixelSize: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: library.formatFileSize(panel.dFileSize)
                            color: theme.onSurface; font.pixelSize: 10
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                        }

                        Text { text: "Duration"; color: theme.outline; font.pixelSize: 10 }
                        Text {
                            Layout.fillWidth: true
                            text: library.formatDuration(panel.dTrackDuration)
                            color: theme.onSurface; font.pixelSize: 10
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 8
                        text: panel.dFilePath
                        color: theme.outline
                        font.pixelSize: 9
                        elide: Text.ElideMiddle
                        font.family: "monospace"
                        opacity: 0.55
                        visible: panel.dHasCurrent
                    }
                }
            }
        }
    }
}