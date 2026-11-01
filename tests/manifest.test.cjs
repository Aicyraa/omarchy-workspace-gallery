// The manifest is what the plugin host reads first, so keep it consistent with the repo.
const test = require('node:test')
const assert = require('node:assert')
const fs = require('node:fs')
const path = require('node:path')

const root = path.join(__dirname, '..')
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'))

test('manifest has the required identity fields', () => {
  assert.equal(manifest.schemaVersion, 1)
  assert.match(manifest.id, /^[a-z0-9]+(\.[a-z0-9-]+)+$/)
  assert.ok(manifest.name && manifest.author && manifest.description)
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/)
  assert.equal(manifest.license, 'MIT')
})

test('entry points exist and match the declared kinds', () => {
  for (const kind of manifest.kinds) {
    const file = manifest.entryPoints[kind]
    assert.ok(file, kind + ' kind needs an entry point')
    assert.ok(fs.existsSync(path.join(root, file)), file + ' is missing')
  }
})

test('every QML component in qmldir exists', () => {
  const lines = fs.readFileSync(path.join(root, 'qmldir'), 'utf8').split('\n').map(l => l.trim()).filter(Boolean)
  for (const line of lines) {
    const file = line.split(/\s+/).pop()
    assert.ok(fs.existsSync(path.join(root, file)), file + ' is listed in qmldir but missing')
  }
})

test('the changelog documents the current version', () => {
  const changelog = fs.readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8')
  assert.ok(changelog.includes('## ' + manifest.version), 'CHANGELOG.md has no entry for ' + manifest.version)
})

test('the README install command points at the repository', () => {
  const readme = fs.readFileSync(path.join(root, 'README.md'), 'utf8')
  assert.ok(readme.includes('omarchy plugin add https://github.com/Aicyraa/omarchy-workspace-gallery.git'))
})
