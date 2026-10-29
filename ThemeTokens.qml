pragma Singleton
import QtQuick
import qs.Commons as Commons

QtObject {
    readonly property color background: Commons.Color.background
    readonly property color text: Commons.Color.foreground
    readonly property color accent: Commons.Color.accent
    readonly property color danger: Commons.Color.urgent
    function blend(color, amount) { return Qt.tint(background, Qt.rgba(color.r, color.g, color.b, amount)) }
    function alpha(color, amount) { return Qt.rgba(color.r, color.g, color.b, amount) }
    readonly property color surface: blend(text, 0.045)
    readonly property color raised: blend(text, 0.075)
    readonly property color hover: blend(text, 0.105)
    readonly property color selected: blend(accent, 0.16)
    readonly property color selectedHover: blend(accent, 0.23)
    readonly property color secondary: blend(text, 0.66)
    readonly property color subdued: blend(text, 0.43)
    readonly property color border: blend(text, 0.22)
    readonly property color track: blend(text, 0.15)
    readonly property color sidebar: blend(text, 0.015)
    readonly property color panel: alpha(background, 0.97)
    readonly property color scrim: alpha(background, 0.42)
    readonly property color overviewScrim: alpha(background, 0.92)
    readonly property color preview: alpha(background, 0.85)
    readonly property color caption: alpha(background, 0.90)
    readonly property color heroStart: alpha(background, 0.96)
    readonly property color heroEnd: alpha(background, 0.36)
    readonly property color badge: alpha(background, 0.72)
    readonly property color onAccent: background
}
