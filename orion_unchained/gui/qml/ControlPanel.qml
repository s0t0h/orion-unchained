// SPDX-License-Identifier: GPL-2.0-or-later
// Every setting the firmware has, for the zone picked in the case view or the chips.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "effects.js" as Fx

Rectangle {
    id: panel

    property string zoneId: "global"
    property real t: -1
    signal pickZone(string zone)
    signal saveRequested()

    readonly property var zone: {
        for (const z of backend.zones)
            if (z.id === zoneId)
                return z
        return backend.zones.length ? backend.zones[0] : undefined
    }
    readonly property var mode: {
        if (zone)
            for (const m of backend.modes)
                if (m.id === zone.mode)
                    return m
        return undefined
    }
    readonly property bool whole: zone !== undefined && zone.id === "global"
    readonly property bool lit: zone !== undefined && zone.mode !== "off"
    readonly property var areas: backend.zones.filter(z => z.id !== "global" && z.id !== "dimm")

    function differs(key) {
        return zone !== undefined && zone.mixed.indexOf(key) >= 0
    }
    function set(changes) {
        backend.setZone(zone.id, changes)
    }

    color: Theme.surface
    radius: Theme.radius
    border.color: Theme.line

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 1
        contentHeight: body.implicitHeight + 44
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            x: 22
            y: 22
            width: flick.width - 44
            spacing: 14
            enabled: panel.zone !== undefined

            // --- zone -----------------------------------------------------------------
            SectionTitle { text: "Zone" }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: backend.zones
                    Chip {
                        id: chip
                        required property var modelData
                        text: modelData.label
                        selected: panel.zone !== undefined && panel.zone.id === modelData.id
                        onClicked: panel.pickZone(modelData.id)
                        lead: Component {
                            Row {
                                spacing: -3
                                Repeater {
                                    model: chip.modelData.id === "global" && chip.modelData.mixed.length ? panel.areas : [chip.modelData]
                                    ColorDot {
                                        required property var modelData
                                        look: modelData
                                        size: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                text: !panel.zone ? ""
                      : panel.whole ? (backend.synced
                            ? "One effect runs across the whole case."
                            : "Each zone has its own settings. A change here applies to all of them, and once they all match, one effect runs across the whole case.")
                      : panel.zone.alias ? "Driver zone " + panel.zone.id + ", or " + panel.zone.alias + " in orionctl."
                      : "Driver zone " + panel.zone.id + "."
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 4; Layout.bottomMargin: 4 }

            // --- effect ---------------------------------------------------------------
            SectionTitle {
                text: "Effect"
                note: panel.differs("mode") ? "differs per zone" : ""
            }
            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: Math.max(3, Math.floor((width + 8) / 70))
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: panel.zone ? backend.modes.filter(m => panel.zone.modes.indexOf(m.id) >= 0) : []
                    EffectTile {
                        required property var modelData
                        Layout.fillWidth: true
                        mode: modelData
                        zone: panel.zone
                        t: Math.floor(panel.t * 30) / 30
                        selected: !panel.differs("mode") && panel.zone.mode === modelData.id
                        onClicked: panel.set({ mode: modelData.id })
                    }
                }
            }
            Label {
                visible: panel.lit && panel.mode !== undefined && !panel.mode.color && !panel.differs("mode")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: panel.mode ? panel.mode.name + " brings its own colours." : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
            Label {
                visible: !panel.lit
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: panel.whole ? "The lights are off. Pick an effect to turn them on." : "This zone is off. Pick an effect to light it."
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            // --- colour ---------------------------------------------------------------
            ColumnLayout {
                visible: panel.lit && panel.mode !== undefined && (panel.mode.color || panel.differs("mode"))
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 12

                SectionTitle {
                    text: "Colour"
                    note: panel.differs("color") ? "differs per zone" : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    ColorWheel {
                        Layout.preferredWidth: 148
                        Layout.preferredHeight: 148
                        Layout.alignment: Qt.AlignTop
                        value: panel.zone && panel.zone.color !== "random" ? "#" + panel.zone.color : "white"
                        marker: panel.zone !== undefined && panel.zone.color !== "random" && !panel.differs("color")
                        onPicked: c => panel.set({ color: c.toString().slice(1, 7) })
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.radiusSmall
                            color: Theme.surface2
                            border.color: hex.activeFocus ? Theme.accent : Theme.line

                            ColorDot {
                                id: current
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                size: 18
                                look: panel.differs("color") ? undefined : panel.zone
                                visible: !panel.differs("color")
                            }
                            Label {
                                x: 36
                                anchors.verticalCenter: parent.verticalCenter
                                text: "#"
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontBody
                            }
                            TextField {
                                id: hex
                                x: 44
                                width: parent.width - 50
                                anchors.verticalCenter: parent.verticalCenter
                                background: null
                                color: Theme.text
                                placeholderText: panel.differs("color") ? "differs per zone"
                                                 : panel.zone && panel.zone.color === "random" ? "random" : "rrggbb"
                                placeholderTextColor: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontBody
                                selectByMouse: true
                                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                                onEditingFinished: {
                                    const v = text.replace("#", "")
                                    if (v.length === 6 && panel.zone && v.toLowerCase() !== panel.zone.color)
                                        panel.set({ color: v.toLowerCase() })
                                }
                                Binding on text {
                                    when: !hex.activeFocus
                                    value: panel.zone && panel.zone.color !== "random" && !panel.differs("color") ? panel.zone.color : ""
                                    restoreMode: Binding.RestoreNone
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: backend.swatches
                                Rectangle {
                                    required property string modelData
                                    readonly property bool on: panel.zone !== undefined && panel.zone.color === modelData && !panel.differs("color")
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: "#" + modelData
                                    border.width: on ? 2 : 1
                                    border.color: on ? "white" : Qt.rgba(1, 1, 1, 0.15)
                                    scale: swatchArea.containsMouse ? 1.12 : 1
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    MouseArea {
                                        id: swatchArea
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.set({ color: parent.modelData })
                                    }
                                }
                            }
                        }

                        Toggle {
                            visible: panel.whole && panel.mode !== undefined && panel.mode.random && !panel.differs("mode")
                            text: "Random colours"
                            checked: panel.zone !== undefined && panel.zone.color === "random"
                            onToggled: panel.set({ color: checked ? "random" : backend.lastColor })
                        }
                    }
                }
            }

            // --- motion and brightness ------------------------------------------------------
            ValueSlider {
                visible: panel.lit
                Layout.fillWidth: true
                Layout.topMargin: 6
                label: "Brightness"
                unit: "%"
                to: 100
                value: panel.zone ? panel.zone.brightness : 0
                note: panel.differs("brightness") ? "differs per zone" : ""
                onMoved: v => panel.set({ brightness: v })
            }
            ValueSlider {
                visible: panel.lit && panel.mode !== undefined && panel.mode.speed
                Layout.fillWidth: true
                label: "Speed"
                to: 9
                value: panel.zone ? panel.zone.speed : 0
                note: panel.differs("speed") ? "differs per zone" : ""
                lowText: "Slow"
                highText: "Fast"
                onMoved: v => panel.set({ speed: v })
            }
            ValueSlider {
                visible: panel.lit && panel.mode !== undefined && panel.mode.duration
                Layout.fillWidth: true
                label: "Duration"
                to: 9
                value: panel.zone ? panel.zone.duration : 0
                note: panel.differs("duration") ? "differs per zone" : ""
                info: "The firmware takes a duration from 0 to 9, and PredatorSense uses 3. What it changes has not been measured for every effect yet; the preview shows it as a pause between cycles."
                onMoved: v => panel.set({ duration: v })
            }
            ColumnLayout {
                visible: panel.lit && panel.mode !== undefined && panel.mode.direction
                Layout.fillWidth: true
                spacing: 8
                SectionTitle {
                    text: "Direction"
                    note: panel.differs("direction") ? "differs per zone" : ""
                }
                Segmented {
                    Layout.fillWidth: true
                    value: panel.zone ? panel.zone.direction : 0
                    options: [{ text: "Left", icon: "left", value: 0 }, { text: "Right", icon: "right", value: 1 }]
                    onActivated: v => panel.set({ direction: v })
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 8 }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10
                ActionButton {
                    text: "Identify"
                    iconName: "spark"
                    enabled: backend.writable && backend.identifying === ""
                    onClicked: backend.identify(panel.whole ? "all" : panel.zone.id)
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: panel.whole ? "Flash every zone white, one after the other, to see which is which."
                                              : "Flash this zone white for a moment so you can spot it on the case."
                }
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: "Save as style"
                    iconName: "save"
                    primary: true
                    onClicked: panel.saveRequested()
                }
            }
        }
    }
}
