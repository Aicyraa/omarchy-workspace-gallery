import QtQuick
import Quickshell

Item {
    id: root
    required property var service
    readonly property int count: service.workspaceIds.length
    readonly property int selectedIndex: Math.max(0, service.workspaceIds.indexOf(service.selectedWorkspace))
    property real phase: selectedIndex
    property real dragShift: 0
    property bool dragging: false
    property real wheelDelta: 0
    function snapToSelection() {
        if (!count) return
        var current = ((phase % count) + count) % count
        var delta = selectedIndex - current
        if (delta > count / 2) delta -= count
        if (delta < -count / 2) delta += count
        phase += delta
    }
    Connections { target: root.service; function onSelectedWorkspaceChanged() { root.snapToSelection() } }
    Behavior on phase { enabled: !root.dragging; NumberAnimation { duration: root.service.motionDuration(330); easing.type: Easing.OutCubic } }
    opacity: 0
    Component.onCompleted: { phase = selectedIndex; opacity = 1 }
    Behavior on opacity { NumberAnimation { duration: root.service.motionDuration(160) } }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        property real startX: 0
        property bool moved: false
        onPressed: function(mouse) { startX = mouse.x; moved = false; root.dragging = true }
        onPositionChanged: function(mouse) {
            if (!pressed) return
            if (Math.abs(mouse.x - startX) > 8) moved = true
            if (moved) root.dragShift = -(mouse.x - startX) / 210
        }
        onReleased: {
            var steps = Math.round(root.dragShift)
            root.phase += root.dragShift
            root.dragShift = 0; root.dragging = false
            if (steps) root.service.moveWorkspace(steps)
            else root.snapToSelection()
        }
        onCanceled: { root.dragShift = 0; root.dragging = false; root.snapToSelection() }
        onClicked: if (!moved) root.service.dismiss()
    }
    WheelHandler {
        enabled: !root.service.windowDragAddress
        onWheel: event => {
            root.wheelDelta += event.angleDelta.y || event.angleDelta.x
            if (Math.abs(root.wheelDelta) >= 90) {
                root.service.moveWorkspace(root.wheelDelta > 0 ? -1 : 1)
                root.wheelDelta = 0
            }
            event.accepted = true
        }
    }
    Item {
        id: stage
        anchors.fill: parent
        transform: Rotation {
            origin.x: stage.width / 2; origin.y: stage.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.service.reducedMotion ? 0 : 14
        }
        readonly property real cardWidth: Math.min(400, width * 0.30, height * root.service.monitorWidth / root.service.monitorHeight * 0.64) * root.service.previewScale
        readonly property real radius: Math.min(width * 0.30, (width - cardWidth * 0.55) / 2 - 24)
        Repeater {
            model: root.service.workspaceIds
            Item {
                id: card
                required property int modelData
                required property int index
                readonly property real theta: (index - root.phase - root.dragShift) * Math.PI * 2 / Math.max(1, root.count)
                readonly property real depth: (Math.cos(theta) + 1) / 2
                readonly property bool selected: root.service.selectedWorkspace === modelData
                width: stage.cardWidth
                height: width * root.service.monitorHeight / root.service.monitorWidth
                x: (stage.width - width) / 2 + Math.sin(theta) * stage.radius
                y: (stage.height - height) / 2 + (depth - 0.5) * 180
                scale: 0.72 + depth * 0.28
                opacity: 0.38 + depth * 0.62
                z: depth * 1000 + index * 0.01
                // Render each workspace once at 2x resolution, then filter its
                // transformed surface. The texture is bounded for older GPUs.
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.samples: 4
                layer.textureSize: Qt.size(Math.min(1280, Math.ceil(width * 2)), Math.min(720, Math.ceil(height * 2)))
                transform: Rotation {
                    origin.x: card.width / 2; origin.y: card.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    // Each workspace faces radially out from the ring center.
                    // Rear workspaces show their reverse side rather than facing the camera.
                    angle: root.service.reducedMotion ? 0 : -card.theta * 180 / Math.PI
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.enterWorkspace(card.modelData, "")
                }
                // Window previews remain independently clickable above the workspace.
                WorkspaceScene {
                    anchors.fill: parent
                    service: root.service; workspaceId: card.modelData
                    miniature: !card.selected
                }
                MouseArea {
                    anchors.fill: parent; enabled: !card.selected
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.enterWorkspace(card.modelData, "")
                }
            }
        }
    }
}
