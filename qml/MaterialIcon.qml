import QtQuick

Text {
    id: root

    property string glyph: ""
    property int iconSize: 20
    property color iconColor: theme.onSurface
    property bool filled: false

    property real fillProgress: 0
    property real spinAngle: 0

    rotation: spinAngle

    Behavior on fillProgress {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    Behavior on rotation {
        enabled: false
    }

    Component.onCompleted: fillProgress = filled ? 1 : 0
    onFilledChanged: fillProgress = filled ? 1 : 0

    NumberAnimation {
        id: spinAnim
        target: root
        property: "spinAngle"
        duration: 520
        easing.type: Easing.OutCubic
    }

    function spin() {
        spinAnim.stop()
        root.spinAngle = 0
        spinAnim.from = 0
        spinAnim.to = 360
        spinAnim.start()
    }

    font.family: "Material Symbols Rounded"
    font.pixelSize: iconSize
    color: iconColor
    text: glyph
    renderType: Text.NativeRendering
    font.variableAxes: ({
        "FILL": fillProgress,
        "wght": 400,
        "GRAD": 0,
        "opsz": 24
    })
}