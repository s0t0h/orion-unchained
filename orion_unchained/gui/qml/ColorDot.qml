// SPDX-License-Identifier: GPL-2.0-or-later
// The colour of a zone at a glance; a colour wheel when the effect brings its own colours.
import QtQuick
import QtQuick.Shapes
import "effects.js" as Fx

Item {
    id: dot

    property var look
    property real size: 10
    readonly property bool off: !look || look.mode === "off"
    readonly property bool many: !off && (look.color === "random" || !Fx.usesColor(look.mode))

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !dot.many
        color: dot.off ? "transparent" : "#" + dot.look.color
        border.width: 1
        border.color: dot.off ? Theme.textMuted : Qt.rgba(1, 1, 1, 0.18)
    }

    Shape {
        anchors.fill: parent
        visible: dot.many
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: dot.size / 2; centerY: dot.size / 2; angle: 90
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }
            PathAngleArc {
                centerX: dot.size / 2; centerY: dot.size / 2
                radiusX: dot.size / 2; radiusY: dot.size / 2
                startAngle: 0; sweepAngle: 360
            }
        }
    }
}
