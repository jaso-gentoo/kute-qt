import QtQuick

Text {
    id: root

    property string glyph: ""
    property int iconSize: 20
    property color iconColor: theme.onSurface
    property bool filled: false

    property real spinScale: 1.0
    property real spinAngle: 0

    scale: spinScale
    rotation: spinAngle
    Behavior on rotation { enabled: false }

    SequentialAnimation {
        id: spinAnim

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "spinScale"
                to: 1.35
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "spinAngle"
                to: 180
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "spinScale"
                to: 1.0
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 2.5
            }
            NumberAnimation {
                target: root
                property: "spinAngle"
                to: 360
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: root.spinAngle = 0
        }
    }

    function spin() {
        spinAnim.stop()
        root.spinScale = 1.0
        root.spinAngle = 0
        spinAnim.start()
    }

    font.family: "Material Symbols Rounded"
    font.pixelSize: iconSize
    color: iconColor
    text: glyph
    renderType: Text.NativeRendering
    font.variableAxes: ({
        "FILL": filled ? 1 : 0,
        "wght": 400,
        "GRAD": 0,
        "opsz": 24
    })
}