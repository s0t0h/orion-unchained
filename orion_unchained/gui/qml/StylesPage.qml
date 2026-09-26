// SPDX-License-Identifier: GPL-2.0-or-later
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: page

    property real clock: 0
    property string query: ""
    property string tag: ""          // "" for every style, "yours" for your own
    property var target              // the style a menu or dialog is about

    readonly property int userCount: backend.styles.filter(s => s.user).length
    readonly property var shown: backend.styles.filter(s => matches(s))

    function matches(s) {
        if (tag === "yours" && !s.user)
            return false
        if (tag !== "" && tag !== "yours" && s.tags.map(x => x.toLowerCase()).indexOf(tag) < 0)
            return false
        const q = query.trim().toLowerCase()
        if (q === "")
            return true
        return s.name.toLowerCase().includes(q) || s.description.toLowerCase().includes(q)
            || s.author.toLowerCase().includes(q) || s.tags.some(x => x.toLowerCase().includes(q))
    }

    function focusSearch() {
        search.forceActiveFocus()
        search.selectAll()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                spacing: 2
                Label {
                    text: "Styles"
                    color: Theme.text
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                }
                Label {
                    text: backend.styles.length + " styles. Click one to put it on the case."
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
            }
            Item { Layout.fillWidth: true }
            SearchBox {
                id: search
                Layout.preferredWidth: 280
                placeholderText: "Search names, tags, authors"
                onTextChanged: page.query = text
            }
            ActionButton {
                text: "Import"
                iconName: "import"
                onClicked: importDialog.open()
            }
            IconButton {
                iconName: "folder"
                tip: "Open your styles folder"
                onClicked: backend.openStylesFolder()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Chip {
                text: "All"
                trailing: String(backend.styles.length)
                selected: page.tag === ""
                onClicked: page.tag = ""
            }
            Chip {
                visible: page.userCount > 0
                text: "Yours"
                trailing: String(page.userCount)
                selected: page.tag === "yours"
                onClicked: page.tag = "yours"
            }
            Repeater {
                model: backend.tags.slice(0, 18)
                Chip {
                    required property var modelData
                    text: modelData.name
                    trailing: String(modelData.count)
                    selected: page.tag === modelData.name
                    onClicked: page.tag = page.tag === modelData.name ? "" : modelData.name
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: -7
            Layout.rightMargin: -7
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property int columns: Math.max(1, Math.floor(width / 250))
            cellWidth: Math.floor(width / columns)
            cellHeight: 236
            cacheBuffer: 500
            model: page.shown
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: StyleCard {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                style: modelData
                clock: page.clock
                onApply: backend.applyStyle(modelData.id)
                onMenu: anchor => {
                    page.target = modelData
                    menu.popup(anchor, 0, anchor.height + 4)
                }
            }

            Label {
                anchors.centerIn: parent
                visible: page.shown.length === 0
                text: page.query !== "" ? "No style matches “" + page.query + "”." : "No styles here yet."
                color: Theme.textMuted
            }
        }
    }

    PopupMenu {
        id: menu
        MenuEntry {
            text: "Apply"
            iconName: "play"
            onTriggered: backend.applyStyle(page.target.id)
        }
        MenuEntry {
            text: "Copy as JSON"
            iconName: "copy"
            onTriggered: backend.copyStyle(page.target.id)
        }
        MenuEntry {
            text: "Export to a file"
            iconName: "export"
            onTriggered: {
                exportDialog.styleId = page.target.id
                exportDialog.selectedFile = StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/" + page.target.id + ".json"
                exportDialog.open()
            }
        }
        MenuEntry {
            text: "Share on GitHub"
            iconName: "share"
            onTriggered: backend.shareStyle(page.target.id)
        }
        MenuEntry {
            text: "Show the file"
            iconName: "folder"
            onTriggered: backend.showStyleFile(page.target.id)
        }
        MenuLine { visible: page.target !== undefined && page.target.user }
        MenuEntry {
            visible: page.target !== undefined && page.target.user
            height: visible ? implicitHeight : 0
            text: "Delete"
            iconName: "trash"
            danger: true
            onTriggered: confirmDelete.open()
        }
    }

    ConfirmDialog {
        id: confirmDelete
        title: "Delete " + (page.target ? page.target.name : "") + "?"
        text: "The file moves to the trash, so you can get it back from there."
        confirmText: "Delete"
        danger: true
        onConfirmed: backend.deleteStyle(page.target.id)
    }

    FileDialog {
        id: importDialog
        title: "Import a style"
        nameFilters: ["Style files (*.json)", "All files (*)"]
        onAccepted: backend.importStyle(selectedFile)
    }

    FileDialog {
        id: exportDialog
        property string styleId
        title: "Export a style"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: ["Style files (*.json)"]
        onAccepted: backend.exportStyle(styleId, selectedFile)
    }
}
