// Static guards for the plugin's trust boundaries. Window titles, app ids and IPC
// arguments are controlled by other programs, so they must never reach a parser,
// a URL loader or a compositor command without validation.
const test = require('node:test')
const assert = require('node:assert')
const fs = require('node:fs')
const path = require('node:path')

const root = path.join(__dirname, '..')
const sources = fs.readdirSync(root).filter(f => f.endsWith('.qml') || f.endsWith('.js')).map(f => [f, fs.readFileSync(path.join(root, f), 'utf8').split('\n')])

function offenders(pattern) {
  const found = []
  for (const [file, lines] of sources) lines.forEach((line, i) => { if (pattern.test(line.replace(/\/\/.*$/, ''))) found.push(file + ':' + (i + 1)) })
  return found
}

test('no rich-text, code-loading or network APIs', () => {
  assert.deepStrictEqual(offenders(/Text\.(RichText|StyledText|AutoText|MarkdownText)|\bAutoText\b|openUrlExternally|createQmlObject|createComponent|Qt\.include|\beval\(|new Function|XMLHttpRequest|WebEngine|WebSocket/), [])
})

test('no hard-coded remote URLs', () => {
  assert.deepStrictEqual(offenders(/https?:\/\/|ftp:\/\/|wss?:\/\//), [])
})

test('compositor commands only interpolate validated values', () => {
  // Addresses pass Model.windowAddress (hex only); workspace ids pass Number.isInteger checks.
  const allowed = new Set(['address', 'id', 'root.pendingWindow', 'root.pendingWorkspace'])
  const bad = []
  for (const [file, lines] of sources) lines.forEach((line, i) => {
    if (!/hl\.dsp\.|closewindow|focuswindow|"workspace "/.test(line)) return
    for (const match of line.matchAll(/'\s*\+\s*([A-Za-z_.]+)\s*\+\s*'|"\s*\+\s*([A-Za-z_.]+)/g)) {
      const name = match[1] || match[2]
      if (!allowed.has(name)) bad.push(file + ':' + (i + 1) + ' ' + name)
    }
  })
  assert.deepStrictEqual(bad, [])
})

test('processes are started from argument lists, never through a shell', () => {
  assert.deepStrictEqual(offenders(/\b(sh|bash|zsh)["']\s*,\s*["']-c|execDetached\(\s*["'`]|shell=True|os\.system|subprocess\.[A-Za-z_]+\([^)]*shell\s*=/), [])
  for (const file of ['reorder_workspaces.py', 'deploy.py', 'rollback.py']) {
    const text = fs.readFileSync(path.join(root, file), 'utf8')
    assert.ok(!/shell\s*=\s*True|os\.system|os\.popen/.test(text), file + ' must not use a shell')
  }
})

test('window addresses and icon sources go through the validators', () => {
  const service = fs.readFileSync(path.join(root, 'Service.qml'), 'utf8')
  assert.ok(/Model\.safeImageSource\(/.test(service))
  assert.ok(/Model\.windowAddress\(address\)/.test(service))
  for (const file of ['WindowPreview.qml']) {
    const text = fs.readFileSync(path.join(root, file), 'utf8')
    for (const line of text.split('\n')) if (/\bsource:/.test(line)) assert.ok(/service\.icon\(/.test(line), file + ' loads an image outside service.icon: ' + line.trim())
  }
})
