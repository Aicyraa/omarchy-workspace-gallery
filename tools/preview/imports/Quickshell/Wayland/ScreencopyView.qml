// Preview-only fixture: original sample window content, never compositor capture.
import QtQuick
Item {
    id: root
    property var captureSource: null
    property bool live: false
    property bool paintCursor: false
    readonly property bool hasContent: captureSource !== null
    readonly property string kind: captureSource ? captureSource.kind : 'editor'
    Item {
        width: root.captureSource ? root.captureSource.width : 800
        height: root.captureSource ? root.captureSource.height : 600
        scale: root.width / width
        transformOrigin: Item.TopLeft
        Rectangle { anchors.fill: parent; color: root.kind === 'terminal' ? '#131819' : '#1b2024' }
        Rectangle { width: parent.width; height: 38; color: '#242a30' }
        Row {
            x: 15; y: 15; spacing: 7
            Repeater { model: ['#9f6a72', '#b4a077', '#7d9b86']; Rectangle { required property string modelData; width: 8; height: 8; radius: 4; color: modelData } }
        }
        Text { x: 80; y: 11; text: root.captureSource ? root.captureSource.title : ''; color: '#a8adb5'; font.pixelSize: 12 }
        Column {
            x: 28; y: 70; spacing: 11
            visible: root.kind === 'editor'
            Text { text: 'overview / camera.qml'; color: '#b6a0d5'; font.pixelSize: 15 }
            Repeater {
                model: ['01   import QtQuick', '02', '03   WorkspaceOrbit {', '04       cameraElevation: 22', '05       cameraYaw: 0', '06', '07       // A quieter way to move between spaces', '08       onDrag: moveCamera(mouse.x, mouse.y)', '09       onReleased: keepViewpoint()', '10', '11       workspaces: [Code, Read, Plan, Focus]', '12   }']
                Text { required property string modelData; text: modelData; font.family: 'monospace'; font.pixelSize: 15; color: modelData.indexOf('//') >= 0 ? '#74867c' : '#c9cbd0' }
            }
        }
        Column {
            x: 26; y: 68; spacing: 14
            visible: root.kind === 'terminal'
            Repeater {
                model: ['$ node --test tests/model.test.cjs', '✓ Workspace names and search', '✓ Workspace order and Undo', '✓ Camera movement and bounds', '', '$ python3 tests/reorder_test.py', 'Ran 5 tests — OK', '', '$ omarchy plugin validate .', 'Workspace Gallery · valid', '', 'Ready when you are.']
                Text { required property string modelData; text: modelData; font.family: 'monospace'; font.pixelSize: 14; color: modelData.indexOf('✓') === 0 ? '#9bb39e' : '#bdc2c8' }
            }
        }
        Column {
            x: 40; y: 80; width: parent.width - 80; spacing: 22
            visible: root.kind === 'reading'
            Text { text: 'FIELD NOTES'; color: '#b6a0d5'; font.pixelSize: 12; font.letterSpacing: 3 }
            Text { text: 'Room to think.'; color: '#e1e3e5'; font.pixelSize: 43; font.weight: Font.DemiBold }
            Text { width: parent.width; text: 'A calm desktop begins with a little space.\nKeep your work close and the next idea in view.'; color: '#9da5b0'; font.pixelSize: 18; lineHeight: 1.6; wrapMode: Text.WordWrap }
            Rectangle { width: parent.width; height: 1; color: '#343a42' }
            Repeater { model: ['01    Find your focus', '02    Arrange your workspace', '03    Make room for something new']; Text { required property string modelData; text: modelData; color: '#c5cbd0'; font.pixelSize: 18 } }
        }
        Column {
            x: 36; y: 72; width: parent.width - 72; spacing: 24
            visible: root.kind === 'notes'
            Text { text: 'A small plan'; font.pixelSize: 32; color: '#e0dce7' }
            Repeater { model: ['Keep the essentials nearby', 'Finish one thing with care', 'Leave a little room to explore', 'Take a break. Come back fresh.']; Text { required property string modelData; text: '○   ' + modelData; color: '#b4bac4'; font.pixelSize: 18 } }
            Rectangle { width: parent.width; height: 1; color: '#343a42' }
            Text { text: 'Today, at your own pace.'; color: '#b6a0d5'; font.pixelSize: 16 }
        }
    }
}
