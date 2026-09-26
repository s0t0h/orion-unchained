// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: card

    property var style
    property real clock: 0
    readonly property bool active: backend.currentStyle === style.id
    readonly property bool hot: hover.hovered || moreButton.hovered
    signal apply()
    signal menu(Item anchor)

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 7
        radius: Theme.radius
        color: card.hot ? Theme.surface2 : Theme.surface
        border.color: card.active ? Theme.accent : card.hot ? Theme.lineStrong : Theme.line
        border.width: card.active ? 1.5 : 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            id: stage
            x: 1; y: 1
            width: parent.width - 2
            height: 124
            topLeftRadius: Theme.radius - 1
            topRightRadius: Theme.radius - 1
            color: "#0c0f14"

            MiniCase {
                anchors.fill: parent
                anchors.margins: 10
                looks: card.style.preview
                synced: card.style.synced
                t: card.hot ? card.clock : -1
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: stage.bottom
            anchors.margins: 14
            anchors.topMargin: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Label {
                    Layout.fillWidth: true
                    text: card.style.name
                    color: Theme.text
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: card.active
                    implicitWidth: onRow.implicitWidth + 14
                    implicitHeight: 20
                    radius: 10
                    color: Theme.alpha(Theme.accent, 0.15)
                    Row {
                        id: onRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { name: "check"; size: 12; stroke: 2.4; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "On"; color: Theme.accent; font.pixelSize: Theme.fontTiny; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Rectangle {
                    visible: card.style.user
                    implicitWidth: yours.implicitWidth + 14
                    implicitHeight: 20
                    radius: 10
                    color: Theme.alpha(Theme.violet, 0.16)
                    Label { id: yours; anchors.centerIn: parent; text: "Yours"; color: "#c4a8ff"; font.pixelSize: Theme.fontTiny; font.weight: Font.DemiBold }
                }
            }
            Label {
                Layout.fillWidth: true
                text: card.style.description || " "
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.1
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: card.style.tags.join("  ·  ")
                color: Theme.textMuted
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideRight
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: card.apply()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: card.menu(moreButton)
        }

        IconButton {
            id: moreButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            visible: card.hot
            iconName: "more"
            iconColor: Theme.text
            tip: "More"
            background: Rectangle {
                radius: Theme.radiusSmall
                color: moreButton.hovered ? Theme.surface3 : Theme.alpha(Theme.surface, 0.8)
                border.color: Theme.line
            }
            onClicked: card.menu(moreButton)
        }
    }
}
