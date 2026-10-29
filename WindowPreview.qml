import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: root
    required property var windowHandle
    required property var service
    property bool selected: false
    property bool miniature: false
    signal activated()
    property bool readyCounted: false
    Component.onCompleted: service.captureViews++
    Component.onDestruction: { service.captureViews--; if (readyCounted) service.readyCaptures-- }
    color: ThemeTokens.preview
    radius: 0
    border.width: 0
    border.color: selected || mouse.containsMouse ? ThemeTokens.accent : ThemeTokens.border
    clip: false
    RectangularShadow {
        anchors.fill: parent
        z: -1
        radius: 0
        blur: root.selected || mouse.containsMouse ? 18 : 12
        offset: Qt.vector2d(0, root.selected ? 7 : 4)
        color: Qt.rgba(0, 0, 0, root.selected ? 0.65 : 0.45)
    }
    ScreencopyView {
        id: capture
        smooth: true
        antialiasing: true
        anchors.fill: parent
        captureSource: root.service.opened && root.windowHandle ? root.windowHandle.wayland : null
        live: root.service.opened && !root.miniature
        paintCursor: false
        onHasContentChanged: {
            if (hasContent !== root.readyCounted) {
                root.service.readyCaptures += hasContent ? 1 : -1
                root.readyCounted = hasContent
            }
        }
    }
    Column {
        anchors.centerIn: parent; spacing: 8
        visible: !capture.hasContent
        Image { anchors.horizontalCenter: parent.horizontalCenter; width: root.miniature ? 20 : 48; height: width; source: root.service.icon(root.service.entryFor(root.windowHandle)) }
        Text { visible: !root.miniature; width: Math.max(30, root.width - 24); text: root.windowHandle ? root.windowHandle.title : "Window closed"; color: ThemeTokens.text; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
        Text { visible: !root.miniature; text: "Preview unavailable"; color: ThemeTokens.secondary; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 11 }
    }
    Rectangle {
        visible: !root.miniature && (root.selected || mouse.containsMouse || !capture.hasContent)
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 0 }
        height: 30; color: ThemeTokens.caption; radius: 0
        Image { id: appIcon; x: 7; anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; source: root.service.icon(root.service.entryFor(root.windowHandle)) }
        Text { anchors { left: appIcon.right; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 } text: root.windowHandle ? root.windowHandle.title : ""; color: ThemeTokens.text; elide: Text.ElideRight; font.pixelSize: 12 }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        cursorShape: root.service.windowDragAddress ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: function(event) {
            var point = mapToItem(null, event.x, event.y)
            pressX = point.x; pressY = point.y; dragged = false
        }
        onPositionChanged: function(event) {
            if (!pressed || root.miniature) return
            var point = mapToItem(null, event.x, event.y)
            if (!dragged && Math.hypot(point.x - pressX, point.y - pressY) > 9)
                dragged = root.service.beginWindowDrag(root.windowHandle, point.x, point.y)
            if (dragged) { root.service.windowDragX = point.x; root.service.windowDragY = point.y }
        }
        onReleased: if (dragged) root.service.finishWindowDrag(false)
        onCanceled: root.service.finishWindowDrag(true)
        onClicked: if (!dragged) root.activated()
    }
}
