// SPDX-License-Identifier: GPL-2.0-or-later
// For models without a drawing yet: one ring per zone, named as PredatorSense names them.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: view

    property var zones: ({})
    property bool synced: false
    property real t: -1
    property string selected: ""
    property string identifying: ""
    property var identifyLook
    signal picked(string zone)

    readonly property var areas: backend.zones.filter(z => z.id !== "global")
    readonly property real size: Math.min(200, (width - 40 * areas.length) / Math.max(1, areas.length))

    function look(zone) {
        if (identifying !== "" && (identifying === zone || identifying === "global"))
            return identifyLook
        return zones[zone]
    }

    MouseArea {
        anchors.fill: parent
        onClicked: view.picked("global")
    }

    MultiEffect {
        source: lights
        anchors.fill: lights
        blurEnabled: true
        blurMax: 48
        blur: 1
        opacity: 0.9
    }

    Row {
        id: lights
        anchors.centerIn: parent
        spacing: 40
        Repeater {
            model: view.areas
            Item {
                required property var modelData
                required property int index
                width: view.size
                height: view.size + 40
                Rectangle {
                    width: view.size; height: view.size; radius: width / 2
                    color: Theme.cavity
                    border.color: view.selected === modelData.id ? Theme.accent : Theme.metalEdge
                    border.width: view.selected === modelData.id ? 2 : 1
                }
                LedRing {
                    width: view.size; height: view.size
                    thickness: 10
                    zone: view.look(modelData.id)
                    t: view.t
                    synced: view.synced
                    posStart: index / view.areas.length
                    posSpan: 1 / view.areas.length
                    seed: index + 1
                }
                Label {
                    y: view.size + 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    color: view.selected === modelData.id ? Theme.text : Theme.textDim
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.picked(modelData.id)
                }
            }
        }
    }
}
