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
    property bool lastBarMotionState: false
    onOpenedChanged: syncBarMotion()
    function syncBarMotion() {
        if (barMotion.running) return
        lastBarMotionState = opened
        barMotion.command = ["omarchy-shell", "jee.bar", "setOverviewHidden", opened ? "true" : "false"]
        barMotion.running = true
    }
    Process {
        id: barMotion
        onExited: if (root.lastBarMotionState !== root.opened) root.syncBarMotion()
    }
    Component.onDestruction: Quickshell.execDetached(["omarchy-shell", "jee.bar", "setOverviewHidden", "false"])
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
    }
    function moveWindowToWorkspace(address, id) {
        address = Model.windowAddress(address); id = Number(id)
        if (!address || !Number.isInteger(id) || allWorkspaceIds.indexOf(id) < 0 || workspaceReordering || windowMoveBusy) return false
        var w = windows.find(function(window) { return Model.windowAddress(window.address) === address })
        if (!Model.canMoveWindow(w, id, allWorkspaceIds)) return false
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
                root.windowMoveFeedback = text.trim() === "ok" ? "Window moved — select its workspace to view it" : "Could not move window: " + text.trim()
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
    Timer { id: windowMoveMessage; interval: 5000; onTriggered: root.windowMoveFeedback = "" }
    property bool workspaceReordering: false
    property var reorderSlots: []
    property var reorderMapping: ({})
    property int reorderSelection: 1
    property var reorderHistory: []
    property bool reorderNoticeVisible: false
    property string reorderNotice: ""
    property var pendingUndoEntry: null
    property bool reorderIsUndo: false
    function undoReorder() {
        if (workspaceReordering || !reorderHistory.length) return false
        var entry = reorderHistory[reorderHistory.length - 1]
        return reorderWorkspaces(entry.slots, entry.order, true)
    }
    Timer { id: reorderNoticeTimer; interval: 8000; onTriggered: root.reorderNoticeVisible = false }
    function reorderWorkspaces(slots, order, undoing) {
        if (workspaceReordering || windowMoveBusy || windowDragAddress || searchText.trim()) return false
        var mapping = Model.workspacePermutation(slots, order)
        if (!mapping || JSON.stringify(slots) === JSON.stringify(order)) return false
        reorderIsUndo = undoing === true
        pendingUndoEntry = {slots: slots.slice(), order: Model.inverseWorkspaceOrder(slots, order)}
        reorderSlots = slots.slice()
        reorderMapping = mapping
        reorderSelection = selectedWorkspace
        settingsError = "Rearranging workspaces…"
        workspaceReordering = true
        reorderProcess.command = ["python3", String(Qt.resolvedUrl("reorder_workspaces.py")).replace(/^file:\/\//, ""), JSON.stringify({slots: slots, order: order})]
        reorderProcess.running = true
        return true
    }
    function finishReorder(text) {
        if (!workspaceReordering) return
        var result
        try { result = JSON.parse(text) } catch (error) { result = {ok: false, error: "Could not read workspace reorder result"} }
        if (result.ok) {
            var names = result.names || Model.remapWorkspaceNames(workspaceNames, reorderMapping)
            selectedWorkspace = reorderMapping[String(reorderSelection)] || reorderSelection
            workspaceNames = names
            persistedEntry = Object.assign({}, persistedEntry, {workspaceNames: names})
            settingsError = ""
            if (reorderIsUndo) reorderHistory = reorderHistory.slice(0, -1)
            else reorderHistory = reorderHistory.concat([pendingUndoEntry]).slice(-10)
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
    property string settingsError: ""
    property var persistedEntry: ({id: "jee.overview"})
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
    function onMonitor(w) { return w.monitor && monitor && w.monitor.id === monitor.id }
    function matches(w) {
        const entry = entryFor(w)
        return Model.matches(searchText, w.title, entry ? entry.name : "", w.lastIpcObject.class)
    }
    function windowsFor(id) { return rawWindowsFor(id).filter(w => matches(w)) }
    function rawWindowsFor(id) {
        const r = revision
        return windows.filter(w => w.workspace && (w.workspace.id === id || w.lastIpcObject.pinned) && w.monitor && monitor && w.monitor.id === monitor.id)
    }
    function entryFor(w) {
        const d = w.lastIpcObject
        const cls = d.class || (w.wayland ? w.wayland.appId : "")
        if (cls === "org.omarchy.agent") return DesktopEntries.byId("Alacritty")
        return DesktopEntries.heuristicLookup(cls)
    }
    function icon(entry) { return Quickshell.iconPath(entry && entry.icon ? entry.icon : "application-x-executable", true) || Quickshell.iconPath("application-x-executable") }
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
        const merged = Object.assign({}, persistedEntry, values, {id: "jee.overview"})
        if (!preferencesLoaded || !shell || shell.updateEntryInline("jee.overview", merged) === false) {
            settingsError = "Could not save your preferences. Try again."
            return false
        }
        persistedEntry = merged
        return true
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
                const entry = (config.plugins || []).find(p => p.id === "jee.overview") || {}
                const settings = Model.settings(entry)
                root.persistedEntry = entry
                root.preferencesLoaded = true
                root.workspaceNames = settings.workspaceNames
                root.previewScale = settings.previewScale
                root.animationDuration = settings.animationDuration
                root.reducedMotion = settings.reducedMotion
            } catch (error) { console.warn("Overview preferences:", error) }
        }
    }
    function dismiss() { finishWindowDrag(true); opened = false; if (shell) shell.hide("jee.overview") }
    Connections {
        target: Hyprland
        function onRawEvent(event) { refresh.restart() }
        function onFocusedMonitorChanged() { if (!root.workspaceReordering) root.opened = false; root.revision++ }
    }
    Timer {
        id: refresh; interval: 80
        onTriggered: {
            if (root.workspaceReordering) { refresh.restart(); return }
            Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors()
            root.revision++
            root.ensureSearchSelection()
            root.selectedWindow = Math.min(root.selectedWindow, Math.max(0, root.selectedWindows.length - 1))
        }
    }
}
