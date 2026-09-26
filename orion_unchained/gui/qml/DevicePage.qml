// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page

    readonly property var areas: backend.zones.filter(z => z.id !== "global")
    readonly property string access: {
        switch (backend.deviceState) {
        case "live": return "This account can change the lights."
        case "readonly": return "Read only: this account can't write to the lighting controls yet."
        case "demo": return "Demo mode: a simulated PO7-660, nothing reaches the hardware."
        default: return "No lighting device found."
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: column
            x: 20
            y: 20
            width: flick.width - 40
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "Device"
                        color: Theme.text
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "What Orion Unchained sees on this machine, and whether everything is set up."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: "Check again"
                    iconName: "refresh"
                    onClicked: backend.refresh()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 900 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "This machine"
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 10
                        Repeater {
                            model: [
                                ["Model", backend.model || "unknown"],
                                ["Driver", backend.driverVersion ? "acer_predator_dt_rgb " + backend.driverVersion : "not loaded"],
                                ["SMBIOS 172", backend.smbiosVersion ? "version " + backend.smbiosVersion : "unknown"],
                                ["Zones", page.areas.map(z => z.id + (z.alias ? " (" + z.alias + ")" : "")).join(", ")],
                                ["Access", page.access],
                                ["App", "Orion Unchained " + backend.appVersion]
                            ]
                            Item {
                                required property var modelData
                                required property int index
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                implicitHeight: Math.max(key.implicitHeight, val.implicitHeight)
                                Label {
                                    id: key
                                    width: 110
                                    text: parent.modelData[0]
                                    color: Theme.textMuted
                                }
                                Label {
                                    id: val
                                    x: 120
                                    width: parent.width - 120
                                    text: parent.modelData[1]
                                    color: Theme.text
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Installation"
                    subtitle: backend.checks.length === 0 ? "Checking\u2026" : backend.checks.every(c => c.ok) ? "Everything is in place." : "Some parts need attention."
                    Repeater {
                        model: backend.checks
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                width: 22; height: 22; radius: 11
                                color: Theme.alpha(parent.modelData.ok ? Theme.good : Theme.warn, 0.15)
                                Icon {
                                    anchors.centerIn: parent
                                    name: parent.parent.modelData.ok ? "check" : "alert"
                                    size: 14
                                    stroke: 2.2
                                    color: parent.parent.modelData.ok ? Theme.good : Theme.warn
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label {
                                    Layout.fillWidth: true
                                    text: parent.parent.modelData.text
                                    color: Theme.text
                                    wrapMode: Text.Wrap
                                }
                                TextEdit {
                                    readonly property bool command: /^(sudo|orionctl) /.test(text)
                                    visible: !parent.parent.modelData.ok && parent.parent.modelData.hint !== ""
                                    Layout.fillWidth: true
                                    text: parent.parent.modelData.hint
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: Text.Wrap
                                    color: command ? Theme.accent : Theme.textDim
                                    selectionColor: Theme.accentDim
                                    font.family: command ? Theme.mono : Qt.application.font.family
                                    font.pixelSize: Theme.fontSmall
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Which zone is which"
                    subtitle: "The zone names come from PredatorSense's layout tables and have not all been checked by eye. Flash each zone and see whether the right part of the case lights up. If a name is wrong, a model report lets it be corrected for everyone."
                    Repeater {
                        model: page.areas
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12
                            ColorDot { look: parent.modelData; size: 12 }
                            Label {
                                text: parent.modelData.label
                                color: Theme.text
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: parent.modelData.id
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontSmall
                            }
                            ActionButton {
                                text: backend.identifying === parent.modelData.id ? "Flashing" : "Flash"
                                iconName: "spark"
                                enabled: backend.writable && backend.identifying === ""
                                onClicked: backend.identify(parent.modelData.id)
                            }
                        }
                    }
                    RowLayout {
                        Layout.topMargin: 6
                        spacing: 10
                        ActionButton {
                            text: "Flash them in turn"
                            iconName: "spark"
                            primary: true
                            enabled: backend.writable && backend.identifying === ""
                            onClicked: backend.identify("all")
                        }
                        ActionButton {
                            text: "Send a model report"
                            iconName: "share"
                            onClicked: backend.openUrl(backend.projectUrl + "/issues/new?template=model-report.yml")
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Not supported yet"
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.textDim
                        text: "PredatorSense drives the graphics card's lighting over the card's I2C bus, which also reaches its power controllers. That needs the same careful study the case lighting got before anything is sent there."
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.textDim
                        text: "The driver can offer memory lighting with enable_dimm=1, but nobody has tried it on RGB memory yet."
                    }
                    ActionButton {
                        text: "Read the safety notes"
                        iconName: "book"
                        onClicked: backend.openUrl(backend.projectUrl + "/blob/main/docs/SAFETY.md")
                    }
                }
            }
        }
    }
}
