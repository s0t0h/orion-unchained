// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Button {
    id: button

    property string iconName: ""
    property bool primary: false
    property bool quiet: false

    implicitHeight: 36
    leftPadding: iconName ? 12 : 16
    rightPadding: 16
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold
    opacity: enabled ? 1 : 0.45

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Icon {
                visible: button.iconName !== ""
                name: button.iconName
                size: 17
                anchors.verticalCenter: parent.verticalCenter
                color: button.primary ? Theme.accentText : Theme.text
            }
            Text {
                text: button.text
                font: button.font
                color: button.primary ? Theme.accentText : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: button.primary
               ? (button.down ? Theme.accentDim : button.hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
               : button.quiet
                 ? (button.down ? Theme.surface3 : button.hovered ? Theme.surface2 : "transparent")
                 : (button.down ? Theme.line : button.hovered ? Theme.surface3 : Theme.surface2)
        border.color: button.primary || button.quiet ? "transparent" : Theme.line
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
