import QtQuick
import QtQuick.Shapes
import "WorkspaceModel.js" as Model

Item {
    id: root
    required property var service
    property var previewOrder: []
    property var originalOrder: []
    property int draggedId: -1
    property bool dragging: false
    property real dragX: 0
    readonly property var order: dragging ? previewOrder : service.workspaceIds
    readonly property real pitch: 54
    implicitWidth: Math.max(0, (service.workspaceIds.length + 1) * pitch - 10)
    implicitHeight: 38
    function cancel() { dragging = false; draggedId = -1; previewOrder = []; originalOrder = [] }
    Repeater {
        model: root.service.workspaceIds
        Item {
            id: tab
            required property int modelData
            readonly property bool selected: root.service.selectedWorkspace === modelData
            readonly property bool occupied: root.service.windowsFor(modelData).length > 0
            readonly property bool current: root.service.currentWorkspace === modelData
            readonly property bool pinned: root.service.pinnedWorkspaces.indexOf(modelData) >= 0
            readonly property bool moving: root.dragging && root.draggedId === modelData
            width: 44; height: 38
            x: moving ? root.dragX : Math.max(0, root.order.indexOf(modelData)) * root.pitch
            y: moving ? -4 : 0
            z: moving ? 10 : 0
            scale: moving ? 1.12 : 1
            Behavior on x { enabled: !tab.moving; NumberAnimation { duration: root.service.motionDuration(160); easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: root.service.motionDuration(120) } }
            Behavior on scale { NumberAnimation { duration: root.service.motionDuration(120) } }
            Accessible.role: Accessible.PageTab
            Accessible.name: root.service.workspaceName(modelData) + (pinned ? "; pinned" : "; drag to reorder") + (current ? "; current workspace" : "")
            Accessible.selected: selected
            Accessible.onPressAction: root.service.selectWorkspace(modelData)
            Rectangle {
                visible: tab.occupied
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                width: tab.selected || tab.moving ? 34 : 15
                height: tab.selected || tab.moving ? 5 : 3
                radius: height / 2; antialiasing: true
                color: tab.selected || tab.moving ? ThemeTokens.accent : ThemeTokens.secondary
                opacity: tab.moving || tab.selected ? 1 : tabHover.containsMouse ? 0.9 : tab.occupied ? 0.6 : 0.28
                Behavior on width { NumberAnimation { duration: root.service.motionDuration(160) } }
            }
            Shape {
                id: emptyTabGuide
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
                width: 34; height: 14
                visible: !tab.occupied
                antialiasing: true
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: tab.selected || tab.moving ? ThemeTokens.accent : ThemeTokens.alpha(ThemeTokens.text, 0.65)
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 2]
                    PathPolyline { path: [Qt.point(1, 1), Qt.point(33, 1), Qt.point(33, 13), Qt.point(1, 13), Qt.point(1, 1)] }
                }
            }
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                text: tab.modelData
                textFormat: Text.PlainText
                color: tab.current ? ThemeTokens.accent : tab.selected || tab.moving ? ThemeTokens.text : ThemeTokens.secondary
                opacity: tab.selected || tab.moving || tab.current ? 0.9 : 0.45
                font.pixelSize: 10
            }
            // A small diamond marks a pinned workspace, which reordering leaves in place.
            Rectangle {
                visible: tab.pinned
                anchors { right: parent.right; rightMargin: 4; bottom: parent.bottom; bottomMargin: 5 }
                width: 5; height: 5; rotation: 45; color: ThemeTokens.accent
            }
            Rectangle { anchors.fill: parent; color: ThemeTokens.selectedHover; visible: windowDrop.containsDrag; z: -1 }
            DropArea {
                id: windowDrop
                anchors.fill: parent
                keys: ["workspace-window"]
                onEntered: function(drag) {
                    if (!root.service.windowDragAddress || root.service.workspaceReordering || root.service.windowDragWorkspace === tab.modelData) drag.accepted = false
                }
                onDropped: function(drop) {
                    if (root.service.moveWindowToWorkspace(root.service.windowDragAddress, tab.modelData)) drop.acceptProposedAction()
                }
            }
            MouseArea {
                id: tabHover
                anchors.fill: parent; hoverEnabled: true
                enabled: !root.service.workspaceReordering
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real pressX: 0
                property real grabX: 0
                onPressed: function(mouse) {
                    var p = mapToItem(root, mouse.x, mouse.y)
                    pressX = p.x; grabX = mouse.x
                    root.originalOrder = root.service.workspaceIds.slice()
                    root.previewOrder = root.originalOrder.slice()
                    root.draggedId = tab.modelData
                }
                onPositionChanged: function(mouse) {
                    if (!pressed || root.service.searchText.trim() || tab.pinned) return
                    var p = mapToItem(root, mouse.x, mouse.y)
                    if (!root.dragging && Math.abs(p.x - pressX) < 6) return
                    root.dragX = Math.max(-10, Math.min(root.width - tab.width + 10, p.x - grabX))
                    root.dragging = true
                    var target = Math.max(0, Math.min(root.originalOrder.length - 1, Math.round(root.dragX / root.pitch)))
                    root.previewOrder = Model.insertWorkspacePinned(root.originalOrder, tab.modelData, target, root.service.pinnedWorkspaces)
                }
                onReleased: {
                    if (root.dragging) root.service.reorderWorkspaces(root.originalOrder, root.previewOrder)
                    else root.service.selectWorkspace(tab.modelData)
                    root.cancel()
                }
                onCanceled: root.cancel()
            }
        }
    }
    // Opens the next free workspace number.
    Item {
        id: newTab
        x: root.service.workspaceIds.length * root.pitch; width: 44; height: 38
        Accessible.role: Accessible.Button
        Accessible.name: "Open a new workspace"
        Accessible.onPressAction: root.service.openNewWorkspace()
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
            width: 34; height: 14; radius: 3
            color: newTabMouse.containsMouse ? ThemeTokens.selected : "transparent"
            Text { anchors.centerIn: parent; text: "+"; color: newTabMouse.containsMouse ? ThemeTokens.accent : ThemeTokens.secondary; font.pixelSize: 15 }
        }
        Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 } text: "new"; color: ThemeTokens.subdued; font.pixelSize: 9 }
        MouseArea {
            id: newTabMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled: !root.service.workspaceReordering && !root.dragging
            onClicked: root.service.openNewWorkspace()
        }
    }
}
