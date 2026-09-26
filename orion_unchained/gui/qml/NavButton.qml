// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: nav

    property string iconName
    property bool current: false
    property bool attention: false

    implicitWidth: 72
    implicitHeight: 64

    contentItem: Item {
        Icon {
            id: glyph
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            name: nav.iconName
            size: 24
            color: nav.current ? Theme.accent : nav.hovered ? Theme.text : Theme.textDim
        }
        Rectangle {
            visible: nav.attention
            x: glyph.x + glyph.width - 3
            y: glyph.y - 2
            width: 9; height: 9; radius: 4.5
            color: Theme.warn
            border.color: Theme.sidebar
            border.width: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            text: nav.text
            color: nav.current ? Theme.text : Theme.textDim
            font.pixelSize: Theme.fontTiny
            font.weight: nav.current ? Font.DemiBold : Font.Normal
        }
    }

    background: Rectangle {
        radius: 12
        color: nav.current ? Theme.alpha(Theme.accent, 0.1) : nav.hovered ? Theme.surface2 : "transparent"
        Rectangle {
            visible: nav.current
            x: -8
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 24
            radius: 1.5
            color: Theme.accent
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
