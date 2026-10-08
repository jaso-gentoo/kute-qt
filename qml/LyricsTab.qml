import QtQuick
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: isActive

    property bool isLrcMode: true
    property string lyricsRaw: ""
    property var    lrcLines: []
    property int    activeIndex: -1
    property real   lrcOffset: 0.25
    onIsActiveChanged: if (isActive) refresh()

    function parseLrc(raw) {
        const lines = raw.split('\n'); const result = []
        const re = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re)
            if (m) {
                const min = parseInt(m[1]); const sec = parseInt(m[2])
                const ms  = parseInt(m[3].padEnd(3, '0'))
                const t   = min * 60 + sec + ms / 1000
                const txt = lines[i].replace(/\[.*?\]/g, '').trim()
                result.push({ time: t, text: txt, index: result.length })
            }
        }
        result.sort((a, b) => a.time - b.time)
        return result
    }

    function refresh() {
        lrcOffset = library.getLrcOffset(library.currentIndex)
        offsetField.text = lrcOffset.toFixed(2)
        const t = library.loadTrackText(library.currentIndex, isLrcMode)
        lyricsRaw = (t == null) ? "" : String(t)
        if (isLrcMode) {
            lrcLines = parseLrc(lyricsRaw)
            updateActive()
            Qt.callLater(centerActive, true)
        } else { lrcLines = []; activeIndex = -1 }
    }

    function updateActive() {
        if (!isLrcMode || lrcLines.length === 0 || !library.isPlaying) return
        const t = library.position / 1000 + lrcOffset
        let idx = -1
        for (let i = 0; i < lrcLines.length; i++) {
            if (lrcLines[i].time <= t) idx = i; else break
        }
        if (idx !== activeIndex) { activeIndex = idx; Qt.callLater(centerActive) }
    }

    function centerActive(instant) {
        if (activeIndex < 0) return
        const item = lrcList.itemAtIndex(activeIndex); if (!item) return
        const target = item.y - lrcList.height / 2 + item.height / 2
        const maxY = Math.max(0, lrcList.contentHeight - lrcList.height)
        const clamped = Math.max(0, Math.min(maxY, target))
        const dist = Math.abs(clamped - lrcList.contentY)
        if (dist < 1) return
        if (instant) { lrcList.contentY = clamped; return }
        scrollAnim.stop()
        scrollAnim.from = lrcList.contentY
        scrollAnim.to = clamped
        scrollAnim.duration = Math.min(340, Math.max(120, dist * 0.55))
        scrollAnim.start()
    }

    function commitOffset() {
        const v = parseFloat(offsetField.text)
        if (isNaN(v)) { offsetField.text = lrcOffset.toFixed(2); return }
        lrcOffset = v
        library.setLrcOffset(library.currentIndex, v)
        offsetField.text = v.toFixed(2)
    }

    // Throttled LRC line update — runs only while tab is visible, in LRC mode,
    // and player is playing. 200ms is far below the typical line duration, so
    // visually identical, but CPU load drops from ~10 Hz to 5 Hz.
    Timer {
        id: lrcUpdateTimer
        interval: 200
        repeat: true
        running: tab.isActive && tab.isLrcMode && library.isPlaying
        onTriggered: tab.updateActive()
    }

    Connections {
        target: library
        function onCurrentChanged() { if (tab.isActive) tab.refresh() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [ { isLrc: false, label: "TXT" }, { isLrc: true, label: "LRC" } ]
                delegate: Item {
                    required property var modelData
                    readonly property bool active: tab.isLrcMode === modelData.isLrc
                    Layout.preferredWidth: fmt2.implicitWidth + 28
                    Layout.preferredHeight: 34
                    Text {
                        id: fmt2
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? theme.primary : theme.onBackground
                        opacity: active ? 1.0 : 0.55
                        font.pixelSize: 12; font.weight: Font.DemiBold
                        font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: active ? fmt2.implicitWidth + 12 : 0
                        height: 2; radius: 1
                        color: theme.primary
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tab.isLrcMode = modelData.isLrc
                            tab.refresh()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Offset"
                color: theme.outline
                font.pixelSize: 11; font.weight: Font.Medium
                visible: tab.isLrcMode
            }
            TextInput {
                id: offsetField
                Layout.preferredWidth: 60
                Layout.preferredHeight: 32
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: theme.onBackground
                font.pixelSize: 12; font.family: "monospace"
                selectByMouse: true; clip: true
                selectionColor: theme.primary
                selectedTextColor: theme.background
                visible: tab.isLrcMode
                validator: DoubleValidator { bottom: -60.0; top: 60.0; decimals: 2 }
                HoverHandler { cursorShape: Qt.IBeamCursor }
                onTextEdited: {
                    const v = parseFloat(text)
                    if (!isNaN(v)) {
                        tab.lrcOffset = v
                        library.setLrcOffset(library.currentIndex, v)
                        if (tab.isLrcMode && library.isPlaying) tab.updateActive()
                    }
                }
                onEditingFinished: tab.commitOffset()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: theme.outline; opacity: 0.15
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: txtFlick
                anchors.fill: parent
                visible: !tab.isLrcMode
                contentWidth: width
                contentHeight: txtArea.implicitHeight
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

                TextEdit {
                    id: txtArea
                    width: txtFlick.width
                    text: tab.lyricsRaw
                    color: theme.onBackground
                    font.pixelSize: 15
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    selectionColor: theme.primary
                    selectedTextColor: theme.background
                    textFormat: TextEdit.PlainText
                }

                Text {
                    anchors.centerIn: parent
                    text: "No lyrics found"
                    color: theme.outline; opacity: 0.4
                    font.pixelSize: 13
                    visible: txtArea.text.length === 0
                }
            }

            ListView {
                id: lrcList
                anchors.fill: parent
                visible: tab.isLrcMode
                clip: true; spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: tab.lrcLines
                cacheBuffer: 1200
                smooth: true
                flickDeceleration: 300
                maximumFlickVelocity: 8000

                TapHandler {
                    onTapped: {
                        const w = tab.Window.window
                        if (w && w.activeFocusItem) w.activeFocusItem.focus = false
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "No LRC lyrics found"
                    color: theme.outline; opacity: 0.4
                    font.pixelSize: 13
                    visible: lrcList.count === 0
                }

                NumberAnimation {
                    id: scrollAnim
                    target: lrcList
                    property: "contentY"
                    easing.type: Easing.InOutQuad
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: lrcList.width
                    height: 26
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: index === tab.activeIndex ? theme.primary : theme.onBackground
                        opacity: index === tab.activeIndex ? 1.0 : 0.55
                        font.pixelSize: 15
                        font.weight: index === tab.activeIndex ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        transformOrigin: Item.Center
                        scale: index === tab.activeIndex ? 1.06 : 1.0
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 180 } }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: tab.isLrcMode
                ? "Synced lyrics • " + (tab.lrcLines.length > 0 ? (tab.lrcLines.length + " lines") : "empty")
                : "Plain text lyrics"
            color: theme.outline; font.pixelSize: 10
        }
    }
}