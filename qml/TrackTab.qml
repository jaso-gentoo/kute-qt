import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts

FocusScope {
    id: tab
    property bool isActive: false
    visible: isActive

    property int    subTab: 0
    property bool   textIsLrc: false
    property string statusText: ""
    property string newCoverPath: ""
    property string tagContent: ""
    property string lrcContent: ""

    property bool removeCoverRequested: false
    property bool savingInProgress: false

    signal closeRequested
    signal saved

    function previousSubTab() {
        if (subTab === 1) {
            if (textIsLrc) lrcContent = textArea.text; else tagContent = textArea.text
            subTab = 0
        }
    }
    function nextSubTab() {
        if (subTab === 0) subTab = 1
    }

    component FieldGroup: ColumnLayout {
        id: fgRoot
        property string label: ""
        property string placeholder: ""
        property alias  text:  fgField.text
        property alias  input: fgField

        Layout.fillWidth: true
        spacing: 3

        Text {
            text: fgRoot.label
            color: theme.outline
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        TextInput {
            id: fgField
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            verticalAlignment: TextInput.AlignVCenter
            color: theme.onBackground
            font.pixelSize: 14
            selectByMouse: true
            clip: true
            selectionColor: theme.primary
            selectedTextColor: theme.background

            HoverHandler { cursorShape: Qt.IBeamCursor }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: fgRoot.placeholder
                color: theme.outline
                opacity: 0.5
                font.pixelSize: 14
                visible: fgField.text.length === 0 && !fgField.activeFocus
                enabled: false
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            radius: 1
            color: fgField.activeFocus ? theme.primary : theme.outline
            opacity: fgField.activeFocus ? 1 : 0.18
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    onIsActiveChanged: if (isActive) refresh()

    function refresh() {
        newCoverPath = ""
        removeCoverRequested = false
        titleField.text  = library.currentTitle
        artistField.text = library.currentArtist
        albumField.text  = library.currentAlbum
        textIsLrc = false
        tagContent = String(library.loadTrackText(library.currentIndex, false) ?? "")
        lrcContent = String(library.loadTrackText(library.currentIndex, true)  ?? "")
        textArea.text = tagContent
        offsetField.text = library.getLrcOffset(library.currentIndex).toFixed(2)
        statusText = ""
    }

    function switchTextMode(useLrc) {
        if (textIsLrc === useLrc) return
        if (textIsLrc) lrcContent = textArea.text; else tagContent = textArea.text
        textIsLrc = useLrc
        textArea.text = textIsLrc ? lrcContent : tagContent
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
                        if (tab.textIsLrc) textArea.text = lrcContent
                        statusText = "LRC loaded"
                    } else if (data.plainLyrics) {
                        tagContent = data.plainLyrics
                        if (!tab.textIsLrc) textArea.text = tagContent
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
                titleField.text, artistField.text, albumField.text, newCoverPath)
            savingInProgress = false
        } else {
            if (textIsLrc) lrcContent = textArea.text; else tagContent = textArea.text
            const tg = String(tagContent ?? "")
            const lr = String(lrcContent ?? "")
            let okTag = true, okLrc = true
            if (tg.trim().length > 0 || !textIsLrc) okTag = library.saveTrackText(library.currentIndex, tg, false)
            if (lr.trim().length > 0 || textIsLrc) okLrc = library.saveTrackText(library.currentIndex, lr, true)
            ok = okTag && okLrc
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
            return s.replace(/[\\/:*?"<>|]/g, "_") + ".jpg"
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
            Layout.preferredHeight: 44
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 0
                Repeater {
                    model: [ { idx: 0, label: "Metadata" }, { idx: 1, label: "Text" } ]
                    delegate: Item {
                        required property var modelData
                        readonly property bool active: tab.subTab === modelData.idx
                        Layout.preferredWidth: subLbl.implicitWidth + 24
                        Layout.preferredHeight: 36
                        Text {
                            id: subLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            color: active ? theme.primary : theme.onBackground
                            opacity: active ? 1.0 : 0.55
                            font.pixelSize: 12
                            font.weight: active ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: active ? subLbl.implicitWidth + 12 : 0
                            height: 2; radius: 1
                            color: theme.primary
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab.subTab === 1 && modelData.idx === 0) {
                                    if (tab.textIsLrc) tab.lrcContent = textArea.text
                                    else tab.tagContent = textArea.text
                                }
                                tab.subTab = modelData.idx
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: metaFlick
                anchors.fill: parent
                visible: tab.subTab === 0
                contentWidth: width
                contentHeight: metaRow.implicitHeight + 24
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
                    x: 24; y: 12
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
                            MaterialIcon {
                                anchors.centerIn: parent
                                glyph: "\ue405"; iconSize: 36
                                iconColor: theme.outline
                                visible: coverPreview.status !== Image.Ready
                            }
                            Image {
                                id: coverPreview
                                anchors.fill: parent
                                source: {
                                    if (tab.newCoverPath !== "") return "file://" + tab.newCoverPath
                                    if (library.currentCover !== "") return "file://" + library.currentCover + "?v=" + library.coverVersion
                                    return ""
                                }
                                sourceSize.width: 280; sourceSize.height: 280
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true; cache: false; smooth: true
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

                                    MaterialIcon {
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

                                MaterialIcon {
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

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 6
                                    width: replaceCoverTipTxt.implicitWidth + 16
                                    height: 24
                                    radius: 8
                                    color: theme.surface
                                    border.color: theme.outline
                                    border.width: 1
                                    opacity: replaceCoverHov.containsMouse ? 1 : 0
                                    visible: opacity > 0
                                    z: 9999
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        id: replaceCoverTipTxt
                                        anchors.centerIn: parent
                                        text: "Replace cover"
                                        color: theme.onSurface
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
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

                                MaterialIcon {
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

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 6
                                    width: saveCoverTipTxt.implicitWidth + 16
                                    height: 24
                                    radius: 8
                                    color: theme.surface
                                    border.color: theme.outline
                                    border.width: 1
                                    opacity: (saveCoverHov.containsMouse && saveCoverBtn.btnActive) ? 1 : 0
                                    visible: opacity > 0
                                    z: 9999
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        id: saveCoverTipTxt
                                        anchors.centerIn: parent
                                        text: "Save cover to file"
                                        color: theme.onSurface
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
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

                                MaterialIcon {
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

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 6
                                    width: removeCoverTipTxt.implicitWidth + 16
                                    height: 24
                                    radius: 8
                                    color: theme.surface
                                    border.color: theme.outline
                                    border.width: 1
                                    opacity: (removeCoverHov.containsMouse && removeCoverBtn.btnActive) ? 1 : 0
                                    visible: opacity > 0
                                    z: 9999
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        id: removeCoverTipTxt
                                        anchors.centerIn: parent
                                        text: removeCoverBtn.confirming
                                              ? "Click again to cancel"
                                              : "Remove cover"
                                        color: theme.onSurface
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
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
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: tab.subTab === 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [ { isLrc: false, label: "TAG" }, { isLrc: true, label: "LRC" } ]
                            delegate: Item {
                                required property var modelData
                                readonly property bool active: tab.textIsLrc === modelData.isLrc
                                Layout.preferredWidth: fmtLbl.implicitWidth + 22
                                Layout.preferredHeight: 30
                                Text {
                                    id: fmtLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: active ? theme.primary : theme.onBackground
                                    opacity: active ? 1.0 : 0.5
                                    font.pixelSize: 11; font.weight: Font.DemiBold
                                    font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on opacity { NumberAnimation { duration: 180 } }
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: active ? fmtLbl.implicitWidth + 12 : 0
                                    height: 2; radius: 1
                                    color: theme.primary
                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tab.switchTextMode(modelData.isLrc)
                                }
                            }
                        }

                        Item {
                            id: dlSlot
                            Layout.preferredWidth: tab.textIsLrc ? 28 : 0
                            Layout.preferredHeight: 30
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            Rectangle {
                                id: dlBtn
                                anchors.fill: parent
                                visible: tab.textIsLrc
                                radius: 8
                                color: dlHov.containsMouse
                                    ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.24)
                                    : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    glyph: "\ue2c4"
                                    iconSize: 14
                                    iconColor: theme.primary
                                }

                                MouseArea {
                                    id: dlHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: tab.textIsLrc
                                    onClicked: tab.downloadLrc()
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.bottom
                                anchors.topMargin: 6
                                width: dlTipTxt.implicitWidth + 16
                                height: 26
                                radius: 8
                                color: theme.surface
                                border.color: theme.outline
                                border.width: 1
                                opacity: (dlHov.containsMouse && tab.textIsLrc) ? 1 : 0
                                visible: opacity > 0
                                z: 9999

                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    id: dlTipTxt
                                    anchors.centerIn: parent
                                    text: "Download LRC from lrclib.net"
                                    color: theme.onBackground
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: tab.textIsLrc ? 120 : 0
                            Layout.preferredHeight: 28
                            clip: true
                            color: "transparent"
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 6
                                opacity: tab.textIsLrc ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "Offset"
                                    color: theme.outline
                                    font.pixelSize: 11; font.weight: Font.Medium
                                }
                                TextInput {
                                    id: offsetField
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 28
                                    verticalAlignment: TextInput.AlignVCenter
                                    horizontalAlignment: TextInput.AlignHCenter
                                    color: theme.onBackground
                                    font.pixelSize: 12; font.family: "monospace"
                                    selectByMouse: true; clip: true
                                    selectionColor: theme.primary
                                    selectedTextColor: theme.background
                                    validator: DoubleValidator { bottom: -60.0; top: 60.0; decimals: 2 }
                                    HoverHandler { cursorShape: Qt.IBeamCursor }
                                    onTextEdited: {
                                        const v = parseFloat(text)
                                        if (!isNaN(v)) library.setLrcOffset(library.currentIndex, v)
                                    }
                                    onEditingFinished: {
                                        const v = parseFloat(text)
                                        if (!isNaN(v)) {
                                            library.setLrcOffset(library.currentIndex, v)
                                            text = v.toFixed(2)
                                        } else text = library.getLrcOffset(library.currentIndex).toFixed(2)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: Qt.rgba(theme.onBackground.r, theme.onBackground.g, theme.onBackground.b,
                                       textArea.activeFocus ? 0.06 : 0.03)
                        border.color: textArea.activeFocus
                            ? theme.primary
                            : Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.10)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Flickable {
                            id: textFlick
                            anchors.fill: parent
                            anchors.margins: 14
                            contentWidth: width
                            contentHeight: textArea.implicitHeight
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
                                id: textArea
                                width: textFlick.width
                                color: theme.onBackground
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                selectionColor: theme.primary
                                selectedTextColor: theme.background
                                textFormat: TextEdit.PlainText
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: tab.statusText.length > 0
                            ? tab.statusText
                            : (tab.textIsLrc ? "Saves to ~/.config/kute/txts/" : "Saves to track tag")
                        color: theme.outline
                        font.pixelSize: 10
                        elide: Text.ElideRight
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
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: cancelTxt.implicitWidth + 28
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