// SPDX-License-Identifier: GPL-2.0-or-later
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: win

    width: 1480
    height: 920
    minimumWidth: 1120
    minimumHeight: 720
    visible: true
    title: "Orion Unchained"
    color: Theme.bg
    font.pixelSize: Theme.fontBody

    palette.window: Theme.bg
    palette.windowText: Theme.text
    palette.base: Theme.surface2
    palette.alternateBase: Theme.surface3
    palette.text: Theme.text
    palette.button: Theme.surface2
    palette.buttonText: Theme.text
    palette.brightText: Theme.text
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.accentText
    palette.placeholderText: Theme.textMuted
    palette.toolTipBase: Theme.surface3
    palette.toolTipText: Theme.text
    palette.light: Theme.surface3
    palette.midlight: Theme.surface3
    palette.mid: Theme.lineStrong
    palette.dark: Theme.lineStrong
    palette.shadow: "#000000"

    property int page: 0
    property string zoneId: "global"
    property real clock: 0

    // One clock for every animation; it stops while the window is minimised.
    FrameAnimation {
        running: win.visible && win.visibility !== Window.Minimized
        onTriggered: win.clock += frameTime
    }

    Settings {
        id: settings
        property alias width: win.width
        property alias height: win.height
        property string author: ""
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 88
            color: Theme.sidebar

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.line
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 18
                anchors.bottomMargin: 14
                spacing: 6

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 16
                    source: "../icons/orion-unchained.svg"
                    sourceSize: Qt.size(46, 46)
                }
                NavButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Lighting"
                    iconName: "fan"
                    current: win.page === 0
                    onClicked: win.page = 0
                }
                NavButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Styles"
                    iconName: "styles"
                    current: win.page === 1
                    onClicked: win.page = 1
                }
                NavButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Device"
                    iconName: "chip"
                    current: win.page === 2
                    attention: backend.checks.some(c => !c.ok) || backend.deviceState === "readonly" || backend.deviceState === "missing"
                    onClicked: win.page = 2
                }
                NavButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "About"
                    iconName: "info"
                    current: win.page === 3
                    onClicked: win.page = 3
                }
                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent
                    opacity: backend.busy ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    ToolTip.visible: busyHover.hovered && backend.busy
                    ToolTip.text: "Sending changes to the firmware"
                    HoverHandler { id: busyHover }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: backend.appVersion
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.page

            LightingPage {
                zoneId: win.zoneId
                t: visible ? win.clock : -1
                onPickZone: zone => win.zoneId = zone
                onSaveRequested: saveDialog.open()
                onShowDevice: win.page = 2
            }
            StylesPage {
                id: stylesPage
                clock: visible ? win.clock : 0
            }
            DevicePage {}
            AboutPage {}
        }
    }

    SaveStyleDialog {
        id: saveDialog
        author: settings.author || backend.userName
        onAuthorUsed: name => settings.author = name
    }

    Toast {}

    Shortcut { sequence: "Ctrl+1"; onActivated: win.page = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.page = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.page = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: win.page = 3 }
    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            win.page = 1
            stylesPage.focusSearch()
        }
    }
    Shortcut { sequences: [StandardKey.Save]; onActivated: saveDialog.open() }
    Shortcut { sequences: [StandardKey.Quit]; onActivated: Qt.quit() }
}
