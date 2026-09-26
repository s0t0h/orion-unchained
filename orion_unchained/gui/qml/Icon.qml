// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Shapes
import "icons.js" as Icons

Item {
    id: icon

    property string name
    property color color: Theme.text
    property real size: 20
    property real stroke: 1.8

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Icons.strokes[icon.name] ? icon.color : "transparent"
            strokeWidth: icon.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.strokes[icon.name] || "M0 0" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: Icons.fills[icon.name] ? icon.color : "transparent"
            PathSvg { path: Icons.fills[icon.name] || "M0 0" }
        }
    }
}
