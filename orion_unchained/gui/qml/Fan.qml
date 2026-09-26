// SPDX-License-Identifier: GPL-2.0-or-later
// An unlit fan seen from the front: dark frame, curved blades and a hub.
import QtQuick
import QtQuick.Shapes

Item {
    id: fan

    property int blades: 7
    property real ringWidth: 8        // diffuser ring the LEDs shine through, 0 for none
    property color bladeColor: "#181d26"
    property color edgeColor: "#252c38"

    readonly property real r: Math.min(width, height) / 2

    function polar(radius, angle) {
        return (r + radius * Math.cos(angle)).toFixed(2) + " " + (r + radius * Math.sin(angle)).toFixed(2)
    }

    function bladePath() {
        const hub = r * 0.3, tip = r * 0.84, step = 2 * Math.PI / blades
        let d = ""
        for (let k = 0; k < blades; k++) {
            const a = k * step - Math.PI / 2
            const sweep = step * 0.9
            d += "M" + polar(hub, a)
               + " Q" + polar((hub + tip) * 0.55, a + sweep * 0.2) + " " + polar(tip, a + sweep)
               + " A" + tip.toFixed(2) + " " + tip.toFixed(2) + " 0 0 1 " + polar(tip, a + sweep + step * 0.55)
               + " Q" + polar((hub + tip) * 0.5, a + step * 0.45 + sweep * 0.45) + " " + polar(hub, a + step * 0.45)
               + " A" + hub.toFixed(2) + " " + hub.toFixed(2) + " 0 0 0 " + polar(hub, a) + " Z "
        }
        return d
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.cavity
        border.color: Theme.metalEdge
        border.width: 1
    }

    Rectangle {
        visible: fan.ringWidth > 0
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        color: "transparent"
        border.color: Theme.unlit
        border.width: fan.ringWidth + 2
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillGradient: RadialGradient {
                centerX: fan.r; centerY: fan.r; centerRadius: fan.r
                focalX: fan.r * 0.8; focalY: fan.r * 0.7
                GradientStop { position: 0; color: Qt.lighter(fan.bladeColor, 1.35) }
                GradientStop { position: 1; color: fan.bladeColor }
            }
            strokeColor: fan.edgeColor
            strokeWidth: 1
            PathSvg { path: fan.bladePath() }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: fan.r * 0.62
        height: width
        radius: width / 2
        color: "#12161d"
        border.color: fan.edgeColor
        border.width: 1

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: width
            radius: width / 2
            color: "#0e1116"
        }
    }
}
