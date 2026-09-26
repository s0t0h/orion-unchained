// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

MenuItem {
    id: item

    property string iconName: ""
    property bool danger: false

    implicitHeight: 36
    leftPadding: 10
    rightPadding: 14
    font.pixelSize: Theme.fontBody

    contentItem: Row {
        spacing: 10
        Icon {
            name: item.iconName
            size: 17
            color: item.danger ? Theme.bad : item.highlighted ? Theme.text : Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: item.text
            font: item.font
            color: item.danger ? Theme.bad : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        implicitWidth: 230
        radius: 8
        color: item.highlighted ? Theme.surface3 : "transparent"
    }
}
