// SPDX-License-Identifier: GPL-2.0-or-later
// The Predator Orion 7000 (PO7-660) unfolded like a box: rear panel, the inside as seen
// through the side window, front panel, and the radiator on top. Zones as PredatorSense
// lays them out: area1 CPU cooler, area2 front, area3 radiator, area4 rear fan.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import "effects.js" as Fx

Item {
    id: view

    property var zones: ({})          // zone id -> state
    property bool synced: false
    property real t: -1
    property string selected: ""
    property string identifying: ""
    property var identifyLook
    property bool glow: true
    property bool labels: true
    signal picked(string zone)

    property string hovered: ""
    readonly property real s: Math.min(width / 1000, height / 660)

    function look(zone) {
        if (identifying !== "" && (identifying === zone || identifying === "global"))
            return identifyLook
        return zones[zone]
    }

    readonly property var rings: Fx.PO7_660_RINGS

    readonly property var areas: [
        { zone: "area4", x: 30, y: 176, w: 210, h: 448, lx: 30, ly: 146 },
        { zone: "area3", x: 270, y: 36, w: 430, h: 112, lx: 270, ly: 6 },
        { zone: "area1", x: 350, y: 252, w: 120, h: 120, lx: 350, ly: 380 },
        { zone: "area2", x: 730, y: 36, w: 230, h: 588, lx: 730, ly: 6 }
    ]

    function label(zone) {
        for (const z of backend.zones)
            if (z.id === zone)
                return z.label
        return zone
    }

    Item {
        id: design
        width: 1000
        height: 660
        scale: view.s
        transformOrigin: Item.TopLeft
        x: (view.width - width * view.s) / 2
        y: (view.height - height * view.s) / 2

        MouseArea {
            anchors.fill: parent
            onClicked: view.picked("global")
        }

        // --- the case, unlit -----------------------------------------------------

        // Rear panel
        Rectangle {
            x: 30; y: 176; width: 210; height: 448; radius: 16
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.metalLight }
                GradientStop { position: 1; color: Theme.metal }
            }
            border.color: Theme.metalEdge

            Rectangle {   // I/O shield
                x: 16; y: 24; width: 38; height: 172; radius: 5
                color: Theme.cavity; border.color: Theme.metalEdge
                Column {
                    anchors.centerIn: parent
                    spacing: 7
                    Repeater {
                        model: 8
                        Rectangle {
                            width: index % 3 === 0 ? 22 : 16; height: index % 3 === 0 ? 9 : 7; radius: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#161b23"; border.color: "#232a35"
                        }
                    }
                }
            }
            Column {       // expansion slot covers
                x: 16; y: 222; spacing: 9
                Repeater {
                    model: 7
                    Rectangle {
                        width: 178; height: 11; radius: 3
                        color: index < 3 ? "#10141a" : Theme.cavity
                        border.color: Theme.metalEdge
                    }
                }
            }
            Rectangle {   // power supply
                x: 16; y: 384; width: 178; height: 50; radius: 6
                color: Theme.cavity; border.color: Theme.metalEdge
                Rectangle {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15; color: "transparent"; border.color: "#232a35"
                }
                Rectangle {
                    x: 140; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 18; radius: 3; color: "#161b23"; border.color: "#232a35"
                }
            }
        }
        Fan { x: 110; y: 222; width: 120; height: 120; blades: 7; ringWidth: 8 }

        // Radiator on top
        Rectangle {
            x: 270; y: 36; width: 430; height: 112; radius: 14
            color: Theme.metal
            border.color: Theme.metalEdge
            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 5
                clip: true
                Repeater {
                    model: 80
                    Rectangle { width: 1; height: parent.height; color: "#19202a" }
                }
            }
            Rectangle { x: 6; y: 8; width: 14; height: parent.height - 16; radius: 5; color: Theme.metalLight; border.color: Theme.metalEdge }
            Rectangle { x: parent.width - 20; y: 8; width: 14; height: parent.height - 16; radius: 5; color: Theme.metalLight; border.color: Theme.metalEdge }
        }
        Repeater {
            model: [345, 485, 625]
            Fan { x: modelData - 50; y: 42; width: 100; height: 100; blades: 7; ringWidth: 8 }
        }

        // Inside, seen through the side window: rear on the left, front on the right
        Rectangle {
            x: 270; y: 176; width: 430; height: 448; radius: 16
            color: "#0d1016"
            border.color: Theme.metalEdge

            Rectangle {   // motherboard
                x: 20; y: 20; width: 312; height: 350; radius: 6
                color: "#10141a"; border.color: "#1d2430"
                Rectangle { x: 22; y: 16; width: 170; height: 16; radius: 4; color: "#151a22"; border.color: "#222a35" }
                Rectangle { x: 22; y: 40; width: 16; height: 120; radius: 4; color: "#151a22"; border.color: "#222a35" }
                Repeater {
                    model: 4
                    Rectangle { x: 222 + index * 12; y: 60; width: 7; height: 144; radius: 2; color: "#141922"; border.color: "#252d39" }
                }
                Rectangle { x: 150; y: 270; width: 60; height: 44; radius: 4; color: "#131820"; border.color: "#1f2631" }
            }
            Rectangle {   // graphics card: its lighting is not supported yet
                id: gpu
                x: 20; y: 238; width: 370; height: 92; radius: 10
                color: "#0f1318"; border.color: "#262e3b"
                Repeater {
                    model: 3
                    Fan {
                        x: 56 + index * 102; y: 12; width: 68; height: 68; blades: 9; ringWidth: 0
                        opacity: 0.8
                    }
                }
                HoverHandler { id: gpuHover }
                ToolTip.visible: gpuHover.hovered
                ToolTip.delay: 300
                ToolTip.text: "Graphics card lighting is not supported yet."
            }
            Rectangle {   // power supply shroud
                x: 10; y: 374; width: 410; height: 62; radius: 8
                color: "#0f1217"; border.color: "#1c222c"
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: 12
                        Rectangle { width: 3; height: 22; radius: 1.5; color: "#171c25" }
                    }
                }
            }
        }
        Rectangle {   // pump block of the liquid cooler
            x: 350; y: 252; width: 120; height: 120; radius: 26
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a2029" }
                GradientStop { position: 1; color: "#10141a" }
            }
            border.color: Theme.metalEdge
            Rectangle {
                anchors.centerIn: parent
                width: 88; height: 88; radius: 44
                color: "transparent"; border.color: Theme.unlit; border.width: 9
            }
            Rectangle {
                anchors.centerIn: parent
                width: 62; height: 62; radius: 31
                color: "#0d1015"; border.color: "#232a35"
            }
        }

        // Front panel
        Rectangle {
            x: 730; y: 36; width: 230; height: 588; radius: 18
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.metalLight }
                GradientStop { position: 1; color: Theme.metal }
            }
            border.color: Theme.metalEdge
            Rectangle {
                anchors.fill: parent; anchors.margins: 16; radius: 12
                color: Theme.cavity; border.color: "#1d2430"
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 34
                spacing: 6
                Repeater {
                    model: 14
                    Rectangle { width: 4; height: 12; radius: 2; color: "#181e27" }
                }
            }
        }
        Rectangle {   // emblem
            x: 845 - 58; y: 146 - 58; width: 116; height: 116; radius: 58
            color: "#0d1015"; border.color: Theme.metalEdge
            Rectangle {
                anchors.fill: parent; anchors.margins: 1; radius: width / 2
                color: "transparent"; border.color: Theme.unlit; border.width: 10
            }
        }
        Fan { x: 845 - 78; y: 322 - 78; width: 156; height: 156; blades: 7; ringWidth: 10 }
        Fan { x: 845 - 78; y: 502 - 78; width: 156; height: 156; blades: 7; ringWidth: 10 }

        // --- light --------------------------------------------------------------

        // Light spilling onto the case: a wide soft glow and a tight halo under the crisp rings.
        MultiEffect {
            visible: view.glow
            source: lights
            anchors.fill: lights
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            blurMultiplier: 0.8
            brightness: 0.2
            saturation: 0.15
        }
        MultiEffect {
            visible: view.glow
            source: lights
            anchors.fill: lights
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 20
            blur: 0.9
            brightness: 0.1
        }

        Item {
            id: lights
            width: 1000
            height: 660

            Repeater {
                model: view.rings
                LedRing {
                    required property var modelData
                    required property int index
                    x: modelData.x - modelData.r
                    y: modelData.y - modelData.r
                    width: modelData.r * 2
                    height: width
                    thickness: modelData.th
                    zone: view.look(modelData.zone)
                    t: view.t
                    synced: view.synced && view.identifying === ""
                    posStart: modelData.posStart
                    posSpan: modelData.posSpan
                    chainStart: modelData.chainStart
                    chainSpan: modelData.chainSpan
                    yTop: modelData.yTop
                    ySpan: modelData.ySpan
                    seed: index + 1
                }
            }

            // Orion's belt on the emblem and the pump cap, lit with their zones
            Repeater {
                model: [
                    { zone: "area2", x: 845, y: 146, d: 17, size: 17 },
                    { zone: "area1", x: 410, y: 312, d: 11, size: 11 }
                ]
                Item {
                    id: badge
                    required property var modelData
                    readonly property color lit: Fx.swatch(view.look(modelData.zone), view.t)
                    Repeater {
                        model: 3
                        Shape {
                            id: star
                            required property int index
                            readonly property real k: index - 1
                            readonly property real size: badge.modelData.size * (index === 1 ? 1.3 : 1)
                            width: size
                            height: size
                            x: badge.modelData.x + k * badge.modelData.d * 1.3 - size / 2
                            y: badge.modelData.y - k * badge.modelData.d * 0.8 - size / 2
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: "transparent"
                                fillColor: badge.lit
                                scale: Qt.size(star.size / 24, star.size / 24)
                                PathSvg { path: "M12 1C12.8 8.4 15.6 11.2 23 12C15.6 12.8 12.8 15.6 12 23C11.2 15.6 8.4 12.8 1 12C8.4 11.2 11.2 8.4 12 1Z" }
                            }
                        }
                    }
                }
            }

            // Memory sticks, only when the driver offers memory lighting
            Repeater {
                model: view.zones["dimm"] ? 4 : 0
                Rectangle {
                    required property int index
                    x: 270 + 20 + 222 + index * 12 + 1
                    y: 176 + 20 + 60 + 4
                    width: 5; height: 40; radius: 2
                    color: Fx.led(view.look("dimm"), view.t, index, 4, index / 4, index / 4, 0.5, 11)
                }
            }
        }

        // --- zones you can click ----------------------------------------------------

        Repeater {
            model: view.areas
            Item {
                id: area
                required property var modelData
                readonly property bool on: view.selected === modelData.zone
                readonly property bool hot: view.hovered === modelData.zone
                readonly property bool present: view.zones[modelData.zone] !== undefined

                Rectangle {
                    x: area.modelData.x - 7; y: area.modelData.y - 7
                    width: area.modelData.w + 14; height: area.modelData.h + 14
                    radius: 22
                    color: "transparent"
                    border.width: 2
                    border.color: area.on ? Theme.accent : Theme.textDim
                    opacity: !area.present ? 0 : view.selected === area.modelData.zone ? 1 : area.hot ? 0.45 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
                MouseArea {
                    x: area.modelData.x; y: area.modelData.y
                    width: area.modelData.w; height: area.modelData.h
                    enabled: area.present
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.hovered = area.modelData.zone
                    onExited: if (view.hovered === area.modelData.zone) view.hovered = ""
                    onClicked: view.picked(area.modelData.zone)
                }
                Rectangle {
                    visible: view.labels && area.present
                    x: area.modelData.lx; y: area.modelData.ly
                    width: tag.implicitWidth + 30; height: 24; radius: 12
                    color: view.selected === area.modelData.zone ? Theme.alpha(Theme.accent, 0.16) : Theme.alpha(Theme.surface3, 0.9)
                    border.color: view.selected === area.modelData.zone ? Theme.alpha(Theme.accent, 0.6) : Theme.line
                    Rectangle {
                        x: 9; anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: Theme.zoneColor(view.zones[area.modelData.zone] ? view.zones[area.modelData.zone].color : "")
                        visible: view.zones[area.modelData.zone] && view.zones[area.modelData.zone].mode !== "off"
                    }
                    Text {
                        id: tag
                        x: 22; anchors.verticalCenter: parent.verticalCenter
                        text: view.label(area.modelData.zone)
                        color: view.selected === area.modelData.zone ? Theme.text : Theme.textDim
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.picked(area.modelData.zone)
                    }
                }
            }
        }
    }
}
