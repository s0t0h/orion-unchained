// SPDX-License-Identifier: GPL-2.0-or-later
// One effect to pick, with a small ring that runs it in the zone's colour.
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: tile

    property var mode       // entry of backend.modes
    property var zone       // the zone's current settings
    property bool selected: false
    property real t: -1

    readonly property var look: zone ? Object.assign({}, zone, {
        mode: mode.id,
        brightness: 100,
        color: zone.color === "random" && !mode.random ? "ffffff" : zone.color
    }) : undefined

    implicitWidth: 64
    implicitHeight: 76

    background: Rectangle {
        radius: 12
        color: tile.selected ? Theme.alpha(Theme.accent, 0.12) : tile.hovered ? Theme.surface3 : Theme.surface2
        border.color: tile.selected ? Theme.accent : Theme.line
        border.width: tile.selected ? 1.5 : 1
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    contentItem: Item {
        Rectangle {
            id: base
            width: 34; height: 34; radius: 17
            anchors.horizontalCenter: parent.horizontalCenter
            y: 11
            color: "transparent"
            border.color: Theme.unlit
            border.width: 5
        }
        LedRing {
            anchors.fill: base
            thickness: 5
            zone: tile.look
            t: tile.t
            seed: 3
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 53
            text: tile.mode.name
            color: tile.selected ? Theme.text : Theme.textDim
            font.pixelSize: Theme.fontTiny
            font.weight: tile.selected ? Font.DemiBold : Font.Normal
        }
    }

    ToolTip.visible: hovered
    ToolTip.delay: 600
    ToolTip.text: mode.hint

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
