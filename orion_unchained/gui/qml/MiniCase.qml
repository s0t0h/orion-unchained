// SPDX-License-Identifier: GPL-2.0-or-later
// A small version of CaseView for style cards: the same layout with fewer LEDs and cheap halos.
import QtQuick
import QtQuick.Shapes
import "effects.js" as Fx

Item {
    id: mini

    property var looks: ({})      // area id -> state
    property bool synced: false
    property real t: -1

    readonly property real s: Math.min(width / 1000, height / 660)
    readonly property var rings: Fx.PO7_660_RINGS

    Item {
        width: 1000
        height: 660
        scale: mini.s
        transformOrigin: Item.TopLeft
        x: (mini.width - width * mini.s) / 2
        y: (mini.height - height * mini.s) / 2

        Rectangle { x: 30; y: 176; width: 210; height: 448; radius: 22; color: Theme.metal; border.color: Theme.metalEdge; border.width: 3 }
        Rectangle { x: 270; y: 36; width: 430; height: 112; radius: 20; color: Theme.metal; border.color: Theme.metalEdge; border.width: 3 }
        Rectangle { x: 270; y: 176; width: 430; height: 448; radius: 22; color: "#0d1016"; border.color: Theme.metalEdge; border.width: 3
            Rectangle { x: 20; y: 238; width: 370; height: 92; radius: 14; color: "#12161c" }
        }
        Rectangle { x: 350; y: 252; width: 120; height: 120; radius: 30; color: "#161b23" }
        Rectangle { x: 730; y: 36; width: 230; height: 588; radius: 24; color: Theme.metal; border.color: Theme.metalEdge; border.width: 3 }

        Repeater {
            model: mini.rings
            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property var look: mini.looks[modelData.zone]
                x: modelData.x - modelData.r
                y: modelData.y - modelData.r
                width: modelData.r * 2
                height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.cavity
                    border.color: Theme.unlit
                    border.width: 16
                }
                Shape {   // soft light around the ring
                    id: halo
                    readonly property color lit: Fx.swatch(slot.look, mini.t)
                    readonly property real r: width / 2
                    anchors.centerIn: parent
                    width: parent.width * 1.6
                    height: width
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: halo.r; centerY: halo.r; centerRadius: halo.r
                            focalX: halo.r; focalY: halo.r
                            GradientStop { position: 0.35; color: Theme.alpha(halo.lit, 0) }
                            GradientStop { position: 0.62; color: Theme.alpha(halo.lit, 0.5 * halo.lit.a) }
                            GradientStop { position: 1.0; color: Theme.alpha(halo.lit, 0) }
                        }
                        PathAngleArc { centerX: halo.r; centerY: halo.r; radiusX: halo.r; radiusY: halo.r; startAngle: 0; sweepAngle: 360 }
                    }
                }
                LedRing {
                    anchors.fill: parent
                    thickness: 16
                    zone: slot.look
                    t: mini.t
                    seed: slot.index + 1
                    synced: mini.synced
                    posStart: slot.modelData.posStart
                    posSpan: slot.modelData.posSpan
                    chainStart: slot.modelData.chainStart
                    chainSpan: slot.modelData.chainSpan
                    yTop: slot.modelData.yTop
                    ySpan: slot.modelData.ySpan
                }
            }
        }
    }
}
