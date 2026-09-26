// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

TextField {
    id: field

    implicitHeight: 38
    leftPadding: 12
    rightPadding: 12
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    font.pixelSize: Theme.fontBody
    selectByMouse: true
    selectionColor: Theme.accentDim

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.surface2
        border.color: field.activeFocus ? Theme.accent : Theme.line
    }
}
