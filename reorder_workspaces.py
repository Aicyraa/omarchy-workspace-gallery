#!/usr/bin/python3
"""Renumber workspace identities without moving individual windows or layouts."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

def permutation(slots, order):
    if not isinstance(slots, list) or not isinstance(order, list) or not slots or len(slots) > 100:
        raise ValueError('Invalid workspace order')
    if any(type(i) is not int or i < 1 or i > 100000 for i in slots + order):
        raise ValueError('Invalid workspace ID')
    if slots != sorted(set(slots)) or sorted(order) != slots:
        raise ValueError('Order must be a permutation of the workspace slots')
    return {old: slots[index] for index, old in enumerate(order) if old != slots[index]}

def query():
    return json.loads(subprocess.check_output(['hyprctl', 'workspaces', '-j'], timeout=5))

def change_id(source, target):
    command = 'hl.dsp.workspace.change_id({workspace="%d",id=%d})' % (source, target)
    result = subprocess.run(['hyprctl', 'dispatch', command], capture_output=True, text=True, timeout=5)
    if result.returncode or result.stdout.strip() != 'ok':
        raise RuntimeError(result.stdout.strip() or result.stderr.strip() or 'Workspace renumber failed')

def transact(mapping, snapshot, change, journal):
    existing = {w['id'] for w in snapshot}
    originals = [old for old in mapping if old in existing]
    spare = max(existing | set(mapping) | set(mapping.values()) | {1000}) + 100
    moves = []
    try:
        for index, old in enumerate(originals):
            change(old, spare + index)
            moves.append((old, spare + index)); journal(moves)
        for index, old in enumerate(originals):
            change(spare + index, mapping[old])
            moves.append((spare + index, mapping[old])); journal(moves)
    except Exception as error:
        errors = []
        for source, target in reversed(moves):
            try: change(target, source)
            except Exception as recovery: errors.append(str(recovery))
        raise RuntimeError(str(error) + ('; recovery errors: ' + '; '.join(errors) if errors else '; original numbering restored'))
    return moves

def main():
    data = json.loads(sys.argv[1])
    mapping = permutation(data['slots'], data['order'])
    state = Path.home() / '.local/state/omarchy/workspace-reorder'
    state.mkdir(parents=True, exist_ok=True)
    with (state / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        snapshot = query()
        stamp = str(time.time_ns())
        record = state / ('transaction-' + stamp + '.json')
        def journal(moves):
            fd, name = tempfile.mkstemp(dir=state)
            with os.fdopen(fd, 'w') as output:
                json.dump({'mapping': mapping, 'workspaces': snapshot, 'completedMoves': moves}, output)
            os.replace(name, record)
        journal([])
        moves = transact(mapping, snapshot, change_id, journal)
        # Keep custom names with their workspace, preserving unrelated config.
        try:
            config_path = Path.home() / '.config/omarchy/shell.json'
            config = json.loads(config_path.read_text())
            entry = next((e for e in config.get('plugins', []) if isinstance(e, dict) and e.get('id') == 'io.github.aicyraa.workspace-gallery'), None)
            old_names = dict(entry.get('workspaceNames', {})) if entry else {}
            names = {str(mapping.get(int(key), int(key))): value for key, value in old_names.items() if str(key).isdigit()}
            if entry is not None and names != old_names:
                entry['workspaceNames'] = names
                fd, temporary = tempfile.mkstemp(dir=config_path.parent, prefix='.reorder-config-')
                try:
                    with os.fdopen(fd, 'w') as output: json.dump(config, output, indent=2); output.write('\n')
                    os.replace(temporary, config_path)
                finally:
                    if os.path.exists(temporary): os.unlink(temporary)
        except Exception:
            for source, target in reversed(moves): change_id(target, source)
            raise
        # Numeric workspace names should track their new numeric identity.
        for workspace in snapshot:
            old = workspace['id']
            if old in mapping and workspace.get('name') == str(old):
                new = mapping[old]
                subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.workspace.rename({workspace="%d",name="%d"})' % (new, new)], capture_output=True, timeout=5)
        for old in sorted(state.glob('transaction-*.json'), reverse=True)[20:]: old.unlink()
        print(json.dumps({'ok': True, 'mapping': mapping, 'names': names}))

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'ok': False, 'error': str(error)}))
        sys.exit(1)
