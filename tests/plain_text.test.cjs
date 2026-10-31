// Window titles and other app-controlled strings must never be parsed as rich text:
// Qt's automatic detection would fetch remote <img> sources when the overview opens.
const test = require('node:test')
const assert = require('node:assert')
const fs = require('node:fs')
const path = require('node:path')

const root = path.join(__dirname, '..')
const files = fs.readdirSync(root).filter(f => f.endsWith('.qml'))
const untrusted = /\.title\b|windowDragTitle|windowMoveFeedback|settingsError|reorderNotice|tab\.modelData/

test('Text items showing app-controlled strings use Text.PlainText', () => {
  const offenders = []
  for (const file of files) {
    const lines = fs.readFileSync(path.join(root, file), 'utf8').split('\n')
    lines.forEach((line, i) => {
      const bound = /\btext:/.test(line) && untrusted.test(line)
      if (!bound) return
      // textFormat may sit on the same line or within the next few lines of a multi-line item.
      const block = lines.slice(Math.max(0, i - 4), i + 5).join('\n')
      if (!/textFormat:\s*Text\.PlainText/.test(block)) offenders.push(file + ':' + (i + 1))
    })
  }
  assert.deepStrictEqual(offenders, [])
})
