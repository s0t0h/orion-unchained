// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

Rectangle {
    id: toast

    property string text
    property bool error: false
    property bool shown: false

    function show(message, isError) {
        text = message
        error = isError
        shown = true
        timer.interval = isError ? 6000 : 3000
        timer.restart()
    }

    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - (shown ? height + 28 : 0)
    width: Math.min(row.implicitWidth + 36, parent.width - 120)
    height: Math.max(44, row.implicitHeight + 20)
    radius: 22
    color: Theme.surface3
    border.color: error ? Theme.alpha(Theme.bad, 0.6) : Theme.lineStrong
    opacity: shown ? 1 : 0
    visible: opacity > 0
    z: 100

    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Timer {
        id: timer
        onTriggered: toast.shown = false
    }

    Row {
        id: row
        anchors.centerIn: parent
        width: Math.min(implicitWidth, toast.parent.width - 156)
        spacing: 10
        Icon {
            name: toast.error ? "alert" : "check"
            size: 18
            color: toast.error ? Theme.bad : Theme.good
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            width: Math.min(implicitWidth, toast.parent.width - 190)
            text: toast.text
            color: Theme.text
            wrapMode: Text.Wrap
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    TapHandler { onTapped: toast.shown = false }

    Connections {
        target: backend
        function onMessage(text, error) { toast.show(text, error) }
    }
}
