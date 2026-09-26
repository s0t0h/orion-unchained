// SPDX-License-Identifier: GPL-2.0-or-later
// A pill that can be checked, with an optional item (a colour dot, a count) before the text.
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: chip

    property bool selected: false
    property Component lead: null
    property string trailing: ""

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 26
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold

    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Loader {
                active: chip.lead !== null
                visible: active
                sourceComponent: chip.lead
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.text
                font: chip.font
                color: chip.selected ? Theme.text : Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: chip.trailing !== ""
                text: chip.trailing
                font.pixelSize: Theme.fontTiny
                color: Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        radius: height / 2
        color: chip.selected ? Theme.alpha(Theme.accent, 0.14) : chip.hovered ? Theme.surface3 : Theme.surface2
        border.color: chip.selected ? Theme.alpha(Theme.accent, 0.7) : Theme.line
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
