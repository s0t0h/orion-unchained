// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Switch {
    id: toggle

    spacing: 10
    font.pixelSize: Theme.fontBody

    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 22
        x: toggle.leftPadding
        y: toggle.topPadding + toggle.availableHeight / 2 - height / 2
        radius: 11
        color: toggle.checked ? Theme.accent : Theme.surface3
        border.color: toggle.checked ? Theme.accent : Theme.lineStrong
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            x: toggle.checked ? parent.width - width - 3 : 3
            y: 3
            width: 16
            height: 16
            radius: 8
            color: toggle.checked ? Theme.accentText : Theme.textDim
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    contentItem: Text {
        text: toggle.text
        font: toggle.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        leftPadding: toggle.indicator.width + toggle.spacing
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
