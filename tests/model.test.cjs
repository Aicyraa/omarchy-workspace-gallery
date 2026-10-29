const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../WorkspaceModel.js'), 'utf8').replace(/^\.pragma library\s*/, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

assert.equal(model.workspaceName(3, {}), 'Workspace 3');
assert.equal(model.workspaceName(3, {3: ' Design '}), 'Design');
const original = {1: 'Code', 2: 'Research'};
assert.deepEqual(plain(model.renamed(original, 2, '  Reading\n room  ')), {1:'Code', 2:'Reading room'});
assert.equal(original[2], 'Research');
assert.deepEqual(plain(model.renamed(original, 2, '  ')), {1:'Code'});
assert.deepEqual(plain(model.renamed(original, 2, 'Workspace 2')), {1:'Code'});
assert.deepEqual(plain(model.renamed({garbage:'bad', 1:42, 3:'Mail'}, 2, 'Notes')), {2:'Notes',3:'Mail'});
assert.equal(model.cleanName('x'.repeat(100)).length, 48);
assert.equal(model.cleanName('<Research>'), '<Research>'); // Displayed as plain text by the view.

assert.equal(model.matches('', 'Any title', '', ''), true);
assert.equal(model.matches('  DOC   CHROMIUM ', 'Documentation', 'Chromium', 'chromium'), true);
assert.equal(model.matches('DOC firefox', 'Documentation', 'Chromium', 'chromium'), false);
assert.equal(model.matches('[work]', 'Notes [work]', '', ''), true);
assert.equal(model.matches('résumé', 'RÉSUMÉ', '', ''), true);
assert.equal(model.matches('terminal', '', 'Terminal', 'org.omarchy.agent'), true);
assert.equal(model.matches('missing', null, undefined, ''), false);

assert.deepEqual(plain(model.settings({})), {workspaceNames:{},previewScale:1,animationDuration:300,reducedMotion:false});
assert.deepEqual(plain(model.settings({previewScale:8,animationDuration:1,reducedMotion:true})), {workspaceNames:{},previewScale:1,animationDuration:120,reducedMotion:true});
assert.equal(model.settings({previewScale:0.1}).previewScale, 0.65);
assert.equal(model.settings({animationDuration:900}).animationDuration, 500);
assert.equal(model.settings({previewScale:'bad',animationDuration:NaN,reducedMotion:'true'}).reducedMotion, false);
assert.deepEqual(plain(model.settings({workspaceNames:['Bad']})).workspaceNames, {});
console.log('Workspace names, persistence values, search matching, and preference validation passed.');

assert.equal(model.windowAddress('55ba291dc230'), '0x55ba291dc230');
assert.equal(model.windowAddress('0x55ba291dc230'), '0x55ba291dc230');
assert.equal(model.windowAddress(''), '');
assert.equal(model.windowAddress('garbage;exit'), '');

assert.deepEqual(plain(model.insertWorkspace([1,2,3,4],1,2)),[2,3,1,4]);
assert.deepEqual(plain(model.insertWorkspace([1,2,3,4],4,0)),[4,1,2,3]);
assert.deepEqual(plain(model.workspacePermutation([1,2,3],[2,3,1])),{'1':3,'2':1,'3':2});
assert.deepEqual(plain(model.remapWorkspaceNames({'1':'Code','2':'Web'},{'1':2,'2':1})),{'1':'Web','2':'Code'});
