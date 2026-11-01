// Render actual plugin components with original staged content for public previews.
import QtQuick
import QtTest
import "../.." as App
Item {
    width: 1920; height: 1080
Rectangle {
    id: scene
    width: 1920; height: 1080
    color: '#101315'
    property string mode: 'normal'
    QtObject {
        id: previewService
        property bool opened: true
        property var workspaceIds: [1, 2, 3, 4, 5]
        property int selectedWorkspace: 1
        property int selectedWindow: 0
        property int currentWorkspace: 1
        property var pinnedWorkspaces: [3]
        property bool showKeyGuide: true
        property int monitorWidth: 1366
        property int monitorHeight: 768
        property var monitorData: ({x: 0, y: 0})
        property real previewScale: 1
        property bool reducedMotion: true
        property string searchText: ''
        property string windowDragAddress: ''
        property int windowDragWorkspace: 0
        property bool workspaceReordering: false
        property bool windowMoveBusy: false
        property int captureViews: 0
        property int readyCaptures: 0
        property var samples: [
            {id: 1, title: 'Camera · Workspace Gallery', kind: 'editor', at: [38, 70], size: [768, 590]},
            {id: 1, title: 'Validation · Terminal', kind: 'terminal', at: [830, 70], size: [492, 590]},
            {id: 2, title: 'Field Notes · Reading', kind: 'reading', at: [190, 55], size: [980, 650]},
            {id: 3, title: 'Today · Notes', kind: 'notes', at: [100, 100], size: [900, 560]},
            {id: 5, title: 'Ideas · Field Notes', kind: 'reading', at: [65, 95], size: [1100, 590]}
        ]
        function windowsFor(id) {
            return samples.filter(s => s.id === id).map((s, index) => ({
                title: s.title, address: '0x' + (id * 10 + index),
                wayland: {kind: s.kind, title: s.title, width: s.size[0], height: s.size[1]},
                lastIpcObject: {at: s.at, size: s.size, pinned: false}
            }))
        }
        function workspaceName(id) { return ['Build', 'Read', 'Notes', 'Focus', 'Explore'][id - 1] }
        function motionDuration(ms) { return 0 }
        function selectWorkspace(id) { selectedWorkspace = id }
        function entryFor(w) { return null }
        function icon(entry) { return '' }
        function focusWindow(w) { }
        function finishWindowDrag(canceled) { }
        function dismiss() { }
        function enterWorkspace(id, address) { }
        function moveWorkspace(delta) { }
    }
    App.WorkspaceTabs {
        service: previewService
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 30 }
        width: implicitWidth; height: implicitHeight
    }
    Image { x: parent.width - 62; y: 36; width: 16; height: 16; source: '../../icons/settings.svg'; opacity: 0.65 }
    Item {
        id: normal
        x: 0; y: 90; width: parent.width; height: parent.height - 184
        visible: scene.mode === 'normal'
        readonly property real previewWidth: Math.min(width - 112, height * previewService.monitorWidth / previewService.monitorHeight)
        Repeater {
            model: previewService.workspaceIds
            Item {
                id: card
                required property int modelData
                required property int index
                readonly property real offset: index - (previewService.selectedWorkspace - 1)
                readonly property bool selected: offset === 0
                width: normal.previewWidth; height: normal.height
                x: (normal.width - width) / 2 + offset * (width * 0.82 + 28)
                y: Math.min(1, Math.abs(offset)) * 18
                scale: 1 - Math.min(1, Math.abs(offset)) * 0.20
                opacity: Math.max(0, 1 - Math.min(2, Math.abs(offset)) * 0.62)
                z: selected ? 10 : 5 - Math.abs(offset)
                visible: opacity > 0.005
                App.WorkspaceScene { anchors.fill: parent; workspaceId: card.modelData; service: previewService; miniature: !card.selected }
            }
        }
    }
    App.WorkspaceOrbit {
        id: orbit
        x: 0; y: 82; width: parent.width; height: parent.height - 184
        scale: 0.9
        visible: scene.mode === 'ring'
        service: previewService
    }
    App.WorkspaceName {
        service: previewService
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
    }
    // Mirrors the key guide in Overview.qml: keys in one column, labels in the next.
    Column {
        anchors { left: parent.left; leftMargin: 30; bottom: parent.bottom; bottomMargin: 17 }
        spacing: 6
        Repeater {
            model: scene.mode === 'normal'
                ? [{keys: ['←', '→'], label: 'Workspaces'}, {keys: ['Tab'], label: 'Windows'}, {keys: ['Enter'], label: 'Open'}, {keys: ['F2'], label: 'Rename'}, {keys: ['Type'], label: 'Search'}, {keys: ['F1'], label: 'Hide guide'}]
                : [{keys: ['Drag'], label: 'Orbit'}, {keys: ['Ctrl + Scroll'], label: 'Zoom'}, {keys: ['←', '→'], label: 'Workspaces'}, {keys: ['Enter'], label: 'Open'}, {keys: ['F1'], label: 'Hide guide'}]
            Row {
                required property var modelData
                spacing: 12
                Row {
                    width: scene.mode === 'normal' ? 44 : 76; spacing: 4
                    Repeater {
                        model: modelData.keys
                        Rectangle {
                            required property string modelData
                            height: 17; width: keyText.implicitWidth + 12; radius: 5
                            color: App.ThemeTokens.surface; border.width: 1; border.color: App.ThemeTokens.border
                            Text { id: keyText; anchors.centerIn: parent; text: parent.modelData; color: App.ThemeTokens.secondary; font.pixelSize: 10 }
                        }
                    }
                }
                Text { height: 17; verticalAlignment: Text.AlignVCenter; text: modelData.label; color: App.ThemeTokens.subdued; font.pixelSize: 10 }
            }
        }
    }
    TestCase {
        name: 'PublicationPreviews'; when: windowShown
        function savePreview(path) {
            var finished = false, saved = false
            verify(scene.grabToImage(function(result) {
                saved = result.saveToFile(String(Qt.resolvedUrl('../../' + path)).replace(/^file:\/\//, ''))
                finished = true
            }, Qt.size(1920, 1080)))
            tryVerify(function() { return finished }, 5000)
            verify(saved)
        }
        function test_render() {
            scene.mode = 'normal'; previewService.selectedWorkspace = 1
            wait(350)
            savePreview('assets/previews/overview.png')
            scene.mode = 'ring'; previewService.selectedWorkspace = 2; orbit.resetCamera()
            wait(350)
            savePreview('preview.png')
            previewService.selectedWorkspace = 4
            wait(350)
            savePreview('assets/previews/empty-workspace.png')
        }
    }
}

}
