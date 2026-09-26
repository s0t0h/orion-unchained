// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: button

    property string iconName
    property string tip: ""
    property color iconColor: Theme.textDim
    property real iconSize: 18

    implicitWidth: 34
    implicitHeight: 34
    opacity: enabled ? 1 : 0.4

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: button.iconName
            size: button.iconSize
            color: button.hovered ? Theme.text : button.iconColor
        }
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: button.down ? Theme.line : button.hovered ? Theme.surface3 : "transparent"
    }

    ToolTip.visible: tip !== "" && hovered
    ToolTip.delay: 500
    ToolTip.text: tip

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
