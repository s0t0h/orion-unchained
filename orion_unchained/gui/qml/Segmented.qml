// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Rectangle {
    id: seg

    property var options: []   // [{ text, icon, value }]
    property var value
    signal activated(var value)

    implicitHeight: 36
    implicitWidth: row.implicitWidth + 8
    radius: Theme.radiusSmall
    color: Theme.surface2
    border.color: Theme.line

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        Repeater {
            model: seg.options
            AbstractButton {
                id: option
                required property var modelData
                readonly property bool on: seg.value === modelData.value
                width: (row.width) / seg.options.length
                height: row.height
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            visible: option.modelData.icon !== undefined
                            name: option.modelData.icon || ""
                            size: 16
                            color: option.on ? Theme.text : Theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: option.modelData.text
                            color: option.on ? Theme.text : Theme.textDim
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                background: Rectangle {
                    radius: Theme.radiusSmall - 2
                    color: option.on ? Theme.surface3 : option.hovered ? Theme.alpha(Theme.surface3, 0.5) : "transparent"
                    border.color: option.on ? Theme.lineStrong : "transparent"
                }
                onClicked: seg.activated(modelData.value)
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
