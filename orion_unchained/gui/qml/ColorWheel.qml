// SPDX-License-Identifier: GPL-2.0-or-later
// Hue around the circle, saturation from the centre out. Brightness has its own slider.
import QtQuick
import QtQuick.Shapes

Item {
    id: wheel

    property color value: "white"
    property bool marker: true
    signal picked(color value)

    implicitWidth: 150
    implicitHeight: 150

    readonly property real r: Math.min(width, height) / 2
    property color pending
    property bool hasPending: false

    function pick(x, y) {
        const dx = x - r, dy = r - y
        const sat = Math.min(1, Math.sqrt(dx * dx + dy * dy) / r)
        let h = Math.atan2(dy, dx) / (2 * Math.PI)
        if (h < 0)
            h += 1
        pending = Qt.hsva(h, sat, 1, 1)
        hasPending = true
        if (!throttle.running) {
            flush()
            throttle.start()
        }
    }

    function flush() {
        if (hasPending) {
            hasPending = false
            picked(pending)
        }
    }

    // A drag produces far more positions than the firmware should see; about 25 per second is plenty.
    Timer {
        id: throttle
        interval: 40
        onTriggered: wheel.flush()
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: wheel.r; centerY: wheel.r; angle: 0
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }
            PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.08)
            strokeWidth: 1
            fillGradient: RadialGradient {
                centerX: wheel.r; centerY: wheel.r; centerRadius: wheel.r
                focalX: wheel.r; focalY: wheel.r
                GradientStop { position: 0; color: "#ffffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
            PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
        }
    }

    Rectangle {
        visible: wheel.marker
        readonly property real hue: Math.max(0, wheel.value.hsvHue)
        readonly property real dist: wheel.value.hsvSaturation * wheel.r
        width: 20
        height: 20
        radius: 10
        x: wheel.r + Math.cos(hue * 2 * Math.PI) * dist - width / 2
        y: wheel.r - Math.sin(hue * 2 * Math.PI) * dist - height / 2
        color: Qt.hsva(hue, wheel.value.hsvSaturation, 1, 1)
        border.color: "white"
        border.width: 2.5
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        onPressed: mouse => wheel.pick(mouse.x, mouse.y)
        onPositionChanged: mouse => { if (pressed) wheel.pick(mouse.x, mouse.y) }
        onReleased: {
            throttle.stop()
            wheel.flush()
        }
    }
}
