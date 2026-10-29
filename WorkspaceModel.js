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

function matches(query, title, appName, appClass) {
    var tokens = String(query || "").toLocaleLowerCase().trim().split(/\s+/).filter(function(t) { return t.length > 0 })
    var text = [title || "", appName || "", appClass || ""].join(" ").toLocaleLowerCase()
    return tokens.every(function(token) { return text.indexOf(token) !== -1 })
}

function settings(entry) {
    entry = entry || {}
    var names = entry.workspaceNames && typeof entry.workspaceNames === "object" && !Array.isArray(entry.workspaceNames) ? entry.workspaceNames : {}
    var scale = typeof entry.previewScale === "number" && isFinite(entry.previewScale) ? entry.previewScale : 1
    var duration = typeof entry.animationDuration === "number" && isFinite(entry.animationDuration) ? entry.animationDuration : 300
    return {workspaceNames: renamed(names, 0, ""), previewScale: Math.max(0.65, Math.min(1, scale)), animationDuration: Math.max(120, Math.min(500, duration)), reducedMotion: entry.reducedMotion === true}
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
