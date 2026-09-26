// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

TextField {
    id: field

    implicitHeight: 36
    leftPadding: 36
    rightPadding: text ? 34 : 12
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    font.pixelSize: Theme.fontBody
    selectByMouse: true

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.surface2
        border.color: field.activeFocus ? Theme.accent : Theme.line
        Icon {
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 17
            color: Theme.textMuted
        }
    }

    IconButton {
        visible: field.text !== ""
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        iconName: "close"
        iconSize: 15
        onClicked: field.clear()
    }

    Keys.onEscapePressed: clear()
}
