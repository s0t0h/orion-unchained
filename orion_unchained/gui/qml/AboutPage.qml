// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: column
            width: Math.min(680, flick.width - 80)
            x: (flick.width - width) / 2
            y: 48
            spacing: 18

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "../icons/orion-unchained.svg"
                sourceSize: Qt.size(112, 112)
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Orion Unchained"
                color: Theme.text
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Version " + backend.appVersion
                color: Theme.textMuted
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.text
                font.pixelSize: 15
                lineHeight: 1.15
                text: "Lighting control for Acer Predator Orion desktops on Linux."
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.textDim
                lineHeight: 1.2
                text: "Acer sells the Orion with a case full of RGB fans and a Windows app to drive them, and gives Linux users nothing. Orion Unchained is the Linux side of that: a kernel driver, orionctl on the command line, and this app. It was built by taking PredatorSense apart, and every byte it sends to the firmware is documented."
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.textDim
                lineHeight: 1.2
                text: "Changing the colour of a computer you own should not require a particular operating system. The app has no account, telemetry or ads, and styles are plain files you can share however you like."
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10
                ActionButton {
                    text: "Project page"
                    iconName: "share"
                    primary: true
                    onClicked: backend.openUrl(backend.projectUrl)
                }
                ActionButton {
                    text: "Documentation"
                    iconName: "book"
                    onClicked: backend.openUrl(backend.projectUrl + "/tree/main/docs")
                }
                ActionButton {
                    text: "Report a problem"
                    iconName: "chat"
                    onClicked: backend.openUrl(backend.projectUrl + "/issues/new/choose")
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; Layout.topMargin: 10 }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                lineHeight: 1.2
                text: "Free software under the GNU General Public License, version 2 or later. It contains no code or files from Acer. Acer, Predator, Predator Orion and PredatorSense are trademarks of Acer Inc. This project is not affiliated with or endorsed by Acer."
            }
        }
    }
}
