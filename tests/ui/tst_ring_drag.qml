import QtQuick
import QtTest
import "../.." as App

Item {
    id: scene
    width: 1000; height: 600
    focus: true
    Keys.onEscapePressed: service.finishWindowDrag(true)
    QtObject {
        id: service
        property bool opened: true
        property var workspaceIds: [1, 2, 3, 4, 5]
        property var pinnedWorkspaces: []
        property int currentWorkspace: 0
        property bool showKeyGuide: true
        property int selectedWorkspace: 1
        property int selectedWindow: 0
        property int monitorWidth: 1366
        property int monitorHeight: 768
        property var monitorData: ({x: 0, y: 0})
        property real previewScale: 1
        property bool reducedMotion: true
        property string searchText: ""
        property string windowDragAddress: ""
        property int windowDragWorkspace: 0
        property real windowDragX: 0
        property real windowDragY: 0
        property bool workspaceReordering: false
        property bool windowMoveBusy: false
        property bool pinned: false
        property int captureViews: 0
        property int readyCaptures: 0
        property int activations: 0
        property var moves: []
        property int entered: 0
        signal windowDragEnded(bool canceled)
        property var win: ({address: '0xabcd', title: 'Editor', wayland: null, lastIpcObject: {at: [0, 0], size: [1366, 768], pinned: false}})
        function motionDuration(ms) { return 0 }
        function windowsFor(id) { return id === 1 ? [win] : [] }
        function icon(e) { return '' }
        function entryFor(w) { return null }
        function workspaceName(id) { return 'Workspace ' + id }
        function enterWorkspace(id, address) { entered = id }
        function selectWorkspace(id) { selectedWorkspace = id }
        function focusWindow(w) { activations++ }
        function moveWorkspace(delta) { }
        function dismiss() { }
        function beginWindowDrag(w, x, y) {
            if (pinned || windowMoveBusy || workspaceReordering) return false
            windowDragAddress = w.address; windowDragWorkspace = selectedWorkspace; windowDragX = x; windowDragY = y
            return true
        }
        function finishWindowDrag(canceled) {
            if (!windowDragAddress) return
            windowDragEnded(canceled); windowDragAddress = ''; windowDragWorkspace = 0
        }
        function moveWindowToWorkspace(address, id) { moves = moves.concat([{address: address, id: id}]); return true }
    }
    App.WorkspaceOrbit { id: orbit; anchors.fill: parent; service: service }
    Rectangle {
        id: ghost
        x: service.windowDragX - 10; y: service.windowDragY - 10; width: 80; height: 25; z: 100
        visible: !!service.windowDragAddress
        Drag.active: visible
        Drag.keys: ['workspace-window']
        Drag.source: service
        Drag.hotSpot.x: 10; Drag.hotSpot.y: 10
        Drag.supportedActions: Qt.MoveAction; Drag.proposedAction: Qt.MoveAction
        Connections { target: service; function onWindowDragEnded(canceled) { if (canceled) ghost.Drag.cancel(); else ghost.Drag.drop() } }
    }
    TestCase {
        name: 'RingDrag'; when: windowShown
        function card(id) { return findChild(orbit, 'orbit-workspace-' + id) }
        function center(id) { var item = card(id); return item.mapToItem(scene, item.width / 2, item.height / 2) }
        function init() {
            orbit.resetCamera(); service.selectedWorkspace = 1; service.entered = 0; service.activations = 0
            service.moves = []; service.windowDragAddress = ''; service.windowMoveBusy = false; service.pinned = false
            wait(20)
        }
        function test_drag_window_from_front_card_to_side_card() {
            var from = center(1), to = center(2)
            mousePress(scene, from.x, from.y)
            mouseMove(scene, from.x + 20, from.y, 10, Qt.LeftButton)
            mouseMove(scene, (from.x + to.x) / 2, (from.y + to.y) / 2, 20, Qt.LeftButton)
            mouseMove(scene, to.x, to.y, 20, Qt.LeftButton)
            wait(30)
            mouseRelease(scene, to.x, to.y)
            compare(service.moves.length, 1, 'window was not dropped on the side workspace')
            compare(service.moves[0].id, 2)
        }
        function test_click_side_card_enters_that_workspace() {
            var p = center(2)
            mouseClick(scene, p.x, p.y)
            compare(service.entered, 2)
        }
        function test_drag_window_from_side_card_is_allowed() {
            service.selectedWorkspace = 2
            wait(30)
            var from = center(1), to = center(3)
            mousePress(scene, from.x, from.y)
            mouseMove(scene, from.x + 20, from.y, 10, Qt.LeftButton)
            mouseMove(scene, to.x, to.y, 20, Qt.LeftButton)
            wait(30)
            mouseRelease(scene, to.x, to.y)
            compare(service.moves.length, 1, 'windows on a background card cannot be dragged')
        }
    }
}
