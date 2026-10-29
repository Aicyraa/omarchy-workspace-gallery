// UI tests replace compositor capture only; production pointer/drag code is used unchanged.
import QtQuick
Item {
    property var captureSource: null
    property bool live: false
    property bool paintCursor: false
    readonly property bool hasContent: false
}
