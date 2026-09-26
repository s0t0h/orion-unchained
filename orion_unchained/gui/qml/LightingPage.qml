// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: page

    property string zoneId: "global"
    property real t: -1
    signal pickZone(string zone)
    signal saveRequested()
    signal showDevice()

    readonly property var zoneMap: {
        const map = {}
        for (const z of backend.zones)
            map[z.id] = z
        return map
    }
    readonly property int areaCount: backend.zones.filter(z => z.id !== "global").length
    readonly property string styleName: {
        for (const s of backend.styles)
            if (s.id === backend.currentStyle)
                return s.name
        return ""
    }
    readonly property string details: {
        const parts = []
        if (backend.deviceState === "demo")
            parts.push("Simulated machine")
        if (backend.driverVersion)
            parts.push("Driver " + backend.driverVersion)
        if (backend.smbiosVersion)
            parts.push("SMBIOS 172 v" + backend.smbiosVersion)
        parts.push(areaCount + (areaCount === 1 ? " lighting zone" : " lighting zones"))
        return parts.join("   ·   ")
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: backend.model || "Unknown model"
                        color: Theme.text
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: page.details
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: page.styleName !== ""
                    implicitWidth: styleRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    color: Theme.surface2
                    border.color: Theme.line
                    Row {
                        id: styleRow
                        anchors.centerIn: parent
                        spacing: 7
                        Icon { name: "styles"; size: 16; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: page.styleName; color: Theme.text; font.pixelSize: Theme.fontSmall; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    HoverHandler { id: styleHover }
                    ToolTip.visible: styleHover.hovered
                    ToolTip.delay: 400
                    ToolTip.text: "The case shows this style from your library."
                }
                Rectangle {
                    visible: backend.synced && backend.lightsOn
                    implicitWidth: syncRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    color: Theme.alpha(Theme.violet, 0.12)
                    border.color: Theme.alpha(Theme.violet, 0.45)
                    Row {
                        id: syncRow
                        anchors.centerIn: parent
                        spacing: 7
                        Icon { name: "link"; size: 16; color: "#c4a8ff"; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "In sync across the case"; color: "#d9c9ff"; font.pixelSize: Theme.fontSmall; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    HoverHandler { id: syncHover }
                    ToolTip.visible: syncHover.hovered
                    ToolTip.delay: 400
                    ToolTip.text: "The whole case was set in one go, so the firmware runs one effect over every zone."
                }
                AbstractButton {
                    id: power
                    implicitWidth: powerRow.implicitWidth + 28
                    implicitHeight: 36
                    contentItem: Item {
                        Row {
                            id: powerRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon {
                                name: "power"
                                size: 17
                                color: backend.lightsOn ? Theme.accentText : Theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: backend.lightsOn ? "Lights on" : "Lights off"
                                color: backend.lightsOn ? Theme.accentText : Theme.textDim
                                font.pixelSize: Theme.fontBody
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    background: Rectangle {
                        radius: 18
                        color: backend.lightsOn ? (power.hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
                                                : (power.hovered ? Theme.surface3 : Theme.surface2)
                        border.color: backend.lightsOn ? "transparent" : Theme.line
                    }
                    onClicked: backend.lightsOn ? backend.turnOff() : backend.turnOn()
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: backend.lightsOn ? "Turn every zone off. The current look comes back when you turn them on."
                                                   : "Bring back the look from before the lights went off."
                }
            }

            Banner {
                Layout.fillWidth: true
                visible: backend.deviceState !== "live"
                iconName: backend.deviceState === "readonly" ? "lock" : backend.deviceState === "demo" ? "eye" : "alert"
                tint: backend.deviceState === "demo" ? Theme.violet : Theme.warn
                text: backend.deviceState === "demo"
                      ? "Demo mode. This is a simulated PO7-660, and nothing is sent to the hardware."
                      : backend.deviceState === "readonly"
                        ? "This account can't change the lights yet, so changes stay in this window. The Device page shows how to fix that."
                        : "The lighting driver isn't loaded, so this is a preview only. The Device page shows what's missing."
                actionText: backend.deviceState === "demo" ? "" : "Open Device"
                onAction: page.showDevice()
            }

            Rectangle {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.line
                clip: true

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: stage.width / 2; centerY: stage.height * 0.45
                            centerRadius: Math.max(stage.width, stage.height) * 0.6
                            focalX: centerX; focalY: centerY
                            GradientStop { position: 0; color: "#151a23" }
                            GradientStop { position: 1; color: Theme.surface }
                        }
                        startX: 1; startY: 1
                        PathLine { x: stage.width - 1; y: 1 }
                        PathLine { x: stage.width - 1; y: stage.height - 1 }
                        PathLine { x: 1; y: stage.height - 1 }
                        PathLine { x: 1; y: 1 }
                    }
                }

                Loader {
                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.bottomMargin: 36
                    sourceComponent: backend.layout === "po7-660" ? caseView : genericView
                }
                Component {
                    id: caseView
                    CaseView {
                        zones: page.zoneMap
                        synced: backend.synced
                        t: page.t
                        selected: page.zoneId
                        identifying: backend.identifying
                        identifyLook: backend.identifyLook
                        onPicked: zone => page.pickZone(zone)
                    }
                }
                Component {
                    id: genericView
                    GenericCaseView {
                        zones: page.zoneMap
                        synced: backend.synced
                        t: page.t
                        selected: page.zoneId
                        identifying: backend.identifying
                        identifyLook: backend.identifyLook
                        onPicked: zone => page.pickZone(zone)
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    spacing: 8
                    Icon { name: "info"; size: 15; stroke: 1.6; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        text: "Click a part of the case to change it. The animations imitate the firmware's effects and may not match them exactly."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    visible: backend.identifying !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    spacing: 8
                    Icon { name: "spark"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        text: "Flashing " + (page.zoneMap[backend.identifying] ? page.zoneMap[backend.identifying].label : "") + " white"
                        color: Theme.text
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        ControlPanel {
            Layout.preferredWidth: 410
            Layout.fillHeight: true
            zoneId: page.zoneId
            t: page.t
            onPickZone: zone => page.pickZone(zone)
            onSaveRequested: page.saveRequested()
        }
    }
}
