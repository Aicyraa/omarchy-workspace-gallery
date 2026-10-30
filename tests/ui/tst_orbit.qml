import QtQuick
import QtTest
import "../.." as App

Item {
    id: scene
    width: 1000; height: 600
    QtObject {
        id: service
        property var workspaceIds: [1, 2, 3, 4, 5]
        property int selectedWorkspace: 1
        property int selectedWindow: 0
        property int monitorWidth: 1366
        property int monitorHeight: 768
        property real previewScale: 1
        property bool reducedMotion: true
        property string searchText: ""
        property string windowDragAddress: ""
        property int windowDragWorkspace: 0
        property bool workspaceReordering: false
        property bool windowMoveBusy: false
        property int entered: 0
        function motionDuration(ms) { return 0 }
        function windowsFor(id) { return [] }
        function enterWorkspace(id, address) { entered = id }
        function moveWorkspace(delta) { selectedWorkspace = workspaceIds[(workspaceIds.indexOf(selectedWorkspace) + delta + workspaceIds.length) % workspaceIds.length] }
        function dismiss() { }
    }
    App.WorkspaceOrbit { id: orbit; anchors.fill: parent; service: service }
    TestCase {
        name: "WorkspaceRingProjection"; when: windowShown
        function card(id) { return findChild(orbit, 'orbit-workspace-' + id) }
        function center(id) { var item = card(id); return item.mapToItem(scene, item.width / 2, item.height / 2) }
        function init() { orbit.resetCamera(); service.selectedWorkspace = 1; service.entered = 0; service.windowDragAddress = ''; service.windowMoveBusy = false; wait(20) }
        function test_circle_has_depth_and_symmetric_sides() {
            var front = center(1), right = center(2), left = center(5), rear = center(3)
            fuzzyCompare(front.x, scene.width / 2, 0.1)
            fuzzyCompare(left.x + right.x, scene.width, 0.1)
            fuzzyCompare(left.y, right.y, 0.1)
            verify(front.y - rear.y > scene.height * 0.35, 'Front and back must have visible separation')
            verify(right.x > front.x && left.x < front.x)
        }
        function test_projected_cards_stay_in_view() {
            for (var id = 1; id <= 5; id++) {
                var item = card(id)
                var corners = [Qt.point(0, 0), Qt.point(item.width, 0), Qt.point(item.width, item.height), Qt.point(0, item.height)]
                for (var j = 0; j < corners.length; j++) {
                    var p = item.mapToItem(scene, corners[j].x, corners[j].y)
                    verify(isFinite(p.x) && isFinite(p.y))
                    verify(p.x >= 0 && p.x <= scene.width && p.y >= 0 && p.y <= scene.height)
                }
            }
        }
        function test_projected_click_enters_chosen_workspace() {
            var point = center(2)
            mouseClick(scene, point.x, point.y)
            compare(service.entered, 2)
        }
        function test_selection_rotates_chosen_workspace_to_front() {
            service.selectedWorkspace = 4
            wait(30)
            fuzzyCompare(center(4).x, scene.width / 2, 0.1)
            verify(center(4).y > scene.height / 2)
        }
        function test_default_view_is_lower() { compare(orbit.cameraElevation, 22) }
        function test_backdrop_drag_moves_and_keeps_camera() {
            var original = center(2)
            mousePress(scene, 80, 60)
            mouseMove(scene, 190, 20, 30, Qt.LeftButton)
            mouseRelease(scene, 190, 20)
            verify(orbit.cameraElevation > 22)
            verify(orbit.cameraYaw < 0)
            var moved = center(2)
            verify(Math.hypot(moved.x - original.x, moved.y - original.y) > 10)
            compare(service.selectedWorkspace, 1); compare(service.entered, 0)
            var elevation = orbit.cameraElevation, yaw = orbit.cameraYaw
            wait(50)
            compare(orbit.cameraElevation, elevation); compare(orbit.cameraYaw, yaw)
            compare(orbit.dragging, false)
        }
        function test_right_drag_over_workspace_does_not_activate() {
            var p = center(1)
            mousePress(scene, p.x, p.y, Qt.RightButton)
            mouseMove(scene, p.x + 100, p.y + 50, 30, Qt.RightButton)
            mouseRelease(scene, p.x + 100, p.y + 50, Qt.RightButton)
            verify(orbit.cameraYaw < 0); verify(orbit.cameraElevation < 22)
            compare(service.entered, 0); compare(service.selectedWorkspace, 1)
        }
        function test_camera_elevation_stays_in_bounds() {
            orbit.beginCameraDrag(0, 0); orbit.moveCamera(0, -10000)
            compare(orbit.cameraElevation, 36)
            orbit.moveCamera(0, 10000); compare(orbit.cameraElevation, 12)
            orbit.dragging = false
        }
        function test_camera_extremes_keep_cards_visible() {
            var elevations = [12, 36], angles = [0, 45, 90, 180]
            for (var e = 0; e < elevations.length; e++) {
                for (var a = 0; a < angles.length; a++) {
                    orbit.cameraElevation = elevations[e]; orbit.cameraYaw = angles[a]
                    test_projected_cards_stay_in_view()
                }
            }
        }
        function test_camera_drag_rejected_during_window_move() {
            service.windowMoveBusy = true
            mousePress(scene, 80, 60); mouseMove(scene, 190, 20, 30, Qt.LeftButton); mouseRelease(scene, 190, 20)
            compare(orbit.cameraElevation, 22); compare(orbit.cameraYaw, 0)
        }
        function test_zoom_clamps_between_default_and_max() {
            orbit.zoomCamera(-5); compare(orbit.cameraZoom, 1)
            orbit.zoomCamera(5); compare(orbit.cameraZoom, 2)
            orbit.resetCamera(); compare(orbit.cameraZoom, 1)
        }
        function test_ctrl_scroll_zooms_without_changing_workspace() {
            var before = card(1).width
            mouseWheel(scene, scene.width / 2, scene.height / 2, 0, 120, Qt.NoButton, Qt.ControlModifier)
            verify(orbit.cameraZoom > 1)
            verify(card(1).width > before, 'Zoom must enlarge the front card')
            compare(service.selectedWorkspace, 1); compare(service.entered, 0)
            mouseWheel(scene, scene.width / 2, scene.height / 2, 0, -10000, Qt.NoButton, Qt.ControlModifier)
            compare(orbit.cameraZoom, 1)
        }
        function test_plain_scroll_still_changes_workspace() {
            mouseWheel(scene, scene.width / 2, scene.height / 2, 0, -120, Qt.NoButton, Qt.NoModifier)
            compare(orbit.cameraZoom, 1)
            compare(service.selectedWorkspace, 2)
        }
        function test_reset_camera_clears_zoom() {
            orbit.cameraZoom = 1.5
            orbit.resetCamera()
            compare(orbit.cameraZoom, 1); compare(orbit.cameraYaw, 0)
        }
        function test_projected_click_after_camera_move() {
            orbit.cameraElevation = 32; orbit.cameraYaw = 16
            var p = center(2)
            mouseClick(scene, p.x, p.y)
            compare(service.entered, 2)
        }
    }
}
