.pragma library

function cleanName(value) {
    return String(value || "").replace(/\s+/g, " ").trim().slice(0, 48)
}

function workspaceName(id, names) {
    var value = names && typeof names[String(id)] === "string" ? cleanName(names[String(id)]) : ""
    return value || "Workspace " + id
}

function renamed(names, id, value) {
    var next = {}
    Object.keys(names || {}).forEach(function(key) {
        if (/^[1-9][0-9]*$/.test(key) && typeof names[key] === "string") next[key] = cleanName(names[key])
    })
    var name = cleanName(value)
    if (!name || name === "Workspace " + id) delete next[String(id)]
    else next[String(id)] = name
    return next
}

function matches(query, title, appName, appClass, workspaceLabel) {
    var tokens = String(query || "").toLocaleLowerCase().trim().split(/\s+/).filter(function(t) { return t.length > 0 })
    var text = [title || "", appName || "", appClass || "", workspaceLabel || ""].join(" ").toLocaleLowerCase()
    return tokens.every(function(token) { return text.indexOf(token) !== -1 })
}

function settings(entry) {
    entry = entry || {}
    var names = entry.workspaceNames && typeof entry.workspaceNames === "object" && !Array.isArray(entry.workspaceNames) ? entry.workspaceNames : {}
    var scale = typeof entry.previewScale === "number" && isFinite(entry.previewScale) ? entry.previewScale : 1
    var duration = typeof entry.animationDuration === "number" && isFinite(entry.animationDuration) ? entry.animationDuration : 300
    return {workspaceNames: renamed(names, 0, ""), previewScale: Math.max(0.65, Math.min(1, scale)), animationDuration: Math.max(120, Math.min(500, duration)), reducedMotion: entry.reducedMotion === true,
        showKeyGuide: entry.showKeyGuide !== false, liveOtherWorkspaces: entry.liveOtherWorkspaces === true, previewQuality: entry.previewQuality === "high" ? "high" : "standard", defaultView: entry.defaultView === "orbit" ? "orbit" : "classic", pinnedWorkspaces: cleanPinned(entry.pinnedWorkspaces)}
}

function cleanPinned(value) {
    var out = []
    if (!Array.isArray(value)) return out
    value.forEach(function(id) {
        if (Number.isInteger(id) && id >= 1 && id <= 100000 && out.indexOf(id) < 0 && out.length < 100) out.push(id)
    })
    return out.sort(function(a, b) { return a - b })
}

function togglePinned(pinned, id) {
    var list = cleanPinned(pinned)
    var at = list.indexOf(id)
    if (at >= 0) list.splice(at, 1)
    else if (Number.isInteger(id)) list = cleanPinned(list.concat([id]))
    return list
}

// Like insertWorkspace, but pinned workspaces keep their position in the list.
function insertWorkspacePinned(ids, id, index, pinned) {
    pinned = pinned || []
    if (pinned.indexOf(id) >= 0 || ids.indexOf(id) < 0) return ids.slice()
    var rest = ids.filter(function(other) { return other !== id })
    var free = rest.filter(function(other) { return pinned.indexOf(other) < 0 })
    var at = rest.slice(0, Math.max(0, Math.min(rest.length, index))).filter(function(other) { return pinned.indexOf(other) < 0 }).length
    free.splice(at, 0, id)
    var next = ids.map(function(other) { return pinned.indexOf(other) >= 0 ? other : null })
    var cursor = 0
    return next.map(function(other) { return other === null ? free[cursor++] : other })
}

// Quickshell icon paths are local; refuse anything that could reach the network.
function safeImageSource(value) {
    var source = String(value || "")
    return /^(image:\/\/icon\/|file:\/\/\/|\/(?!\/))/.test(source) ? source : ""
}

function nextWorkspaceId(ids) {
    var highest = ids.reduce(function(a, b) { return Math.max(a, b) }, 0)
    return highest >= 100000 ? 0 : highest + 1
}

// Parses the order sent over IPC; anything but a short list of integers is rejected.
function parseOrderPayload(text) {
    try {
        var value = JSON.parse(text)
        if (value && Array.isArray(value.order) && value.order.length > 0 && value.order.length <= 100 && value.order.every(Number.isInteger)) return value.order
    } catch (error) { }
    return null
}

function windowAddress(value) {
    var address = String(value || "").replace(/^0x/i, "")
    return /^[0-9a-f]+$/i.test(address) ? "0x" + address : ""
}

function insertWorkspace(ids, id, index) {
    var next = ids.slice()
    var from = next.indexOf(id)
    if (from < 0) return next
    next.splice(from, 1)
    next.splice(Math.max(0, Math.min(next.length, index)), 0, id)
    return next
}
function workspacePermutation(slots, order) {
    if (slots.length !== order.length || new Set(slots).size !== slots.length || slots.some(function(id) { return order.indexOf(id) < 0 })) return null
    var mapping = {}
    order.forEach(function(id, index) { mapping[String(id)] = slots[index] })
    return mapping
}
function remapWorkspaceNames(names, mapping) {
    var next = {}
    Object.keys(names).forEach(function(id) { next[String(mapping[id] === undefined ? id : mapping[id])] = names[id] })
    return next
}

function inverseWorkspaceOrder(slots, order) {
    var mapping = workspacePermutation(slots, order)
    return mapping ? slots.map(function(id) { return mapping[String(id)] }) : null
}

function canMoveWindow(window, workspace, allowed) {
    return !!window && !!window.workspace && !(window.lastIpcObject || {}).pinned
        && Number.isInteger(workspace) && allowed.indexOf(workspace) >= 0
        && window.workspace.id !== workspace
}

function canUndoWindowMove(entry, window) {
    return !!entry && entry.kind === "window" && !!window && !!window.workspace
        && windowAddress(window.address) === entry.address
        && window.workspace.id === entry.to
        && (!entry.pid || (window.lastIpcObject || {}).pid === entry.pid)
}
