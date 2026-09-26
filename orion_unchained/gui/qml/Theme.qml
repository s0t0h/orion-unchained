// SPDX-License-Identifier: GPL-2.0-or-later
pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#0a0c10"
    readonly property color sidebar: "#0d1015"
    readonly property color surface: "#11151c"
    readonly property color surface2: "#161b23"
    readonly property color surface3: "#1c222c"
    readonly property color line: "#1f2631"
    readonly property color lineStrong: "#2c3542"
    readonly property color text: "#e8ecf2"
    readonly property color textDim: "#a1abbb"
    readonly property color textMuted: "#687385"
    readonly property color accent: "#34d6e6"
    readonly property color accentDim: "#1d7f8a"
    readonly property color accentText: "#04181b"
    readonly property color violet: "#9d6bff"
    readonly property color good: "#43d17f"
    readonly property color warn: "#f1b544"
    readonly property color bad: "#ff5d6c"

    // Case drawing
    readonly property color metal: "#141922"
    readonly property color metalLight: "#1b212c"
    readonly property color metalEdge: "#2a3340"
    readonly property color cavity: "#0b0e13"
    readonly property color unlit: "#1a2029"

    readonly property int radius: 16
    readonly property int radiusSmall: 10
    readonly property int fontTitle: 24
    readonly property int fontHeading: 16
    readonly property int fontBody: 13
    readonly property int fontSmall: 12
    readonly property int fontTiny: 11
    readonly property string mono: "monospace"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // "#rrggbb" for a zone colour; random and missing colours get a neutral grey.
    function zoneColor(hex) {
        return hex && hex !== "random" ? "#" + hex : "#8891a0"
    }
}
