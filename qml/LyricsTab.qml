import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

FocusScope {
    id: tab
    property bool isActive: false
    visible: opacity > 0.01
    opacity: isActive ? 1 : 0
    enabled: isActive
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property bool   isLrcMode: true
    property string lyricsRaw: ""
    property var    lrcLines: []
    property int    activeIndex: -1
    property real   lrcOffset: 0.25

    onIsActiveChanged: if (isActive) refresh()

    function parseLrc(raw) {
        const lines = raw.split("\n")
        const result = []
        const re = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re)
            if (m) {
                const min = parseInt(m[1])
                const sec = parseInt(m[2])
                const ms  = parseInt(m[3].padEnd(3, "0"))
                const t   = min * 60 + sec + ms / 1000
                const txt = lines[i].replace(/\[.*?\]/g, "").trim()
                result.push({ time: t, text: txt, index: result.length })
            }
        }
        result.sort((a, b) => a.time - b.time)
        return result
    }

    function refresh() {
        lrcOffset = library.getLrcOffset(library.currentIndex)
        if (isLrcMode) {
            const t = library.loadTrackText(library.currentIndex, true)
            lrcLines = parseLrc(t == null ? "" : String(t))
            lyricsRaw = ""
            updateActive()
            Qt.callLater(centerActive, true)
        } else {
            const t = library.loadTrackText(library.currentIndex, false)
            lyricsRaw = (t == null) ? "" : String(t)
            lrcLines = []
            activeIndex = -1
        }
    }

    function updateActive() {
        if (!isLrcMode || lrcLines.length === 0 || !library.isPlaying) return
        const t = library.position / 1000 + lrcOffset
        let idx = -1
        for (let i = 0; i < lrcLines.length; i++) {
            if (lrcLines[i].time <= t) idx = i
            else break
        }
        if (idx !== activeIndex) {
            activeIndex = idx
            Qt.callLater(centerActive)
        }
    }

    function centerActive(instant) {
        if (activeIndex < 0) return
        const item = lrcList.itemAtIndex(activeIndex)
        if (!item) return
        const target = item.y - lrcList.height / 2 + item.height / 2
        const maxY = Math.max(0, lrcList.contentHeight - lrcList.height)
        const clamped = Math.max(0, Math.min(maxY, target))
        const dist = Math.abs(clamped - lrcList.contentY)
        if (dist < 1) return
        if (instant) {
            lrcList.contentY = clamped
            return
        }
        scrollAnim.stop()
        scrollAnim.from = lrcList.contentY
        scrollAnim.to = clamped
        scrollAnim.duration = Math.min(700, Math.max(280, dist * 1.2))
        scrollAnim.start()
    }

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
        function onOffsetRevisionChanged() {
            if (!tab.isActive) return
            tab.lrcOffset = library.getLrcOffset(library.currentIndex)
        }
    }

    Item {
        anchors.fill: parent

        ListView {
            id: lrcList
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            clip: true
            spacing: 0
            visible: tab.isLrcMode && tab.lrcLines.length > 0
            opacity: tab.isLrcMode ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            model: tab.lrcLines
            cacheBuffer: 1600
            smooth: true
            flickDeceleration: 300
            maximumFlickVelocity: 8000
            boundsBehavior: Flickable.StopAtBounds

            NumberAnimation {
                id: scrollAnim
                target: lrcList
                property: "contentY"
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                id: lrcWheelAnim
                target: lrcList
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, lrcList.contentHeight - lrcList.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                    else dy = (event.angleDelta.y / 120.0) * 140
                    const currentTarget = lrcWheelAnim.running ? lrcWheelAnim.to : lrcList.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    lrcWheelAnim.stop()
                    lrcWheelAnim.from = lrcList.contentY
                    lrcWheelAnim.to = target
                    lrcWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - lrcList.contentY) * 1.2))
                    lrcWheelAnim.start()
                    event.accepted = true
                }
            }

            TapHandler {
                onTapped: {
                    const w = tab.Window.window
                    if (w && w.activeFocusItem) w.activeFocusItem.focus = false
                }
            }

            delegate: Item {
                required property var modelData
                required property int index
                width: lrcList.width
                height: activeText.implicitHeight + 8

                Text {
                    id: activeText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    text: modelData.text
                    color: index === tab.activeIndex ? theme.primary : theme.onBackground
                    opacity: index === tab.activeIndex ? 1.0 : 0.4
                    font.pixelSize: 17
                    font.weight: index === tab.activeIndex ? Font.DemiBold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    transformOrigin: Item.Center
                    scale: index === tab.activeIndex ? 1.06 : 1.0
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
        }

        Flickable {
            id: txtFlick
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            visible: !tab.isLrcMode
            opacity: tab.isLrcMode ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            contentWidth: width
            contentHeight: txtArea.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 300
            maximumFlickVelocity: 8000

            NumberAnimation {
                id: txtWheelAnim
                target: txtFlick
                property: "contentY"
                duration: 260
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                onWheel: (event) => {
                    const maxY = Math.max(0, txtFlick.contentHeight - txtFlick.height)
                    let dy = 0
                    if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                    else dy = (event.angleDelta.y / 120.0) * 140
                    const currentTarget = txtWheelAnim.running ? txtWheelAnim.to : txtFlick.contentY
                    const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                    txtWheelAnim.stop()
                    txtWheelAnim.from = txtFlick.contentY
                    txtWheelAnim.to = target
                    txtWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - txtFlick.contentY) * 1.2))
                    txtWheelAnim.start()
                    event.accepted = true
                }
            }

            TextEdit {
                id: txtArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                text: tab.lyricsRaw
                color: theme.onBackground
                font.pixelSize: 17
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                selectionColor: theme.primary
                selectedTextColor: theme.background
                textFormat: TextEdit.PlainText
                horizontalAlignment: TextEdit.AlignHCenter

                HoverHandler { cursorShape: Qt.IBeamCursor }
            }
        }

        Text {
            anchors.centerIn: parent
            text: tab.isLrcMode ? "No LRC lyrics found" : "No lyrics found"
            color: theme.outline
            opacity: 0.5
            font.pixelSize: 14
            visible: (tab.isLrcMode && tab.lrcLines.length === 0)
                  || (!tab.isLrcMode && tab.lyricsRaw.length === 0)
        }
    }
}
