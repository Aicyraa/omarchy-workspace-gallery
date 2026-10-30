import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var service: null
    property bool opened: false
    property string viewMode: "classic"
    property real cameraLift: opened && viewMode === "orbit" ? 1 : 0
    Behavior on cameraLift {
        enabled: root.opened
        NumberAnimation { duration: root.service ? root.service.motionDuration(360) : 360; easing.type: Easing.InOutCubic }
    }
    function togglePerspective() {
        if (!opened) return shell ? shell.summon("io.github.aicyraa.workspace-gallery", '{"view":"orbit"}') === true : false
        if (!service || !service.opened) return false
        searchVisible = false; settingsVisible = false
        service.setSearch("")
        viewMode = viewMode === "orbit" ? "classic" : "orbit"
        Qt.callLater(function() { keys.forceActiveFocus() })
        return true
    }
    IpcHandler {
        target: "io.github.aicyraa.workspace-gallery.perspective"
        function toggle(): bool { return root.togglePerspective() }
        function select(id: int): void { if (root.opened && root.service && root.service.allWorkspaceIds.indexOf(id) >= 0) root.service.selectWorkspace(id) }
        function reorder(order: string): bool { return root.opened && root.service ? root.service.reorderWorkspaces(root.service.allWorkspaceIds, JSON.parse(order).order) : false }
        function undo(): bool { return root.service ? root.service.undoLastAction() : false }
        function moveWindow(address: string, workspace: int): bool { return root.opened && root.service ? root.service.moveWindowToWorkspace(address, workspace) : false }
        function activate(): void { if (root.opened && root.service) root.service.activate() }
        function status(): string { return JSON.stringify({opened: root.opened, mode: root.viewMode, transition: root.cameraLift, reordering: root.service ? root.service.workspaceReordering : false, error: root.service ? root.service.settingsError : "", undoCount: root.service ? root.service.actionHistory.length : 0, movingWindow: root.service ? root.service.windowMoveBusy : false, moveFeedback: root.service ? root.service.windowMoveFeedback : "", workspace: root.service ? root.service.selectedWorkspace : null}) }
    }
    property bool searchVisible: false
    property bool settingsVisible: false
    onSettingsVisibleChanged: if (settingsVisible) Qt.callLater(function() { if (overviewLoader.item) overviewLoader.item.focusSettings() })
    function beginRename() { if (overviewLoader.item) overviewLoader.item.beginRename() }
    function beginSearch(initial) {
        searchVisible = true; settingsVisible = false
        if (typeof initial === "string") service.setSearch(initial)
        Qt.callLater(function() { if (overviewLoader.item) overviewLoader.item.focusSearch() })
    }
    function clearSearch() { service.setSearch(""); searchVisible = false; keys.forceActiveFocus() }
    function open(payload) {
        var requested = {}
        try { requested = JSON.parse(payload || "{}") } catch (error) { }
        viewMode = requested.view === "orbit" ? "orbit" : "classic"
        if (!service && shell) service = shell.serviceFor("io.github.aicyraa.workspace-gallery")
        if (!service) { console.warn("Overview service unavailable"); return }
        service.setSearch(""); searchVisible = false; settingsVisible = false
        service.selectWorkspace(Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
        service.opened = true; opened = true
        Qt.callLater(() => keys.forceActiveFocus())
    }
    function diagnostics(arg) {
        return JSON.stringify(service ? {opened: service.opened, view: viewMode, captures: service.captureViews, ready: service.readyCaptures, workspace: service.selectedWorkspace, windows: service.selectedWindows.length, query: service.searchText, workspaceName: service.workspaceName(service.selectedWorkspace), workspaceNames: service.workspaceNames, previewScale: service.previewScale, animationDuration: service.animationDuration, reducedMotion: service.reducedMotion, workspaceIds: service.workspaceIds, matches: service.matchCount} : {error: "Service unavailable"})
    }
    function close() { opened = false; settingsVisible = false; searchVisible = false; if (service) service.opened = false }
    Connections {
        target: root.service
        function onOpenedChanged() { if (!root.service.opened && root.opened) { root.opened = false; if (root.shell) root.shell.hide("io.github.aicyraa.workspace-gallery") } }
    }
    PanelWindow {
        id: panel
        screen: root.service ? root.service.screen : null
        visible: root.opened && root.service !== null && root.service.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        // Cover the entire output above applications and the bar, without
        // changing the desktop's reserved space or application geometry.
        exclusionMode: ExclusionMode.Ignore
        color: ThemeTokens.overviewScrim
        WlrLayershell.namespace: "aicyraa-workspace-gallery"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Loader {
            id: overviewLoader
            anchors.fill: parent
            active: root.opened && root.service !== null
            z: 1
            sourceComponent: Item {
                function focusSettings() { settingsPane.focusFirst() }
                function beginRename() { root.settingsVisible = false; nameEditor.beginEdit() }
                function focusSearch() { searchInput.forceActiveFocus(); searchInput.cursorPosition = searchInput.text.length }
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: root.service.motionDuration(150) } }
                MouseArea { anchors.fill: parent; enabled: root.viewMode === "classic"; onClicked: root.service.dismiss() }
                WorkspaceTabs {
                    service: root.service
                    anchors { top: parent.top; topMargin: 30; horizontalCenter: parent.horizontalCenter }
                    width: implicitWidth; height: implicitHeight
                }
                Rectangle {
                    visible: root.searchVisible
                    anchors { top: parent.top; topMargin: 78; horizontalCenter: parent.horizontalCenter }
                    width: Math.min(430, parent.width - 120); height: 38
                    radius: 12; color: ThemeTokens.surface; border.width: 1; border.color: ThemeTokens.border
                    Text { x: 13; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: ThemeTokens.secondary; font.pixelSize: 23 }
                    Text { visible: !searchInput.text && !searchInput.preeditText; x: 39; anchors.verticalCenter: parent.verticalCenter; text: "Search windows by app or title"; color: ThemeTokens.subdued; font.pixelSize: 12 }
                    TextInput {
                        id: searchInput
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 39; rightMargin: 14 }
                        text: root.service.searchText; color: ThemeTokens.text
                        font.pixelSize: 12; clip: true; selectByMouse: true; maximumLength: 256
                        selectionColor: ThemeTokens.selectedHover; selectedTextColor: ThemeTokens.text
                        Accessible.name: "Search windows"
                        onTextChanged: root.service.setSearch(text)
                        onAccepted: root.service.activate()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) { root.clearSearch(); event.accepted = true }
                            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                const count = root.service.selectedWindows.length
                                if (count) root.service.selectedWindow = (root.service.selectedWindow + (event.modifiers & Qt.ShiftModifier ? -1 : 1) + count) % count
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) { keys.forceActiveFocus(); event.accepted = true }
                        }
                    }
                }
                Rectangle {
                    id: preferencesButton
                    anchors { top: parent.top; right: parent.right; topMargin: 29; rightMargin: 30 }
                    width: 32; height: 32; radius: 10; z: 70
                    color: root.settingsVisible || preferencesMouse.containsMouse ? ThemeTokens.selected : "transparent"
                    Image {
                        anchors.centerIn: parent
                        width: 19; height: 19
                        source: "icons/settings.svg"
                        sourceSize: Qt.size(38, 38)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1
                            colorizationColor: root.settingsVisible || preferencesMouse.containsMouse ? ThemeTokens.accent : ThemeTokens.secondary
                        }
                    }
                    MouseArea { id: preferencesMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.settingsVisible = !root.settingsVisible; keys.forceActiveFocus() } Accessible.role: Accessible.Button; Accessible.name: "Overview preferences" }
                }
                Item {
                    id: workspaceStage
                    enabled: root.viewMode === "classic"
                    opacity: 1 - root.cameraLift
                    visible: opacity > 0.001
                    scale: root.service.reducedMotion ? 1 : 1 - root.cameraLift * 0.20
                    transform: Rotation {
                        origin.x: workspaceStage.width / 2; origin.y: workspaceStage.height / 2
                        axis { x: 1; y: 0; z: 0 }
                        angle: root.service.reducedMotion ? 0 : root.cameraLift * 14
                    }
                    x: 0; y: root.searchVisible ? 136 : 90; width: parent.width; height: parent.height - y - 94
                    readonly property real previewWidth: Math.min(width - 112, height * root.service.monitorWidth / root.service.monitorHeight) * root.service.previewScale
                    readonly property int selectedIndex: root.service.workspaceIds.indexOf(root.service.selectedWorkspace)
                    property real visualIndex: selectedIndex
                    Behavior on visualIndex { NumberAnimation { duration: root.service.motionDuration(260); easing.type: Easing.OutCubic } }
                    Timer { id: wheelCooldown; interval: 220 }
                    WheelHandler {
                        acceptedDevices: PointerDevice.AllDevices
                        enabled: !root.service.windowDragAddress
                        onWheel: event => {
                            const delta = event.angleDelta.x || event.angleDelta.y
                            if (delta && !wheelCooldown.running) {
                                root.service.moveWorkspace(delta > 0 ? -1 : 1)
                                wheelCooldown.start()
                            }
                            event.accepted = true
                        }
                    }
                    Repeater {
                        model: root.service.workspaceIds
                        Item {
                            id: workspacePreview
                            required property int modelData
                            required property int index
                            readonly property real offset: index - workspaceStage.visualIndex
                            readonly property bool selected: index === workspaceStage.selectedIndex
                            width: workspaceStage.previewWidth; height: workspaceStage.height
                            x: (workspaceStage.width - width) / 2 + offset * (width * 0.82 + 28)
                            y: Math.min(1, Math.abs(offset)) * 18
                            scale: 1 - Math.min(1, Math.abs(offset)) * 0.20
                            transform: Rotation {
                                origin.x: workspacePreview.width / 2; origin.y: workspacePreview.height / 2
                                axis { x: 0; y: 1; z: 0 }
                                angle: root.service.reducedMotion ? 0 : Math.max(-1, Math.min(1, workspacePreview.offset)) * -12
                            }
                            opacity: Math.max(0, 1 - Math.min(2, Math.abs(offset)) * 0.62)
                            z: selected ? 10 : 5 - Math.abs(offset)
                            visible: opacity > 0.005
                            // The workspace has no background, frame, padding, or border.
                            // Its windows alone form the animated preview.
                            Loader {
                                anchors.fill: parent
                                active: Math.abs(workspacePreview.offset) <= 1 || workspacePreview.opacity > 0.005
                                sourceComponent: WorkspaceScene {
                                    service: root.service; workspaceId: workspacePreview.modelData
                                    miniature: !workspacePreview.selected
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !workspacePreview.selected
                                onClicked: root.service.selectWorkspace(workspacePreview.modelData)
                            }
                        }
                    }
                }
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 100 }
                    width: noticeRow.width + 28; height: 36; radius: 0; z: 20
                    color: ThemeTokens.panel
                    visible: root.service.reorderNoticeVisible
                    Row {
                        id: noticeRow; anchors.centerIn: parent; spacing: 22
                        Text { text: root.service.reorderNotice; color: ThemeTokens.text; font.pixelSize: 12 }
                        Text {
                            text: "Undo  Ctrl+Z"; color: ThemeTokens.accent; font.pixelSize: 12
                            visible: root.service.actionHistory.length > 0
                            opacity: root.service.workspaceReordering || root.service.windowMoveBusy ? 0.4 : 1
                            MouseArea { anchors.fill: parent; enabled: !root.service.workspaceReordering && !root.service.windowMoveBusy; cursorShape: Qt.PointingHandCursor; onClicked: root.service.undoLastAction() }
                        }
                    }
                }
                WorkspaceName {
                    id: nameEditor
                    service: root.service
                    anchors { bottom: parent.bottom; bottomMargin: 39; horizontalCenter: parent.horizontalCenter }
                    width: Math.min(implicitWidth, parent.width - 64); height: 36
                    onFinished: keys.forceActiveFocus()
                }
                // Feedback replaces the key legend while it is shown.
                Text {
                    visible: !!(root.service.settingsError || root.service.windowMoveFeedback)
                    anchors { bottom: parent.bottom; bottomMargin: 17; horizontalCenter: parent.horizontalCenter }
                    text: root.service.settingsError || root.service.windowMoveFeedback
                    color: ThemeTokens.subdued; font.pixelSize: 11
                }
                Column {
                    id: hintRow
                    visible: !(root.service.settingsError || root.service.windowMoveFeedback)
                    anchors { bottom: parent.bottom; bottomMargin: 17; left: parent.left; leftMargin: 30 }
                    spacing: 7
                    function hintItems() {
                        if (nameEditor.editing) return [{keys: ["Enter"], label: "Save name"}, {keys: ["Esc"], label: "Cancel"}, {keys: [], label: "Empty name resets"}]
                        if (root.searchVisible) return [{keys: [], label: root.service.matchCount + " matches"}, {keys: ["Tab"], label: "Select"}, {keys: ["Enter"], label: "Open"}, {keys: ["Esc"], label: "Clear"}]
                        if (root.viewMode === "orbit") return [{keys: ["Drag"], label: "Orbit"}, {keys: ["Ctrl + Scroll"], label: "Zoom"}, {keys: ["←", "→"], label: "Workspaces"}, {keys: ["Enter"], label: "Open"}]
                        return [{keys: ["←", "→"], label: "Workspaces"}, {keys: ["Tab"], label: "Windows"}, {keys: ["Enter"], label: "Open"}, {keys: ["F2"], label: "Rename"}, {keys: ["Type"], label: "Search"}]
                    }
                    Repeater {
                        model: hintRow.hintItems()
                        Row {
                            required property var modelData
                            spacing: 10
                            // Fixed key column keeps every description aligned.
                            Row {
                                width: 84; spacing: 5
                            Repeater {
                                model: modelData.keys
                                Rectangle {
                                    required property string modelData
                                    height: 20; width: keyText.implicitWidth + 14; radius: 6
                                    color: ThemeTokens.surface; border.width: 1; border.color: ThemeTokens.border
                                    Text { id: keyText; anchors.centerIn: parent; text: parent.modelData; color: ThemeTokens.secondary; font.pixelSize: 11 }
                                }
                            }
                            }
                            Text {
                                height: 20; verticalAlignment: Text.AlignVCenter
                                text: modelData.label; color: ThemeTokens.subdued; font.pixelSize: 11
                            }
                        }
                    }
                }
                MouseArea { anchors.fill: parent; visible: root.settingsVisible; z: 50; onClicked: { root.settingsVisible = false; keys.forceActiveFocus() } }
                OverviewSettings {
                    id: settingsPane
                    onDismissed: { root.settingsVisible = false; keys.forceActiveFocus() }
                    anchors { top: parent.top; right: parent.right; topMargin: 72; rightMargin: 30 }
                    width: implicitWidth; height: implicitHeight; z: 60
                    visible: root.settingsVisible; service: root.service
                }

            }
        }
        Loader {
            anchors { fill: parent; topMargin: 90; bottomMargin: 94 }
            active: root.opened && root.service !== null && (root.viewMode === "orbit" || root.cameraLift > 0.001)
            enabled: root.viewMode === "orbit"
            opacity: root.cameraLift
            scale: root.service && root.service.reducedMotion ? 1 : 1.15 - root.cameraLift * 0.25
            transform: Translate { y: root.service && root.service.reducedMotion ? 0 : (1 - root.cameraLift) * 45 - root.cameraLift * 8 }
            sourceComponent: WorkspaceOrbit { service: root.service }
        }
        Rectangle {
            id: windowDragGhost
            x: root.service ? root.service.windowDragX - 18 : 0
            y: root.service ? root.service.windowDragY - 18 : 0
            width: 220; height: 40; radius: 0; z: 1000
            color: ThemeTokens.panel
            visible: root.opened && root.service !== null && !!root.service.windowDragAddress
            Drag.active: visible
            Drag.source: root.service
            Drag.keys: ["workspace-window"]
            Drag.hotSpot.x: 18
            Drag.hotSpot.y: 18
            Drag.supportedActions: Qt.MoveAction
            Drag.proposedAction: Qt.MoveAction
            Text { anchors { fill: parent; margins: 10 } text: root.service ? root.service.windowDragTitle : ""; textFormat: Text.PlainText; color: ThemeTokens.text; font.pixelSize: 12; elide: Text.ElideRight }
            Connections {
                target: root.service
                function onWindowDragEnded(canceled) { if (canceled) windowDragGhost.Drag.cancel(); else windowDragGhost.Drag.drop() }
            }
        }
        Item {
            id: keys; focus: true
            Keys.onPressed: event => {
                if (!root.service || root.service.workspaceReordering) return
                if (root.service.windowDragAddress) {
                    if (event.key === Qt.Key_Escape) root.service.finishWindowDrag(true)
                    event.accepted = true; return
                }
                if (event.key === Qt.Key_Z && event.modifiers & Qt.ControlModifier && !root.settingsVisible && !root.searchVisible) {
                    root.service.undoLastAction(); event.accepted = true; return
                }
                if (root.viewMode === "orbit" && !root.settingsVisible && !root.searchVisible) {
                    if (event.key === Qt.Key_Escape) root.service.dismiss()
                    else if (event.key === Qt.Key_F2) root.beginRename()
                    else if (event.key === Qt.Key_F && event.modifiers & Qt.ControlModifier) root.beginSearch()
                    else if (event.key === Qt.Key_Comma && event.modifiers & Qt.ControlModifier) root.settingsVisible = !root.settingsVisible
                    else if (event.key === Qt.Key_Left) root.service.moveWorkspace(-1)
                    else if (event.key === Qt.Key_Right) root.service.moveWorkspace(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) root.service.moveWorkspace((event.key === Qt.Key_Up ? -1 : 1))
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.service.activate()
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        const n = root.service.selectedWindows.length
                        if (n) root.service.selectedWindow = (root.service.selectedWindow + (event.modifiers & Qt.ShiftModifier ? -1 : 1) + n) % n
                    } else return
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Escape) {
                    if (root.settingsVisible) root.settingsVisible = false
                    else if (root.searchVisible || root.service.searchText) root.clearSearch()
                    else root.service.dismiss()
                }
                else if (event.key === Qt.Key_F2) root.beginRename()
                else if (event.key === Qt.Key_F && event.modifiers & Qt.ControlModifier) root.beginSearch()
                else if (event.key === Qt.Key_Comma && event.modifiers & Qt.ControlModifier) root.settingsVisible = !root.settingsVisible
                else if (event.key === Qt.Key_Left) root.service.moveWorkspace(-1)
                else if (event.key === Qt.Key_Right) root.service.moveWorkspace(1)
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    const n = root.service.selectedWindows.length
                    if (n) root.service.selectedWindow = (root.service.selectedWindow + (event.modifiers & Qt.ShiftModifier ? -1 : 1) + n) % n
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.service.activate()
                else if (event.text && event.text.trim() && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) root.beginSearch(event.text)
                else return
                event.accepted = true
            }
        }
    }
}
