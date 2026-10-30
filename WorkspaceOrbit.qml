import QtQuick
import QtQuick.Shapes
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
    PinchHandler {
        id: pinch
        target: null
        enabled: !root.dragging && !root.service.windowDragAddress
        property real startZoom: 1
        onActiveChanged: if (active) startZoom = root.cameraZoom
        onActiveScaleChanged: root.cameraZoom = Math.max(1, Math.min(2, startZoom * activeScale))
    }
    WheelHandler {
        enabled: !root.service.windowDragAddress && !root.dragging
        onWheel: event => {
            if (event.modifiers & Qt.ControlModifier) {
                // Touchpads send smooth pixel deltas; mice send notched angle deltas.
                const steps = event.pixelDelta.y !== 0 ? event.pixelDelta.y / 100 : event.angleDelta.y / 120
                root.zoomCamera(steps * 0.1)
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
        // One perspective camera looks at the ring centre from the +Z side.
        // Every workspace is a slab in that shared world, so the ring has one
        // vanishing point and each card reads as a physical object.
        readonly property real radius: Math.min(width * 0.30, height * 0.57) * root.cameraZoom
        readonly property real focal: radius * 5.5
        readonly property real cp: Math.cos(root.cameraElevation * Math.PI / 180)
        readonly property real sp: Math.sin(root.cameraElevation * Math.PI / 180)
        readonly property real cardWidth: Math.min(310, radius * 0.78,
            2 * radius * Math.sin(Math.PI / Math.max(3, root.count)) * 0.78) * root.service.previewScale
        readonly property real cardHeight: cardWidth * root.service.monitorHeight / root.service.monitorWidth
        readonly property real thickness: cardWidth * 0.035

        // Camera space for a vector relative to the camera: x right, y up, z forward.
        function view(q) { return {x: q.x, y: q.y * cp - q.z * sp, z: -q.y * sp - q.z * cp} }
        // World point of a card position. Local x follows the card's tangent,
        // local y runs down, and lift pushes the point back along the normal.
        function world(f, x, y, lift) {
            return {x: f.origin.x + f.t.x * x - f.n.x * lift, y: f.origin.y - y, z: f.origin.z + f.t.z * x - f.n.z * lift}
        }
        function screen(p) {
            var v = view({x: p.x, y: p.y - focal * sp, z: p.z - focal * cp})
            return Qt.point(width / 2 + focal * v.x / v.z, height / 2 - focal * v.y / v.z)
        }
        // Cards face the camera's side of the ring. A small yaw toward the
        // centre keeps side cards readable, and rear cards stay un-mirrored.
        function cardFrame(theta) {
            var yaw = 0.55 * Math.sin(theta)
            var c = {x: radius * Math.sin(theta), y: 0, z: radius * Math.cos(theta)}
            var t = {x: Math.cos(yaw), y: 0, z: -Math.sin(yaw)}
            var n = {x: Math.sin(yaw), y: 0, z: Math.cos(yaw)}
            return {origin: {x: c.x - t.x * cardWidth / 2, y: cardHeight / 2, z: c.z - t.z * cardWidth / 2}, t: t, n: n}
        }
        // Maps the card's local pixel grid through the shared camera as a 4x4 matrix.
        function faceMatrix(f) {
            var o = view({x: f.origin.x, y: f.origin.y - focal * sp, z: f.origin.z - focal * cp})
            var a = view(f.t), b = view({x: 0, y: -1, z: 0})
            var cx = width / 2, cy = height / 2
            return Qt.matrix4x4(
                focal * a.x + cx * a.z, focal * b.x + cx * b.z, 0, focal * o.x + cx * o.z,
                -focal * a.y + cy * a.z, -focal * b.y + cy * b.z, 0, -focal * o.y + cy * o.z,
                0, 0, 1, 0,
                a.z, b.z, 0, o.z)
        }
        // Screen outline of one side face of the slab, from the front edge to the back edge.
        function edge(f, x0, y0, x1, y1) {
            return [screen(world(f, x0, y0, 0)), screen(world(f, x1, y1, 0)),
                    screen(world(f, x1, y1, thickness)), screen(world(f, x0, y0, thickness))]
        }
        // A side is drawn only when its outward normal points toward the camera.
        function facesCamera(f, n, x, y) {
            var m = world(f, x, y, 0)
            return n.x * (0 - m.x) + n.y * (focal * sp - m.y) + n.z * (focal * cp - m.z) > 0
        }
        Repeater {
            model: root.service.workspaceIds
            Item {
                id: unit
                required property int modelData
                required property int index
                anchors.fill: stage
                readonly property real theta: (index - root.phase) * Math.PI * 2 / Math.max(1, root.count) - root.cameraYaw * Math.PI / 180
                readonly property real depth: (Math.cos(theta) + 1) / 2
                readonly property bool selected: root.service.selectedWorkspace === modelData
                readonly property var frame: stage.cardFrame(theta)
                readonly property var topEdge: stage.edge(frame, 0, 0, stage.cardWidth, 0)
                readonly property var bottomEdge: stage.edge(frame, 0, stage.cardHeight, stage.cardWidth, stage.cardHeight)
                readonly property var leftEdge: stage.edge(frame, 0, 0, 0, stage.cardHeight)
                readonly property var rightEdge: stage.edge(frame, stage.cardWidth, 0, stage.cardWidth, stage.cardHeight)
                readonly property bool topFacing: stage.facesCamera(frame, {x: 0, y: 1, z: 0}, stage.cardWidth / 2, 0)
                readonly property bool bottomFacing: stage.facesCamera(frame, {x: 0, y: -1, z: 0}, stage.cardWidth / 2, stage.cardHeight)
                readonly property bool leftFacing: stage.facesCamera(frame, {x: -frame.t.x, y: 0, z: -frame.t.z}, 0, stage.cardHeight / 2)
                readonly property bool rightFacing: stage.facesCamera(frame, {x: frame.t.x, y: 0, z: frame.t.z}, stage.cardWidth, stage.cardHeight / 2)
                z: depth * 1000 + index * 0.01
                opacity: 0.65 + depth * 0.35
                // The slab's sides sit behind the preview, so the card gains real thickness.
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: unit.topFacing ? (unit.selected ? ThemeTokens.alpha(ThemeTokens.accent, 0.6) : ThemeTokens.alpha(ThemeTokens.text, 0.45)) : "transparent"
                        PathPolyline { path: unit.topEdge }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: unit.rightFacing ? ThemeTokens.alpha(ThemeTokens.text, 0.14) : "transparent"
                        PathPolyline { path: unit.rightEdge }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: unit.leftFacing ? ThemeTokens.alpha(ThemeTokens.text, 0.22) : "transparent"
                        PathPolyline { path: unit.leftEdge }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: unit.bottomFacing ? ThemeTokens.alpha(ThemeTokens.text, 0.08) : "transparent"
                        PathPolyline { path: unit.bottomEdge }
                    }
                }
                Item {
                    id: card
                    objectName: "orbit-workspace-" + unit.modelData
                    width: stage.cardWidth
                    height: stage.cardHeight
                    // Render each workspace once at 2x resolution, then filter its
                    // transformed surface. The texture is bounded for older GPUs.
                    layer.enabled: true
                    layer.smooth: true
                    layer.mipmap: true
                    layer.samples: 4
                    layer.textureSize: Qt.size(Math.min(1280, Math.ceil(width * 2)), Math.min(720, Math.ceil(height * 2)))
                    transform: Matrix4x4 { matrix: stage.faceMatrix(unit.frame) }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.enterWorkspace(unit.modelData, "")
                    }
                    // Window previews remain independently clickable above the workspace.
                    WorkspaceScene {
                        anchors.fill: parent
                        service: root.service; workspaceId: unit.modelData
                        miniature: !unit.selected
                    }
                    MouseArea {
                        anchors.fill: parent; enabled: !unit.selected
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.enterWorkspace(unit.modelData, "")
                    }
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
