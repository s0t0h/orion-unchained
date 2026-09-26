// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control

    property string label
    property real value
    property real from: 0
    property real to: 100
    property string unit: ""
    property string note: ""
    property string info: ""
    property string lowText: ""
    property string highText: ""
    signal moved(real value)

    spacing: 4

    onValueChanged: if (!slider.pressed) slider.value = value
    Component.onCompleted: slider.value = value

    RowLayout {
        Layout.fillWidth: true
        SectionTitle {
            Layout.fillWidth: true
            text: control.label
            note: control.note
            info: control.info
        }
        Label {
            text: Math.round(slider.value) + control.unit
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.features: { "tnum": 1 }
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: control.from
        to: control.to
        stepSize: 1
        snapMode: Slider.SnapAlways
        onMoved: control.moved(Math.round(value))

        background: Item {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 6
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.surface3
            }
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentDim }
                    GradientStop { position: 1; color: Theme.accent }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: slider.pressed ? Theme.accent : "#f4f7fb"
            border.color: Theme.accent
            border.width: 2
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: control.lowText !== ""
        Label { text: control.lowText; color: Theme.textMuted; font.pixelSize: Theme.fontTiny }
        Item { Layout.fillWidth: true }
        Label { text: control.highText; color: Theme.textMuted; font.pixelSize: Theme.fontTiny }
    }
}
