// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog

    property string author: ""
    signal authorUsed(string author)

    anchors.centerIn: Overlay.overlay
    width: 480
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

    function save() {
        if (name.text.trim() === "")
            return
        const id = backend.saveStyle(name.text, description.text, tags.text, who.text)
        if (id !== "") {
            dialog.authorUsed(who.text.trim())
            dialog.close()
        }
    }

    onOpened: {
        name.text = ""
        description.text = ""
        tags.text = ""
        who.text = dialog.author
        name.forceActiveFocus()
    }

    component FieldLabel: Label {
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
        Layout.topMargin: 6
    }

    contentItem: ColumnLayout {
        spacing: 6

        Label {
            text: "Save as style"
            color: Theme.text
            font.pixelSize: Theme.fontHeading
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            text: "Saves what the case shows now as a style file in your styles folder. You can apply it again later or share it."
            color: Theme.textDim
            wrapMode: Text.Wrap
        }

        FieldLabel { text: "Name" }
        InputField {
            id: name
            Layout.fillWidth: true
            placeholderText: "Night drive"
            onAccepted: dialog.save()
        }
        FieldLabel { text: "Description" }
        InputField {
            id: description
            Layout.fillWidth: true
            placeholderText: "One sentence about the look"
            onAccepted: dialog.save()
        }
        FieldLabel { text: "Tags" }
        InputField {
            id: tags
            Layout.fillWidth: true
            placeholderText: "neon, night"
            onAccepted: dialog.save()
        }
        FieldLabel { text: "Author" }
        InputField {
            id: who
            Layout.fillWidth: true
            placeholderText: "Your name or handle"
            onAccepted: dialog.save()
        }

        RowLayout {
            Layout.topMargin: 14
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: backend.userStyleDir.replace(/^\/home\/[^\/]+/, "~")
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.fontTiny
                elide: Text.ElideMiddle
            }
            ActionButton {
                text: "Cancel"
                onClicked: dialog.close()
            }
            ActionButton {
                text: "Save"
                iconName: "save"
                primary: true
                enabled: name.text.trim() !== ""
                onClicked: dialog.save()
            }
        }
    }
}
