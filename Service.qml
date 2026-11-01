import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "WorkspaceModel.js" as Model

Item {
    id: root
    property var shell: null
    property var manifest: null
    property bool opened: false
    property var dragWindowsSnapshot: []
    property string windowDragAddress: ""
    property string windowDragTitle: ""
    property int windowDragWorkspace: 0
    property real windowDragX: 0
    property real windowDragY: 0
    property bool windowMoveBusy: false
    property string windowMoveFeedback: ""
    signal windowDragEnded(bool canceled)
    function beginWindowDrag(w, x, y) {
        if (!opened || workspaceReordering || windowMoveBusy || !w || w.lastIpcObject.pinned) return false
        dragWindowsSnapshot = windows.slice()
        windowDragAddress = Model.windowAddress(w.address)
        windowDragTitle = w.title || "Window"
        windowDragWorkspace = w.workspace ? w.workspace.id : 0
        windowDragX = x; windowDragY = y
        return !!windowDragAddress
    }
    function finishWindowDrag(canceled) {
        if (!windowDragAddress) return
        windowDragEnded(canceled)
        windowDragAddress = ""
        windowDragWorkspace = 0
        dragWindowsSnapshot = []
        refresh.restart()
    }
    Timer {
        interval: 120; repeat: true; running: !!root.windowDragAddress
        onTriggered: {
            var exists = Hyprland.toplevels.values.some(function(w) { return w && Model.windowAddress(w.address) === root.windowDragAddress })
            if (!exists) root.finishWindowDrag(true)
        }
    }
    property var pendingWindowMove: null
    function undoLastAction() {
        if (workspaceReordering || windowMoveBusy || windowDragAddress || !actionHistory.length) return false
        var entry = actionHistory[actionHistory.length - 1]
        if (entry.kind === "reorder") return reorderWorkspaces(entry.slots, entry.order, true)
        var w = windows.find(function(window) { return window && Model.windowAddress(window.address) === entry.address })
        if (!Model.canUndoWindowMove(entry, w)) {
            actionHistory = actionHistory.slice(0, -1)
            windowMoveFeedback = "Undo unavailable — the window was closed or moved elsewhere"
            windowMoveMessage.restart()
            return false
        }
        return moveWindowToWorkspace(entry.address, entry.from, true)
    }
    function moveWindowToWorkspace(address, id, undoing) {
        address = Model.windowAddress(address); id = Number(id)
        if (!address || !Number.isInteger(id) || id < 1 || (!undoing && allWorkspaceIds.indexOf(id) < 0) || workspaceReordering || windowMoveBusy) return false
        var w = windows.find(function(window) { return Model.windowAddress(window.address) === address })
        if (!Model.canMoveWindow(w, id, undoing ? allWorkspaceIds.concat([id]) : allWorkspaceIds)) return false
        pendingWindowMove = {kind: "window", address: address, from: w.workspace.id, to: id, undoing: undoing === true, pid: w.lastIpcObject.pid || 0}
        windowMoveFeedback = "Moving window…"
        windowMoveBusy = true
        windowMove.command = ["hyprctl", "dispatch", 'hl.dsp.window.move({window="address:' + address + '",workspace="' + id + '",follow=false})']
        windowMove.running = true
        return true
    }
    Process {
        id: windowMove
        stdout: StdioCollector {
            onStreamFinished: {
                var success = text.trim() === "ok"
                if (success) {
                    if (root.pendingWindowMove.undoing) root.actionHistory = root.actionHistory.slice(0, -1)
                    else root.actionHistory = root.actionHistory.concat([root.pendingWindowMove]).slice(-20)
                    root.reorderNotice = root.pendingWindowMove.undoing ? "Window move undone" : "Window moved"
                    root.reorderNoticeVisible = true
                    reorderNoticeTimer.restart()
                }
                root.windowMoveFeedback = success ? "" : "Could not move window: " + text.trim()
                root.windowMoveBusy = false
                Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); root.revision++
                windowMoveMessage.restart()
            }
        }
        onExited: function(code) {
            if (code !== 0) Qt.callLater(function() {
                if (root.windowMoveBusy) { root.windowMoveBusy = false; root.windowMoveFeedback = "Could not move window"; windowMoveMessage.restart() }
            })
        }
    }
    function closeWindow(w) {
        if (!w || workspaceReordering || windowMoveBusy || windowDragAddress || !windows.includes(w)) return false
        const address = Model.windowAddress(w.address)
        if (!address) return false
        // A polite close request: the application can still ask to save its work.
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.window.close({window="address:' + address + '"})' : "closewindow address:" + address)
        refresh.restart()
        return true
    }
    function moveSelectedWindow(delta) {
        const list = selectedWindows
        if (!list.length) return false
        const w = list[Math.min(selectedWindow, list.length - 1)]
        const ids = allWorkspaceIds
        const from = ids.indexOf(w.workspace ? w.workspace.id : selectedWorkspace)
        if (from < 0 || ids.length < 2) return false
        const target = ids[(from + delta + ids.length) % ids.length]
        if (!moveWindowToWorkspace(w.address, target)) return false
        selectWorkspace(target)
        return true
    }
    function togglePinnedWorkspace(id) {
        const pinned = Model.togglePinned(pinnedWorkspaces, id)
        if (!saveSettings({pinnedWorkspaces: pinned})) return false
        pinnedWorkspaces = pinned
        return true
    }
    function openNewWorkspace() {
        const id = Model.nextWorkspaceId(allWorkspaceIds)
        if (workspaceReordering || !id) return
        pendingWorkspace = id
        pendingWindow = ""
        dismiss()
        activation.restart()
    }
    function jumpToIndex(index) {
        const ids = workspaceIds
        if (index >= 0 && index < ids.length) selectWorkspace(ids[index])
    }
    Timer { id: windowMoveMessage; interval: 5000; onTriggered: root.windowMoveFeedback = "" }
    property bool workspaceReordering: false
    property var reorderSlots: []
    property var reorderMapping: ({})
    property int reorderSelection: 1
    property var actionHistory: []
    readonly property var reorderHistory: actionHistory.filter(function(entry) { return entry.kind === "reorder" })
    property bool reorderNoticeVisible: false
    property string reorderNotice: ""
    property var pendingUndoEntry: null
    property bool reorderIsUndo: false
    function undoReorder() {
        return actionHistory.length && actionHistory[actionHistory.length - 1].kind === "reorder" ? undoLastAction() : false
    }
    Timer { id: reorderNoticeTimer; interval: 8000; onTriggered: root.reorderNoticeVisible = false }
    function reorderWorkspaces(slots, order, undoing) {
        if (workspaceReordering || windowMoveBusy || windowDragAddress || searchText.trim()) return false
        var mapping = Model.workspacePermutation(slots, order)
        if (!mapping || JSON.stringify(slots) === JSON.stringify(order)) return false
        reorderIsUndo = undoing === true
        pendingUndoEntry = {kind: "reorder", slots: slots.slice(), order: Model.inverseWorkspaceOrder(slots, order)}
        reorderSlots = slots.slice()
        reorderMapping = mapping
        reorderSelection = selectedWorkspace
        settingsError = "Rearranging workspaces…"
        workspaceReordering = true
        reorderProcess.command = ["python3", decodeURIComponent(String(Qt.resolvedUrl("reorder_workspaces.py")).replace(/^file:\/\//, "")), JSON.stringify({slots: slots, order: order})]
        reorderProcess.running = true
        reorderWatchdog.restart()
        return true
    }
    // The overview holds exclusive keyboard focus, so a stuck reorder must never leave it unclosable.
    Timer {
        id: reorderWatchdog; interval: 30000
        onTriggered: if (root.workspaceReordering) { reorderProcess.running = false; root.finishReorder('{"ok":false,"error":"Workspace reorder timed out"}') }
    }
    function finishReorder(text) {
        if (!workspaceReordering) return
        reorderWatchdog.stop()
        var result
        try { result = JSON.parse(text) } catch (error) { result = {ok: false, error: "Could not read workspace reorder result"} }
        if (result.ok) {
            var names = result.names || Model.remapWorkspaceNames(workspaceNames, reorderMapping)
            selectedWorkspace = reorderMapping[String(reorderSelection)] || reorderSelection
            workspaceNames = names
            persistedEntry = Object.assign({}, persistedEntry, {workspaceNames: names})
            settingsError = ""
            if (reorderIsUndo) actionHistory = actionHistory.slice(0, -1)
            else actionHistory = actionHistory.concat([pendingUndoEntry]).slice(-20)
            reorderNotice = reorderIsUndo ? "Workspace order restored" : "Workspaces rearranged"
            reorderNoticeVisible = true
            reorderNoticeTimer.restart()
        } else settingsError = result.error || "Could not reorder workspaces"
        Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors()
        workspaceReordering = false
        revision++
    }
    Process {
        id: reorderProcess
        stdout: StdioCollector { onStreamFinished: root.finishReorder(text) }
        onExited: function(code) {
            if (code !== 0) Qt.callLater(function() { if (root.workspaceReordering) root.finishReorder('{"ok":false,"error":"Workspace reorder failed"}') })
        }
    }
    property int selectedWorkspace: 1
    property int selectedWindow: 0
    property int revision: 0
    property int captureViews: 0
    property int readyCaptures: 0
    property var workspaceNames: ({})
    property string searchText: ""
    property real previewScale: 1
    property int animationDuration: 300
    property bool reducedMotion: false
    property bool showKeyGuide: true
    property bool liveOtherWorkspaces: false
    property string defaultView: "classic"
    property var pinnedWorkspaces: []
    property string settingsError: ""
    property var persistedEntry: ({id: "io.github.aicyraa.workspace-gallery"})
    property bool preferencesLoaded: false
    readonly property var monitor: Hyprland.focusedMonitor
    readonly property var screen: {
        const name = monitor ? monitor.name : ""
        return Quickshell.screens.find(s => s.name === name) || null
    }
    readonly property var monitorData: monitor ? monitor.lastIpcObject : ({})
    readonly property real monitorWidth: screen ? screen.width : 1366
    readonly property real monitorHeight: screen ? screen.height : 768
    readonly property var windows: {
        if (windowDragAddress) return dragWindowsSnapshot
        const r = revision
        return Hyprland.toplevels.values.filter(w => w.lastIpcObject.mapped !== false)
    }
    readonly property var allWorkspaceIds: {
        if (workspaceReordering) return reorderSlots
        const r = revision
        const ids = new Set([1, 2, 3, 4, 5])
        Hyprland.workspaces.values.forEach(w => { if (w.id > 0 && (w.toplevels.values.length || w.active)) ids.add(w.id) })
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ids.add(Hyprland.focusedWorkspace.id)
        return Array.from(ids).sort((a,b) => a-b)
    }
    readonly property var workspaceIds: {
        if (!searchText.trim()) return allWorkspaceIds
        const ids = allWorkspaceIds.filter(id => windowsFor(id).length > 0)
        return ids.length ? ids : [selectedWorkspace]
    }
    readonly property var selectedWindows: windowsFor(selectedWorkspace)
    readonly property int matchCount: windows.filter(w => onMonitor(w) && matches(w)).length
    readonly property int currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    function onMonitor(w) { return w.monitor && monitor && w.monitor.id === monitor.id }
    function matches(w) {
        const entry = entryFor(w)
        return Model.matches(searchText, w.title, entry ? entry.name : "", w.lastIpcObject.class, w.workspace ? workspaceName(w.workspace.id) : "")
    }
    function windowsFor(id) { return rawWindowsFor(id).filter(w => matches(w)) }
    function rawWindowsFor(id) {
        const r = revision
        return windows.filter(w => w && w.workspace && (w.workspace.id === id || w.lastIpcObject.pinned) && w.monitor && monitor && w.monitor.id === monitor.id)
    }
    function entryFor(w) {
        const d = w.lastIpcObject
        const cls = d.class || (w.wayland ? w.wayland.appId : "")
        if (cls === "org.omarchy.agent") return DesktopEntries.byId("Alacritty")
        return DesktopEntries.heuristicLookup(cls)
    }
    function icon(entry) {
        const found = Model.safeImageSource(Quickshell.iconPath(entry && entry.icon ? entry.icon : "application-x-executable", true))
        return found || Model.safeImageSource(Quickshell.iconPath("application-x-executable"))
    }
    property int pendingWorkspace: 0
    property string pendingWindow: ""
    function enterWorkspace(id, address) {
        id = Number(id)
        if (workspaceReordering || !Number.isInteger(id) || id < 1 || allWorkspaceIds.indexOf(id) < 0) return
        pendingWorkspace = id
        pendingWindow = Model.windowAddress(address)
        dismiss()
        // Release the overview's exclusive keyboard focus before focusing a client.
        activation.restart()
    }
    Timer {
        id: activation
        interval: 90
        onTriggered: {
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({workspace="' + root.pendingWorkspace + '"})' : "workspace " + root.pendingWorkspace)
            if (root.pendingWindow) {
                var target = root.windows.find(function(w) { return Model.windowAddress(w.address) === root.pendingWindow })
                if (target) Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({window="address:' + root.pendingWindow + '"})' : "focuswindow address:" + root.pendingWindow)
            }
            root.pendingWindow = ""
        }
    }
    function focusWindow(w) {
        if (!w || !windows.includes(w)) return
        var id = w.lastIpcObject.pinned ? selectedWorkspace : (w.workspace ? w.workspace.id : selectedWorkspace)
        enterWorkspace(id, w.address)
    }
    function activate() {
        const list = selectedWindows
        if (!list.length && searchText.trim()) return
        enterWorkspace(selectedWorkspace, list.length ? list[Math.min(selectedWindow, list.length - 1)].address : "")
    }
    function selectWorkspace(id) { selectedWorkspace = id; selectedWindow = 0 }
    function moveWorkspace(delta) {
        const ids = workspaceIds
        selectWorkspace(ids[(Math.max(0, ids.indexOf(selectedWorkspace)) + delta + ids.length) % ids.length])
    }
    function workspaceName(id) { return Model.workspaceName(id, workspaceNames) }
    function motionDuration(base) { return reducedMotion ? 0 : Math.round(base * animationDuration / 300) }
    function saveSettings(values) {
        settingsError = ""
        // The host replaces an inline entry; always send the complete merged entry.
        const merged = Object.assign({}, persistedEntry, values, {id: "io.github.aicyraa.workspace-gallery"})
        if (!preferencesLoaded || !shell || shell.updateEntryInline("io.github.aicyraa.workspace-gallery", merged) === false) {
            settingsError = "Could not save your preferences. Try again."
            return false
        }
        persistedEntry = merged
        return true
    }
    function setPreference(key, value) {
        if (key === "showKeyGuide" && typeof value === "boolean") {
            if (!saveSettings({showKeyGuide: value})) return false
            showKeyGuide = value; return true
        }
        if (key === "liveOtherWorkspaces" && typeof value === "boolean") {
            if (!saveSettings({liveOtherWorkspaces: value})) return false
            liveOtherWorkspaces = value; return true
        }
        if (key === "defaultView" && (value === "classic" || value === "orbit")) {
            if (!saveSettings({defaultView: value})) return false
            defaultView = value; return true
        }
        return false
    }
    function renameWorkspace(id, value) {
        const names = Model.renamed(workspaceNames, id, value)
        if (!saveSettings({workspaceNames: names})) return false
        workspaceNames = names
        return true
    }
    function setSearch(value) {
        if (searchText === value) return
        searchText = value; selectedWindow = 0
        ensureSearchSelection()
    }
    function ensureSearchSelection() {
        if (searchText.trim() && selectedWindows.length === 0) {
            const first = windows.find(w => onMonitor(w) && matches(w) && w.workspace && w.workspace.id > 0)
            if (first) selectWorkspace(first.workspace.id)
        }
    }
    FileView {
        id: preferences
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const config = JSON.parse(text())
                const entry = (config.plugins || []).find(p => p.id === "io.github.aicyraa.workspace-gallery") || {}
                const settings = Model.settings(entry)
                root.persistedEntry = entry
                root.preferencesLoaded = true
                root.workspaceNames = settings.workspaceNames
                root.previewScale = settings.previewScale
                root.animationDuration = settings.animationDuration
                root.reducedMotion = settings.reducedMotion
                root.showKeyGuide = settings.showKeyGuide
                root.liveOtherWorkspaces = settings.liveOtherWorkspaces
                root.defaultView = settings.defaultView
                root.pinnedWorkspaces = settings.pinnedWorkspaces
            } catch (error) { console.warn("Overview preferences:", error) }
        }
    }
    function dismiss() { finishWindowDrag(true); opened = false; if (shell) shell.hide("io.github.aicyraa.workspace-gallery") }
    Connections {
        target: Hyprland
        function onRawEvent(event) { refresh.restart() }
        function onFocusedMonitorChanged() { if (!root.workspaceReordering) root.opened = false; root.revision++ }
    }
    Timer {
        id: refresh; interval: 80
        onTriggered: {
            if (root.workspaceReordering || root.windowDragAddress) { refresh.restart(); return }
            Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors()
            root.revision++
            root.ensureSearchSelection()
            root.selectedWindow = Math.min(root.selectedWindow, Math.max(0, root.selectedWindows.length - 1))
        }
    }
}
