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

const defaults = {previewScale:1,animationDuration:300,reducedMotion:false,showKeyGuide:true,liveOtherWorkspaces:false,defaultView:'classic',pinnedWorkspaces:[]};
assert.deepEqual(plain(model.settings({})), {workspaceNames:{},...defaults});
assert.deepEqual(plain(model.settings({previewScale:8,animationDuration:1,reducedMotion:true})), {workspaceNames:{},...defaults,animationDuration:120,reducedMotion:true});
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

assert.deepEqual(plain(model.inverseWorkspaceOrder([1,2,3],[2,3,1])),[3,1,2]);
assert.deepEqual(plain(model.inverseWorkspaceOrder([1,2,3],[3,1,2])),[2,3,1]);
assert.equal(model.inverseWorkspaceOrder([1,2,3],[1,1,3]),null);

const moveCandidate = {workspace:{id:1},lastIpcObject:{pinned:false}};
assert.equal(model.canMoveWindow(moveCandidate,2,[1,2,3]),true);
assert.equal(model.canMoveWindow(moveCandidate,1,[1,2,3]),false);
assert.equal(model.canMoveWindow(moveCandidate,9,[1,2,3]),false);
assert.equal(model.canMoveWindow(null,2,[1,2,3]),false);
assert.equal(model.canMoveWindow({workspace:{id:1},lastIpcObject:{pinned:true}},2,[1,2,3]),false);

const moveUndo={kind:'window',address:'0xabcd',from:1,to:2,pid:42};
assert.equal(model.canUndoWindowMove(moveUndo,{address:'abcd',workspace:{id:2},lastIpcObject:{pid:42}}),true);
assert.equal(model.canUndoWindowMove(moveUndo,null),false);
assert.equal(model.canUndoWindowMove(moveUndo,{address:'abcd',workspace:{id:3},lastIpcObject:{pid:42}}),false);
assert.equal(model.canUndoWindowMove(moveUndo,{address:'abcd',workspace:{id:2},lastIpcObject:{pid:99}}),false);

// Search also matches the workspace name.
assert.equal(model.matches('design', 'Untitled', 'Editor', 'editor', 'Design'), true);
assert.equal(model.matches('design', 'Untitled', 'Editor', 'editor', 'Mail'), false);

// New preferences are validated.
assert.equal(model.settings({showKeyGuide:false}).showKeyGuide, false);
assert.equal(model.settings({showKeyGuide:'no'}).showKeyGuide, true);
assert.equal(model.settings({liveOtherWorkspaces:true}).liveOtherWorkspaces, true);
assert.equal(model.settings({liveOtherWorkspaces:'yes'}).liveOtherWorkspaces, false);
assert.equal(model.settings({defaultView:'orbit'}).defaultView, 'orbit');
assert.equal(model.settings({defaultView:'<img src=x>'}).defaultView, 'classic');
assert.deepEqual(plain(model.settings({pinnedWorkspaces:[3,1,1,'2',-4,2.5,0,100001,5]}).pinnedWorkspaces), [1,3,5]);
assert.deepEqual(plain(model.settings({pinnedWorkspaces:'1'}).pinnedWorkspaces), []);
assert.deepEqual(plain(model.cleanPinned(Array.from({length: 300}, (_, i) => i + 1))).length, 100);
assert.deepEqual(plain(model.togglePinned([1], 3)), [1,3]);
assert.deepEqual(plain(model.togglePinned([1,3], 3)), [1]);
assert.deepEqual(plain(model.togglePinned([], 'x')), []);

// Pinned workspaces keep their position while the others reorder around them.
assert.deepEqual(plain(model.insertWorkspacePinned([1,2,3,4,5], 1, 4, [3])), [2,4,3,5,1]);
assert.deepEqual(plain(model.insertWorkspacePinned([1,2,3,4,5], 5, 0, [1])), [1,5,2,3,4]);
assert.deepEqual(plain(model.insertWorkspacePinned([1,2,3], 3, 0, [3])), [1,2,3]);
assert.deepEqual(plain(model.insertWorkspacePinned([1,2,3], 9, 0, [])), [1,2,3]);
assert.deepEqual(plain(model.insertWorkspacePinned([1,2,3,4], 2, 3, [])), plain(model.insertWorkspace([1,2,3,4], 2, 3)));
{
  const slots = [1,2,3,4,5], pinned = [2, 4];
  for (const id of slots) for (let index = 0; index < slots.length; index++) {
    const order = plain(model.insertWorkspacePinned(slots, id, index, pinned));
    assert.deepEqual([...order].sort(), slots, 'always a permutation');
    for (const p of pinned) assert.equal(order.indexOf(p), slots.indexOf(p), 'pinned stays put');
  }
}

// Icon sources must stay local.
assert.equal(model.safeImageSource('image://icon/firefox'), 'image://icon/firefox');
assert.equal(model.safeImageSource('/usr/share/icons/a.png'), '/usr/share/icons/a.png');
assert.equal(model.safeImageSource('file:///usr/share/icons/a.png'), 'file:///usr/share/icons/a.png');
for (const bad of ['https://example.com/a.png', 'http://x/y', 'ftp://x', '//attacker/share/a.png', 'qrc:/x', 'data:image/png;base64,AA', '', null, undefined])
  assert.equal(model.safeImageSource(bad), '');

// Fresh workspace numbers and IPC order payloads.
assert.equal(model.nextWorkspaceId([1,2,5]), 6);
assert.equal(model.nextWorkspaceId([]), 1);
assert.equal(model.nextWorkspaceId([100000]), 0);
assert.deepEqual(plain(model.parseOrderPayload('{"order":[2,1]}')), [2,1]);
for (const bad of ['', 'nope', '{}', '{"order":"12"}', '{"order":[]}', '{"order":[1,"2"]}', '{"order":[1.5]}', '{"order":' + JSON.stringify(Array.from({length: 101}, (_, i) => i + 1)) + '}', 'null'])
  assert.equal(model.parseOrderPayload(bad), null);
console.log('Pinning, icon source, new workspace, and IPC payload validation passed.');
