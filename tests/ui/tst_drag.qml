import QtQuick
import QtTest
import "../.." as App

Item {
    id: scene
    width: 600; height: 420
    focus: true
    Keys.onEscapePressed: service.finishWindowDrag(true)
    QtObject {
        id: service
        property bool opened: true
        property bool workspaceReordering: false
        property bool windowMoveBusy: false
        property string searchText: ""
        property var workspaceIds: [1,2,3]
        property int selectedWorkspace: 1
        property string windowDragAddress: ""
        property string windowDragTitle: ""
        property int windowDragWorkspace: 0
        property real windowDragX: 0
        property real windowDragY: 0
        property int captureViews: 0
        property int readyCaptures: 0
        property var moves: []
        property var orders: []
        property int activations: 0
        property bool pinned: false
        signal windowDragEnded(bool canceled)
        function workspaceName(id) { return 'Workspace ' + id }
        function windowsFor(id) { return [] }
        function motionDuration(ms) { return 0 }
        function selectWorkspace(id) { selectedWorkspace = id }
        function reorderWorkspaces(slots, order) { orders = orders.concat([order]); return true }
        function entryFor(w) { return null }
        function icon(e) { return '' }
        function beginWindowDrag(w,x,y) {
            if (pinned || windowMoveBusy || workspaceReordering) return false
            windowDragAddress='0xabcd';windowDragWorkspace=1;windowDragX=x;windowDragY=y;return true
        }
        function finishWindowDrag(canceled) {
            if (!windowDragAddress) return
            windowDragEnded(canceled);windowDragAddress='';windowDragWorkspace=0
        }
        function moveWindowToWorkspace(address,id) { moves=moves.concat([{address:address,id:id}]);return true }
    }
    App.WorkspaceTabs { id: tabs; x:220;y:20;width:implicitWidth;height:implicitHeight;service:service }
    App.WindowPreview {
        id: preview
        x:40;y:160;width:180;height:100
        service:service
        windowHandle: QtObject { property var wayland:null; property string title:'Test window'; property var lastIpcObject: ({pinned:service.pinned}) }
        onActivated: service.activations++
    }
    Rectangle {
        id: ghost
        x:service.windowDragX-10;y:service.windowDragY-10;width:80;height:25;z:100
        visible: !!service.windowDragAddress
        Drag.active: visible
        Drag.keys: ['workspace-window']
        Drag.source: service
        Drag.hotSpot.x:10;Drag.hotSpot.y:10
        Drag.supportedActions:Qt.MoveAction;Drag.proposedAction:Qt.MoveAction
        Connections { target:service; function onWindowDragEnded(canceled) { if(canceled) ghost.Drag.cancel();else ghost.Drag.drop() } }
    }
    TestCase {
        name:'WorkspaceDrag';when:windowShown
        function init() { scene.forceActiveFocus();service.windowMoveBusy=false; service.moves=[];service.orders=[];service.activations=0;service.pinned=false;service.windowDragAddress='';service.windowDragWorkspace=0;service.selectedWorkspace=1 }
        function test_click_focuses_without_moving() { mouseClick(preview,70,40);compare(service.activations,1);compare(service.moves.length,0) }
        function test_window_drop_on_tab() {
            mousePress(preview,70,40)
            mouseMove(scene,140,180,30,Qt.LeftButton)
            mouseMove(scene,296,36,50,Qt.LeftButton)
            wait(30)
            mouseRelease(scene,296,36)
            compare(service.moves.length,1);compare(service.moves[0].id,2);compare(service.activations,0);compare(service.windowDragAddress,'')
        }
        function test_drop_outside_cancels() {
            mousePress(preview,70,40);mouseMove(scene,150,190,30,Qt.LeftButton);mouseMove(scene,500,360,40,Qt.LeftButton);mouseRelease(scene,500,360)
            compare(service.moves.length,0);compare(service.activations,0);compare(service.windowDragAddress,'')
        }
        function test_pinned_does_not_drag() {
            service.pinned=true
            mousePress(preview,70,40);mouseMove(scene,296,36,50,Qt.LeftButton);mouseRelease(scene,296,36)
            compare(service.moves.length,0);compare(service.windowDragAddress,'')
        }
        function test_same_workspace_rejected() {
            mousePress(preview,70,40);mouseMove(scene,150,190,30,Qt.LeftButton);mouseMove(scene,242,36,40,Qt.LeftButton);wait(20);mouseRelease(scene,242,36)
            compare(service.moves.length,0)
        }
        function test_escape_cancels_drag() {
            mousePress(preview,70,40);mouseMove(scene,150,190,30,Qt.LeftButton)
            verify(service.windowDragAddress.length>0)
            keyClick(Qt.Key_Escape)
            compare(service.windowDragAddress,'')
            mouseMove(scene,296,36,30,Qt.LeftButton);mouseRelease(scene,296,36)
            compare(service.moves.length,0)
        }
        function test_busy_move_rejects_new_drag() {
            service.windowMoveBusy=true
            mousePress(preview,70,40);mouseMove(scene,296,36,40,Qt.LeftButton);mouseRelease(scene,296,36)
            compare(service.moves.length,0);compare(service.windowDragAddress,'')
        }
        function test_tab_drag_shifts_order() {
            mousePress(tabs,22,18);mouseMove(tabs,40,18,20,Qt.LeftButton);mouseMove(tabs,129,18,30,Qt.LeftButton);mouseRelease(tabs,129,18)
            compare(service.orders.length,1);compare(JSON.stringify(service.orders[0]),'[2,3,1]')
        }
    }
}
