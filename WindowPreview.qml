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
    property string dragSourceAddress: ""
    // The close button arms only after the pointer has rested on the preview, so a
    // tap or a fast click near the corner can never close a window by accident.
    property bool closeReady: false
    readonly property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    onHoveredChanged: { if (hovered) closeArm.restart(); else { closeArm.stop(); closeReady = false } }
    Timer { id: closeArm; interval: 200; onTriggered: root.closeReady = root.hovered }
    Component.onCompleted: service.captureViews++
    Component.onDestruction: {
        if (service) {
            if (dragSourceAddress && service.windowDragAddress === dragSourceAddress) service.finishWindowDrag(true)
            service.captureViews--; if (readyCounted) service.readyCaptures--
        }
    }
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
        Text { visible: !root.miniature; width: Math.max(30, root.width - 24); text: root.windowHandle ? root.windowHandle.title : "Window closed"; textFormat: Text.PlainText; color: ThemeTokens.text; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
        Text { visible: !root.miniature; text: "Preview unavailable"; color: ThemeTokens.secondary; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 11 }
    }
    // A small app badge keeps windows recognisable while their caption is hidden.
    Rectangle {
        visible: !root.miniature && capture.hasContent && !captionBar.visible
        anchors { left: parent.left; bottom: parent.bottom; margins: 6 }
        width: 26; height: 26; radius: 7; color: ThemeTokens.badge
        Image { anchors.centerIn: parent; width: 18; height: 18; source: root.service.icon(root.service.entryFor(root.windowHandle)) }
    }
    Rectangle {
        id: captionBar
        visible: !root.miniature && (root.selected || mouse.containsMouse || closeMouse.containsMouse || !capture.hasContent)
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 0 }
        height: 30; color: ThemeTokens.caption; radius: 0
        Image { id: appIcon; x: 7; anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; source: root.service.icon(root.service.entryFor(root.windowHandle)) }
        Text { anchors { left: appIcon.right; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 } text: root.windowHandle ? root.windowHandle.title : ""; textFormat: Text.PlainText; color: ThemeTokens.text; elide: Text.ElideRight; font.pixelSize: 12 }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        cursorShape: root.service.windowDragAddress ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: function(event) {
            if (event.button !== Qt.LeftButton) return
            var point = mapToItem(null, event.x, event.y)
            pressX = point.x; pressY = point.y; dragged = false
        }
        onPositionChanged: function(event) {
            if (!pressed || !(pressedButtons & Qt.LeftButton)) return
            var point = mapToItem(null, event.x, event.y)
            if (!dragged && Math.hypot(point.x - pressX, point.y - pressY) > 9)
                dragged = root.service.beginWindowDrag(root.windowHandle, point.x, point.y)
            if (dragged) { root.dragSourceAddress = root.service.windowDragAddress; root.service.windowDragX = point.x; root.service.windowDragY = point.y }
        }
        onReleased: if (dragged) root.service.finishWindowDrag(false)
        onCanceled: root.service.finishWindowDrag(true)
        onClicked: function(event) {
            if (event.button === Qt.MiddleButton) { if (!root.miniature) root.service.closeWindow(root.windowHandle) }
            else if (!dragged) root.activated()
        }
    }
    // Asks the application to close. Hidden on miniatures and while a drag is running.
    Rectangle {
        visible: root.closeReady && !root.miniature && !root.service.windowDragAddress
        anchors { right: parent.right; top: parent.top; margins: 6 }
        width: 24; height: 24; radius: 12
        color: closeMouse.containsMouse ? ThemeTokens.danger : ThemeTokens.badge
        Text { anchors.centerIn: parent; text: "×"; color: closeMouse.containsMouse ? ThemeTokens.onAccent : ThemeTokens.text; font.pixelSize: 16 }
        MouseArea {
            id: closeMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.service.closeWindow(root.windowHandle)
            Accessible.role: Accessible.Button; Accessible.name: "Close window"
        }
    }
}
