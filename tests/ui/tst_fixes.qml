import QtQuick
import QtTest
import "../.." as App

Item {
    id: scene
    width: 1100; height: 700
    focus: true

    QtObject {
        id: service
        property bool opened: true
        property var workspaceIds: [1, 2, 3, 4, 5]
        property var pinnedWorkspaces: []
        property int currentWorkspace: 5
        property bool showKeyGuide: true
        property bool highQuality: false
        property int selectedWorkspace: 5
        property int selectedWindow: 0
        property int monitorWidth: 1366
        property int monitorHeight: 768
        property var monitorData: ({x: 0, y: 0})
        property real previewScale: 0.96
        property bool reducedMotion: true
        property string searchText: ""
        property string windowDragAddress: ""
        property int windowDragWorkspace: 0
        property bool workspaceReordering: false
        property bool windowMoveBusy: false
        property int captureViews: 0
        property int readyCaptures: 0
        property var names: ({})
        property var sampleWindows: ({})
        function motionDuration(ms) { return 0 }
        function windowsFor(id) { return sampleWindows[id] || [] }
        function entryFor(w) { return null }
        function icon(e) { return "" }
        function workspaceName(id) { return names[id] || ("Workspace " + id) }
        function renameWorkspace(id, value) {
            var trimmed = String(value || "").trim()
            if (!trimmed || trimmed === ("Workspace " + id)) delete names[id]
            else names[id] = trimmed
            names = Object.assign({}, names)
            return true
        }
        function selectWorkspace(id) { selectedWorkspace = id }
        function focusWindow(w) { }
        function enterWorkspace(id, address) { }
        function moveWorkspace(delta) { }
        function dismiss() { }
    }

    Item {
        id: sceneHost
        width: 1000; height: 500
        App.WorkspaceScene {
            id: emptyCurrentScene
            anchors.fill: parent
            service: service
            workspaceId: 5
            miniature: false
        }
    }

    Item {
        id: orbitHost
        y: 520; width: 1000; height: 500
        visible: false
        App.WorkspaceOrbit {
            id: orbit
            anchors.fill: parent
            service: service
        }
    }

    Item {
        id: inputContainer
        width: 300; height: 40
        property int escapesSeen: 0
        property int acceptedCount: 0
        property var editedValues: []
        Keys.onEscapePressed: event => { escapesSeen++; event.accepted = true }
        App.SafeTextInput {
            id: safeInput
            anchors { fill: parent; margins: 4 }
            font.pixelSize: 13
            maximumLength: 20
            blinkCursor: false
            onAccepted: inputContainer.acceptedCount++
            onTextEdited: value => inputContainer.editedValues.push(value)
        }
    }

    App.WorkspaceName {
        id: nameEditor
        x: 320; y: 10
        width: 240; height: 36
        service: service
        property int finishedCount: 0
        onFinished: finishedCount++
    }

    TestCase {
        name: "FixesAndHardening"; when: windowShown

        function init() {
            service.currentWorkspace = 5
            service.selectedWorkspace = 5
            service.searchText = ""
            service.sampleWindows = ({})
            service.names = ({})
            safeInput.text = ""
            safeInput.maximumLength = 20
            inputContainer.escapesSeen = 0
            inputContainer.acceptedCount = 0
            inputContainer.editedValues = []
            nameEditor.editing = false
            nameEditor.finishedCount = 0
            wait(20)
        }

        function test_empty_current_workspace_has_no_solid_border_and_pads_badge() {
            var marker = findChild(emptyCurrentScene, "current-workspace-marker")
            var badge = findChild(emptyCurrentScene, "current-workspace-badge")
            var guide = findChild(emptyCurrentScene, "empty-workspace-guide")
            verify(marker && badge && guide)
            compare(marker.visible, true)
            compare(marker.border.width, 0)
            compare(badge.visible, true)
            var bPos = badge.mapToItem(guide, 0, 0)
            // Dashed guide draws strokeWidth 2 around x=1..width-1, y=1..height-1.
            verify(bPos.x >= 12, "Expected >=12px padding from dashed border on left, got " + bPos.x)
            verify(bPos.y >= 12, "Expected >=12px padding from dashed border on top, got " + bPos.y)
        }

        function test_occupied_current_workspace_keeps_solid_border() {
            service.sampleWindows = ({5: [{title: "Alacritty", wayland: null, lastIpcObject: {at: [0, 0], size: [600, 400], pinned: false}}]})
            wait(20)
            var marker = findChild(emptyCurrentScene, "current-workspace-marker")
            var badge = findChild(emptyCurrentScene, "current-workspace-badge")
            compare(marker.border.width, 2)
            compare(badge.x, 8)
            compare(badge.y, 8)
        }

        function test_safe_text_input_editing_navigation_and_paste_guard() {
            safeInput.forceActiveFocus()
            wait(10)
            keyClick(Qt.Key_H); keyClick(Qt.Key_E); keyClick(Qt.Key_L); keyClick(Qt.Key_L); keyClick(Qt.Key_O)
            compare(safeInput.text, "hello")
            compare(inputContainer.editedValues[inputContainer.editedValues.length - 1], "hello")

            // Left / Right / Backspace / Delete
            keyClick(Qt.Key_Left); keyClick(Qt.Key_Left)
            keyClick(Qt.Key_Backspace)
            compare(safeInput.text, "helo")
            keyClick(Qt.Key_Delete)
            compare(safeInput.text, "heo")

            // Home, End, Shift+Left selection and replacement
            keyClick(Qt.Key_End)
            keyClick(Qt.Key_Left, Qt.ShiftModifier)
            keyClick(Qt.Key_Y)
            compare(safeInput.text, "hey")

            // Ctrl+V, Shift+Insert, middle-click must never modify text
            keyClick(Qt.Key_V, Qt.ControlModifier)
            keyClick(Qt.Key_Insert, Qt.ShiftModifier)
            mouseClick(safeInput, 10, 10, Qt.MiddleButton)
            compare(safeInput.text, "hey")

            // Ctrl+A replace and maximumLength cap
            keyClick(Qt.Key_A, Qt.ControlModifier)
            for (var i = 0; i < 25; i++) keyClick(Qt.Key_A)
            compare(safeInput.text.length, 20)

            // Ctrl+Backspace deletes word; Ctrl+U clears
            keyClick(Qt.Key_Space); keyClick(Qt.Key_X) // at limit, unchanged
            safeInput.maximumLength = 40
            keyClick(Qt.Key_U, Qt.ControlModifier)
            compare(safeInput.text, "")
            keyClick(Qt.Key_F); keyClick(Qt.Key_O); keyClick(Qt.Key_O); keyClick(Qt.Key_Space); keyClick(Qt.Key_B); keyClick(Qt.Key_A); keyClick(Qt.Key_R)
            keyClick(Qt.Key_Backspace, Qt.ControlModifier)
            compare(safeInput.text, "foo ")

            // Return triggers accepted; Escape bubbles to parent FocusScope/container
            keyClick(Qt.Key_Return)
            compare(inputContainer.acceptedCount, 1)
            keyClick(Qt.Key_Escape)
            compare(inputContainer.escapesSeen, 1)
        }

        function test_workspace_name_editor_commit_cancel_and_reset() {
            nameEditor.beginEdit()
            wait(20)
            compare(nameEditor.editing, true)
            keyClick(Qt.Key_C); keyClick(Qt.Key_O); keyClick(Qt.Key_D); keyClick(Qt.Key_E)
            keyClick(Qt.Key_Return)
            compare(nameEditor.editing, false)
            compare(service.workspaceName(5), "code")
            compare(nameEditor.finishedCount, 1)

            // Cancel preserves name
            nameEditor.beginEdit()
            wait(20)
            keyClick(Qt.Key_X)
            keyClick(Qt.Key_Escape)
            compare(nameEditor.editing, false)
            compare(service.workspaceName(5), "code")

            // Empty submit resets name
            nameEditor.beginEdit()
            wait(20)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Return)
            compare(nameEditor.editing, false)
            compare(service.workspaceName(5), "Workspace 5")
        }

        function test_orbit_cards_avoid_double_layer_and_normalize_matrix() {
            orbitHost.visible = true
            wait(20)
            var card1 = findChild(orbit, "orbit-workspace-1")
            verify(card1)
            compare(card1.layer.enabled, false)
            var t = card1.transform[0]
            fuzzyCompare(t.matrix.m44, 1.0, 0.0001)
            orbitHost.visible = false
        }
    }
}
