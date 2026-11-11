import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: opacity > 0.01
    opacity: isActive ? 1 : 0
    enabled: isActive
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property int    subTab: 0
    property bool   textIsLrc: true
    property string statusText: ""
    property string newCoverPath: ""
    property string tagContent: ""
    property string lrcContent: ""

    property bool removeCoverRequested: false
    property bool savingInProgress: false

    signal closeRequested
    signal saved

    component FieldGroup: Rectangle {
        id: fgRoot
        property string label: ""
        property string placeholder: ""
        property alias  text:  fgField.text
        property alias  input: fgField
        property bool   readOnly: false

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: 10
        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.04)
        border.color: fgField.activeFocus
            ? theme.primary
            : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 180 } }

        HoverHandler { cursorShape: Qt.IBeamCursor }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
            onPressed: fgField.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 0

            Text {
                text: fgRoot.label
                color: theme.outline
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.6
            }

            TextInput {
                id: fgField
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                color: theme.onBackground
                font.pixelSize: 13
                selectByMouse: true
                clip: true
                selectionColor: theme.primary
                selectedTextColor: theme.background
                readOnly: fgRoot.readOnly
                cursorVisible: activeFocus
                cursorDelegate: Rectangle {
                    width: 2
                    color: theme.primary
                    visible: fgField.cursorVisible
                }

                onTextChanged: {
                    if (!activeFocus) cursorPosition = 0
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: fgRoot.placeholder
                    color: theme.outline
                    opacity: 0.5
                    font.pixelSize: 13
                    visible: fgField.text.length === 0 && !fgField.activeFocus
                    enabled: false
                }
            }
        }
    }

    onIsActiveChanged: {
        if (isActive) {
            refresh()
        } else {
            var w = tab.Window.window
            if (w) {
                var it = w.activeFocusItem
                if (it && it.focus) it.focus = false
            }
        }
    }



    function computeStatusText() {
        if (tab.statusText.length > 0) return tab.statusText
        if (tab.subTab !== 1) return ""
        return tab.textIsLrc ? "Saves to ~/.config/kute/txts/" : "Saves to track tag"
    }

    function refresh() {
        newCoverPath = ""
        removeCoverRequested = false
        titleField.text  = library.currentTitle
        artistField.text = library.currentArtist
        albumField.text  = library.currentAlbum
        const __fp = library.currentFilePath || ""
        const __fi = __fp.lastIndexOf("/")
        fileNameField.text = __fi >= 0 ? __fp.substring(__fi + 1) : __fp
        const newTag = String(library.loadTrackText(library.currentIndex, false) ?? "")
        const newLrc = String(library.loadTrackText(library.currentIndex, true)  ?? "")
        if (tagArea.text !== newTag) { tagArea.text = newTag; tagFlick.contentY = 0 }
        if (lrcArea.text !== newLrc) { lrcArea.text = newLrc; lrcFlick.contentY = 0 }
        tagContent = newTag
        lrcContent = newLrc
        statusText = ""
    }

    function downloadLrc() {
        if (library.currentIndex < 0) return
        const url = "https://lrclib.net/api/get?track_name="
            + encodeURIComponent(library.currentTitle)
            + "&artist_name=" + encodeURIComponent(library.currentArtist)
        statusText = "Loading..."
        const xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText)
                    if (data.syncedLyrics) {
                        lrcContent = data.syncedLyrics
                        lrcArea.text = lrcContent
                        lrcFlick.contentY = 0
                        statusText = "LRC loaded"
                    } else if (data.plainLyrics) {
                        tagContent = data.plainLyrics
                        tagArea.text = tagContent
                        tagFlick.contentY = 0
                        statusText = "Only plain text available"
                    } else statusText = "Not found"
                } catch (e) { statusText = "Parse error" }
            } else if (xhr.status === 404) statusText = "Not found on lrclib.net"
            else statusText = "Error " + xhr.status
        }
        xhr.send()
    }

    function performSave() {
        if (library.currentIndex < 0) { tab.closeRequested(); return }
        let ok = false
        if (subTab === 0) {
            savingInProgress = true
            const wantRemove = removeCoverRequested
                                && newCoverPath === ""
                                && library.currentCover !== ""
            if (wantRemove) {
                library.removeCurrentCover()
            }
            ok = library.saveMetadata(library.currentIndex,
                titleField.text, artistField.text, albumField.text, newCoverPath,
                fileNameField.text)
            savingInProgress = false
        } else {
            const lrc = String(lrcArea.text ?? "")
            const tag = String(tagArea.text ?? "")
            lrcContent = lrc
            tagContent = tag
            const okLrc = library.saveTrackText(library.currentIndex, lrc, true)
            const okTag = library.saveTrackText(library.currentIndex, tag, false)
            ok = okLrc && okTag
        }
        if (ok) tab.saved(); else tab.closeRequested()
    }

    Connections {
        target: library
        function onCurrentChanged() {
            if (tab.isActive && !tab.savingInProgress) tab.refresh()
        }
    }

    FileDialog {
        id: coverDialog
        title: "Select cover image"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp)"]
        onAccepted: {
            let p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            tab.newCoverPath = p
            tab.removeCoverRequested = false
        }
    }

    FileDialog {
        id: saveCoverDialog
        title: "Save cover image"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "jpg"
        nameFilters: ["JPEG (*.jpg *.jpeg)", "PNG (*.png)", "WebP (*.webp)"]

        readonly property string suggestedName: {
            const s = String(library.currentTitle || "cover")
            return s.replace(/[\/:*?"<>|]/g, "_") + ".jpg"
        }

        onVisibleChanged: {
            if (visible) currentFile = suggestedName
        }

        onAccepted: {
            let p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            library.saveCoverTo(p)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: metaFlick
                anchors.fill: parent
                visible: true
                enabled: tab.subTab === 0
                opacity: tab.subTab === 0 ? 1 : 0
                x: tab.subTab === 0 ? 0 : -24
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                contentWidth: width
                contentHeight: Math.max(metaFlick.height, metaRow.implicitHeight + compactFileRow.height + 12)
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

                RowLayout {
                    id: metaRow
                    x: 24; y: 0
                    width: metaFlick.width - 48
                    spacing: 24

                    ColumnLayout {
                        Layout.preferredWidth: 140
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        Item {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 140

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: theme.surfaceVariant
                            }
                            Icon {
                                anchors.centerIn: parent
                                glyph: "\ue405"; iconSize: 36
                                iconColor: theme.outline
                                visible: coverPreview.status !== Image.Ready
                            }
                            Image {
                                id: coverPreview

                                readonly property real dpr: Screen.devicePixelRatio > 0
                                                                ? Screen.devicePixelRatio : 1
                                readonly property int decodeSize: Math.ceil(140 * dpr)

                                anchors.fill: parent
                                source: {
                                    if (tab.newCoverPath !== "") return library.toFileUrl(tab.newCoverPath)
                                    if (library.currentCover !== "") return library.toFileUrl(library.currentCover) + "?v=" + library.coverVersion
                                    return ""
                                }
                                sourceSize.width: decodeSize
                                sourceSize.height: decodeSize
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                visible: false
                            }
                            Item {
                                id: previewMask
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14; color: "white"
                                }
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: coverPreview
                                maskEnabled: true
                                maskSource: previewMask
                                visible: coverPreview.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: "#000"
                                opacity: tab.removeCoverRequested ? 0.55 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Icon {
                                        Layout.alignment: Qt.AlignHCenter
                                        glyph: "\ue872"
                                        iconSize: 28
                                        iconColor: "white"
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Will be removed"
                                        color: "white"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 32
                            spacing: 5

                            Rectangle {
                                id: replaceCoverBtn
                                width: 42
                                height: 32
                                radius: 9
                                color: replaceCoverHov.containsMouse
                                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Icon {
                                    anchors.centerIn: parent
                                    glyph: "\ue3f4"
                                    iconSize: 16
                                    iconColor: theme.onBackground
                                }

                                MouseArea {
                                    id: replaceCoverHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: coverDialog.open()
                                }
                            }

                            Rectangle {
                                id: saveCoverBtn
                                readonly property bool btnActive: library.hasCurrent
                                                              && (library.currentCover !== "" || tab.newCoverPath !== "")
                                width: 42
                                height: 32
                                radius: 9
                                color: (saveCoverHov.containsMouse && btnActive)
                                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                                    : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06)
                                Behavior on color { ColorAnimation { duration: 180 } }
                                opacity: btnActive ? 1.0 : 0.45

                                Icon {
                                    anchors.centerIn: parent
                                    glyph: "\ue2c4"
                                    iconSize: 16
                                    iconColor: theme.onBackground
                                }

                                MouseArea {
                                    id: saveCoverHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: saveCoverBtn.btnActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: saveCoverBtn.btnActive
                                    onClicked: saveCoverDialog.open()
                                }
                            }

                            Rectangle {
                                id: removeCoverBtn
                                readonly property bool btnActive: library.hasCurrent
                                                              && tab.newCoverPath === ""
                                                              && (library.currentCover !== "" || tab.removeCoverRequested)
                                readonly property bool confirming: tab.removeCoverRequested
                                width: 42
                                height: 32
                                radius: 9
                                color: (removeCoverHov.containsMouse && removeCoverBtn.btnActive)
                                    ? (removeCoverBtn.confirming
                                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.22)
                                        : Qt.rgba(0.75, 0.22, 0.17, 0.85))
                                    : (removeCoverBtn.confirming
                                        ? Qt.rgba(0.75, 0.22, 0.17, 0.25)
                                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.06))
                                Behavior on color { ColorAnimation { duration: 180 } }
                                opacity: removeCoverBtn.btnActive ? 1.0 : 0.45

                                Icon {
                                    anchors.centerIn: parent
                                    glyph: removeCoverBtn.confirming ? "\ue8f4" : "\ue92e"
                                    iconSize: 16
                                    iconColor: (removeCoverHov.containsMouse && removeCoverBtn.btnActive && !removeCoverBtn.confirming)
                                               ? "white" : theme.onBackground
                                    Behavior on iconColor { ColorAnimation { duration: 180 } }
                                }

                                MouseArea {
                                    id: removeCoverHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: removeCoverBtn.btnActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: removeCoverBtn.btnActive
                                    onClicked: {
                                        tab.removeCoverRequested = !tab.removeCoverRequested
                                        if (tab.removeCoverRequested) tab.newCoverPath = ""
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        FieldGroup { id: titleField;  label: "Title";  placeholder: "Track title" }
                        FieldGroup { id: artistField; label: "Artist"; placeholder: "Artist" }
                        FieldGroup { id: albumField;  label: "Album";  placeholder: "Album" }
                        FieldGroup {
                            id: fileNameField
                            label: "File name"
                            placeholder: "—"
                        }

                    }
                }

                Rectangle {
                    id: compactFileRow
                    anchors.top: metaRow.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    height: fileCol.implicitHeight + 20
                    radius: 8
                    color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.04)
                    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.15)
                    border.width: 1

                    ColumnLayout {
                        id: fileCol
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 6

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 8
                            rowSpacing: 4

                            Text { text: "Format"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.currentFormat || "—"; color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }
                            Text { text: "Bitrate"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.currentBitrate > 0 ? library.currentBitrate + " kbps" : "—"; color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }
                            Text { text: "Sample rate"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.formatSampleRate(library.currentSampleRate); color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }

                            Text { text: "Size"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.formatFileSize(library.currentFileSize); color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }
                            Text { text: "Channels"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.currentChannels > 0 ? (library.currentChannels === 1 ? "1 (mono)" : library.currentChannels + " (stereo)") : "—"; color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }
                            Text { text: "Duration"; color: theme.outline; font.pixelSize: 10 }
                            Text { Layout.fillWidth: true; text: library.formatDuration(library.currentTrackDuration); color: theme.onSurface; font.pixelSize: 10; font.family: "monospace" }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: theme.outline
                            opacity: 0.15
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "Path"; color: theme.outline; font.pixelSize: 10 }
                            Text {
                                Layout.fillWidth: true
                                text: library.currentFilePath || "—"
                                color: theme.onSurface
                                font.pixelSize: 9
                                font.family: "monospace"
                                opacity: 0.8
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            Item {
                id: textPage
                anchors.fill: parent
                visible: true
                enabled: tab.subTab === 1
                opacity: tab.subTab === 1 ? 1 : 0
                x: tab.subTab === 1 ? 0 : 24
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 12
                    color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b,
                                   (lrcArea.activeFocus || tagArea.activeFocus) ? 0.06 : 0.03)
                    border.color: (lrcArea.activeFocus || tagArea.activeFocus)
                        ? theme.primary
                        : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    Flickable {
                        id: lrcFlick
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: lrcArea.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 300
                        maximumFlickVelocity: 8000
                        enabled: tab.textIsLrc
                        visible: opacity > 0.01
                        opacity: tab.textIsLrc ? 1 : 0
                        x: tab.textIsLrc ? 0 : -16
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                        NumberAnimation { id: lrcWheelAnim; target: lrcFlick; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            blocking: true
                            onWheel: (event) => {
                                const maxY = Math.max(0, lrcFlick.contentHeight - lrcFlick.height)
                                let dy = 0
                                if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                                else dy = (event.angleDelta.y / 120.0) * 140
                                const currentTarget = lrcWheelAnim.running ? lrcWheelAnim.to : lrcFlick.contentY
                                const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                                lrcWheelAnim.stop()
                                lrcWheelAnim.from = lrcFlick.contentY
                                lrcWheelAnim.to = target
                                lrcWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - lrcFlick.contentY) * 1.2))
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

                        TextEdit {
                            id: lrcArea
                            width: lrcFlick.width
                            color: theme.onBackground
                            font.pixelSize: 17
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectionColor: theme.primary
                            selectedTextColor: theme.background
                            textFormat: TextEdit.PlainText
                            horizontalAlignment: TextEdit.AlignHCenter
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }

                    Flickable {
                        id: tagFlick
                        anchors.fill: parent
                        anchors.margins: 14
                        contentWidth: width
                        contentHeight: tagArea.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 300
                        maximumFlickVelocity: 8000
                        enabled: !tab.textIsLrc
                        visible: opacity > 0.01
                        opacity: tab.textIsLrc ? 0 : 1
                        x: tab.textIsLrc ? 16 : 0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on x       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                        NumberAnimation { id: tagWheelAnim; target: tagFlick; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            blocking: true
                            onWheel: (event) => {
                                const maxY = Math.max(0, tagFlick.contentHeight - tagFlick.height)
                                let dy = 0
                                if (Math.abs(event.pixelDelta.y) > 0) dy = event.pixelDelta.y * 3.5
                                else dy = (event.angleDelta.y / 120.0) * 140
                                const currentTarget = tagWheelAnim.running ? tagWheelAnim.to : tagFlick.contentY
                                const target = Math.max(0, Math.min(maxY, currentTarget - dy))
                                tagWheelAnim.stop()
                                tagWheelAnim.from = tagFlick.contentY
                                tagWheelAnim.to = target
                                tagWheelAnim.duration = Math.min(550, Math.max(240, Math.abs(target - tagFlick.contentY) * 1.2))
                                tagWheelAnim.start()
                                event.accepted = true
                            }
                        }

                        TapHandler {
                            onTapped: {
                                const w = tab.Window.window
                                if (w && w.activeFocusItem) w.activeFocusItem.focus = false
                            }
                        }

                        TextEdit {
                            id: tagArea
                            width: tagFlick.width
                            color: theme.onBackground
                            font.pixelSize: 17
                            wrapMode: TextEdit.Wrap
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
                        text: (tab.textIsLrc && lrcArea.text.length === 0) || (!tab.textIsLrc && tagArea.text.length === 0)
                            ? "No lyrics found" : ""
                        color: theme.outline
                        opacity: 0.4
                        font.pixelSize: 13
                        visible: text.length > 0
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: theme.outline; opacity: 0.15
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 8

                Rectangle {
                    id: dlFooterBtn
                    readonly property bool active: tab.subTab === 1 && tab.textIsLrc
                    property real dlW: active ? 30 : 0
                    Behavior on dlW { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Layout.preferredWidth: dlW
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    clip: true
                    radius: 8
                    opacity: active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    color: dlFooterHov.containsMouse
                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.24)
                        : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Icon {
                        anchors.centerIn: parent
                        glyph: ""
                        iconSize: 14
                        iconColor: theme.primary
                    }

                    MouseArea {
                        id: dlFooterHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.downloadLrc()
                    }
                }

                Text {
                    id: footerStatusText
                    property string displayed: tab.computeStatusText()
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: displayed
                    color: theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    opacity: 1

                    Connections {
                        target: tab
                        function onTextIsLrcChanged() { footerFadeAnim.restart() }
                        function onStatusTextChanged() { footerStatusText.displayed = tab.computeStatusText() }
                        function onSubTabChanged() { footerStatusText.displayed = tab.computeStatusText() }
                    }

                    SequentialAnimation {
                        id: footerFadeAnim
                        NumberAnimation { target: footerStatusText; property: "opacity"; to: 0; duration: 100; easing.type: Easing.OutCubic }
                        ScriptAction { script: footerStatusText.displayed = tab.computeStatusText() }
                        NumberAnimation { target: footerStatusText; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: cancelTxt.implicitWidth + 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10
                    color: cancelHov.containsMouse
                        ? Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.12)
                        : Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b, 0.05)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.onBackground
                        font.pixelSize: 12; font.weight: Font.Medium
                    }
                    MouseArea {
                        id: cancelHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.closeRequested()
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: saveTxt.implicitWidth + 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10
                    color: theme.primary
                    opacity: saveHov.containsMouse ? 1.0 : 0.92
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Text {
                        id: saveTxt
                        anchors.centerIn: parent
                        text: "Save"
                        color: theme.background
                        font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: saveHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.performSave()
                    }
                }
            }
        }
    }
}
