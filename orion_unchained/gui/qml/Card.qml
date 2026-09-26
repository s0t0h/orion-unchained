// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    default property alias content: body.data

    implicitHeight: column.implicitHeight + 40
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.line

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        ColumnLayout {
            visible: card.title !== ""
            spacing: 2
            Label {
                text: card.title
                color: Theme.text
                font.pixelSize: Theme.fontHeading
                font.weight: Font.DemiBold
            }
            Label {
                visible: card.subtitle !== ""
                Layout.fillWidth: true
                text: card.subtitle
                color: Theme.textDim
                wrapMode: Text.Wrap
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 10
        }
    }
}
