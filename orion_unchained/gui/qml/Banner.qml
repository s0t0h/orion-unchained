// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: banner

    property string iconName: "info"
    property string text
    property string actionText: ""
    property color tint: Theme.accent
    signal action()

    implicitHeight: row.implicitHeight + 20
    radius: Theme.radiusSmall
    color: Theme.alpha(tint, 0.09)
    border.color: Theme.alpha(tint, 0.35)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 12
        Icon { name: banner.iconName; size: 18; color: banner.tint }
        Label {
            Layout.fillWidth: true
            text: banner.text
            color: Theme.text
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontBody
        }
        ActionButton {
            visible: banner.actionText !== ""
            text: banner.actionText
            quiet: true
            onClicked: banner.action()
        }
    }
}
