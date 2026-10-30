import QtQuick
import Quickshell

Item {
    id: root
    required property var service
    readonly property int count: service.workspaceIds.length
    readonly property int selectedIndex: Math.max(0, service.workspaceIds.indexOf(service.selectedWorkspace))
    property real phase: selectedIndex
    property bool dragging: false
    property real wheelDelta: 0
    property real cameraElevation: 22
    property real cameraYaw: 0
    property real cameraZoom: 1
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragStartElevation: 22
    property real dragStartYaw: 0
    function beginCameraDrag(x, y) {
        if (service.windowDragAddress || service.workspaceReordering || service.windowMoveBusy) return
        dragStartX = x; dragStartY = y
        dragStartElevation = cameraElevation; dragStartYaw = cameraYaw
        dragging = true
    }
    function moveCamera(x, y) {
        if (!dragging) return
        cameraYaw = dragStartYaw - (x - dragStartX) * 0.22
        cameraElevation = Math.max(12, Math.min(36, dragStartElevation - (y - dragStartY) * 0.12))
    }
    function zoomCamera(delta) { cameraZoom = Math.max(1, Math.min(2, cameraZoom + delta)) }
    function resetCamera() { dragging = false; cameraElevation = 22; cameraYaw = 0; cameraZoom = 1 }
    function snapToSelection() {
        if (!count) return
        var current = ((phase % count) + count) % count
        var delta = selectedIndex - current
        if (delta > count / 2) delta -= count
        if (delta < -count / 2) delta += count
        phase += delta
    }
    Connections { target: root.service; function onSelectedWorkspaceChanged() { root.cameraYaw = 0; root.snapToSelection() } }
    Behavior on phase { enabled: !root.dragging; NumberAnimation { duration: root.service.motionDuration(330); easing.type: Easing.OutCubic } }
    opacity: 0
    Component.onCompleted: { phase = selectedIndex; opacity = 1 }
    Behavior on opacity { NumberAnimation { duration: root.service.motionDuration(160) } }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: function(mouse) { root.beginCameraDrag(mouse.x, mouse.y) }
        onPositionChanged: function(mouse) { if (pressed) root.moveCamera(mouse.x, mouse.y) }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
        onDoubleClicked: root.resetCamera()
    }
    WheelHandler {
        enabled: !root.service.windowDragAddress && !root.dragging
        onWheel: event => {
            if (event.modifiers & Qt.ControlModifier) {
                root.zoomCamera(event.angleDelta.y * 0.0009)
                event.accepted = true
                return
            }
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
        // One camera projects every point on the same horizontal world circle.
        // Independent item rotations otherwise give each card a different
        // vanishing point and flatten the ring into a crowded strip.
        readonly property real radius: Math.min(width * 0.30, height * 0.57) * root.cameraZoom
        readonly property real cameraPitch: root.cameraElevation * Math.PI / 180
        readonly property real cameraDistance: radius * 5.5
        readonly property real cardWidth: Math.min(310, radius * 0.78,
            2 * radius * Math.sin(Math.PI / Math.max(3, root.count)) * 0.78) * root.service.previewScale
        function cardMatrix(theta, cardWidth, cardHeight) {
            var s = Math.sin(theta), c = Math.cos(theta)
            // Keep the outward direction while opening up side cards enough
            // to remain readable rather than disappearing edge-on.
            var yaw = Math.atan2(s * 0.55, c)
            var sy = Math.sin(yaw), cy = Math.cos(yaw)
            var cp = Math.cos(cameraPitch), sp = Math.sin(cameraPitch)
            var centerX = width / 2, centerY = height / 2
            // Local card coordinates become upright, radially oriented world
            // planes, then share the camera's perspective divide.
            var wx = cp * sy / cameraDistance, wy = sp / cameraDistance
            var wc = 1 - cp * radius * c / cameraDistance - wx * cardWidth / 2 - wy * cardHeight / 2
            return Qt.matrix4x4(
                centerX * wx + cy, centerX * wy, 0, centerX * wc + radius * s - cy * cardWidth / 2,
                centerY * wx - sp * sy, centerY * wy + cp, 0, centerY * wc + sp * radius * c + sp * sy * cardWidth / 2 - cp * cardHeight / 2,
                0, 0, 1, 0,
                wx, wy, 0, wc)
        }
        Repeater {
            model: root.service.workspaceIds
            Item {
                id: card
                required property int modelData
                required property int index
                objectName: "orbit-workspace-" + modelData
                readonly property real theta: (index - root.phase) * Math.PI * 2 / Math.max(1, root.count) - root.cameraYaw * Math.PI / 180
                readonly property real depth: (Math.cos(theta) + 1) / 2
                readonly property bool selected: root.service.selectedWorkspace === modelData
                width: stage.cardWidth
                height: width * root.service.monitorHeight / root.service.monitorWidth
                opacity: 0.65 + depth * 0.35
                z: depth * 1000 + index * 0.01
                // Render each workspace once at 2x resolution, then filter its
                // transformed surface. The texture is bounded for older GPUs.
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.samples: 4
                layer.textureSize: Qt.size(Math.min(1280, Math.ceil(width * 2)), Math.min(720, Math.ceil(height * 2)))
                transform: Matrix4x4 { matrix: stage.cardMatrix(card.theta, card.width, card.height) }
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
    // Right-drag also works over a workspace, leaving left-click activation
    // and left-drag window moves available on the actual previews.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: function(mouse) { root.beginCameraDrag(mouse.x, mouse.y) }
        onPositionChanged: function(mouse) { if (pressed) root.moveCamera(mouse.x, mouse.y) }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }
}
