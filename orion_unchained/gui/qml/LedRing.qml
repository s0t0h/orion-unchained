// SPDX-License-Identifier: GPL-2.0-or-later
// A fan's LED ring: 24 LEDs behind a diffuser, blended into one band of light by a
// conical gradient. Only the light is drawn; the fan and the unlit diffuser belong to
// the case drawing, so a glow layer on top blurs light and nothing else.
import QtQuick
import QtQuick.Shapes
import "effects.js" as Fx

Shape {
    id: ring

    property var zone
    property real t: -1
    property real thickness: 8
    // Where this ring sits when a global effect runs across the case in sync.
    property bool synced: false
    property real posStart: 0
    property real posSpan: 1
    // Where this ring sits among the LEDs of its own area.
    property real chainStart: 0
    property real chainSpan: 1
    property real yTop: 0
    property real ySpan: 1
    property int seed: 0

    readonly property int count: 24
    readonly property real r: Math.min(width, height) / 2
    // Static light does not change over time, so it need not be worked out every frame.
    readonly property real now: zone && zone.mode !== "static" && zone.mode !== "off" ? t : -1

    // LEDs count clockwise from the top; the gradient runs counter-clockwise from the top.
    function led(i) {
        const a = i / count * 2 * Math.PI - Math.PI / 2
        const edge = (1 + Math.sin(a)) / 2
        const chain = chainStart + chainSpan * i / count
        return Fx.led(zone, now, i, count,
                      synced ? posStart + posSpan * i / count : chain,
                      chain,
                      synced ? yTop + ySpan * edge : edge,
                      seed)
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        fillGradient: ConicalGradient {
            centerX: ring.r
            centerY: ring.r
            angle: 90
            GradientStop { position: 0.00000; color: ring.led(0) }
            GradientStop { position: 0.04167; color: ring.led(23) }
            GradientStop { position: 0.08333; color: ring.led(22) }
            GradientStop { position: 0.12500; color: ring.led(21) }
            GradientStop { position: 0.16667; color: ring.led(20) }
            GradientStop { position: 0.20833; color: ring.led(19) }
            GradientStop { position: 0.25000; color: ring.led(18) }
            GradientStop { position: 0.29167; color: ring.led(17) }
            GradientStop { position: 0.33333; color: ring.led(16) }
            GradientStop { position: 0.37500; color: ring.led(15) }
            GradientStop { position: 0.41667; color: ring.led(14) }
            GradientStop { position: 0.45833; color: ring.led(13) }
            GradientStop { position: 0.50000; color: ring.led(12) }
            GradientStop { position: 0.54167; color: ring.led(11) }
            GradientStop { position: 0.58333; color: ring.led(10) }
            GradientStop { position: 0.62500; color: ring.led(9) }
            GradientStop { position: 0.66667; color: ring.led(8) }
            GradientStop { position: 0.70833; color: ring.led(7) }
            GradientStop { position: 0.75000; color: ring.led(6) }
            GradientStop { position: 0.79167; color: ring.led(5) }
            GradientStop { position: 0.83333; color: ring.led(4) }
            GradientStop { position: 0.87500; color: ring.led(3) }
            GradientStop { position: 0.91667; color: ring.led(2) }
            GradientStop { position: 0.95833; color: ring.led(1) }
            GradientStop { position: 1.00000; color: ring.led(0) }
        }
        PathAngleArc {
            centerX: ring.r; centerY: ring.r
            radiusX: ring.r; radiusY: ring.r
            startAngle: 0; sweepAngle: 360
        }
        PathAngleArc {
            centerX: ring.r; centerY: ring.r
            radiusX: ring.r - ring.thickness; radiusY: ring.r - ring.thickness
            startAngle: 0; sweepAngle: 360
        }
    }
}
