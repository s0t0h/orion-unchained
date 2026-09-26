// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog

    property string title
    property string text
    property string confirmText: "OK"
    property bool danger: false
    signal confirmed()

    anchors.centerIn: Overlay.overlay
    width: 420
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.lineStrong
    }

    contentItem: ColumnLayout {
        spacing: 12
        Label {
            text: dialog.title
            color: Theme.text
            font.pixelSize: Theme.fontHeading
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            text: dialog.text
            color: Theme.textDim
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.topMargin: 8
            spacing: 10
            Item { Layout.fillWidth: true }
            ActionButton {
                text: "Cancel"
                onClicked: dialog.close()
            }
            ActionButton {
                text: dialog.confirmText
                primary: true
                onClicked: {
                    dialog.close()
                    dialog.confirmed()
                }
            }
        }
    }
}
