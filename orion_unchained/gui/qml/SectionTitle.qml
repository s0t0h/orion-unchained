// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: title

    property string text
    property string note: ""
    property string info: ""

    spacing: 8

    Label {
        text: title.text
        color: Theme.text
        font.pixelSize: Theme.fontBody
        font.weight: Font.DemiBold
    }
    Label {
        visible: title.note !== ""
        text: title.note
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }
    Icon {
        visible: title.info !== ""
        name: "info"
        size: 15
        stroke: 1.6
        color: infoHover.hovered ? Theme.text : Theme.textMuted
        HoverHandler { id: infoHover }
        ToolTip.visible: infoHover.hovered
        ToolTip.delay: 200
        ToolTip.text: title.info
    }
    Item { Layout.fillWidth: true }
}
