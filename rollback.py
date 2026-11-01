#!/usr/bin/env python3
"""Disable this plugin and restore the original shortcut without replacing other settings."""
import json
import argparse
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile
from datetime import datetime
parser = argparse.ArgumentParser(description='Disable io.github.aicyraa.workspace-gallery in shell.json and restore its backed-up Aerial shortcut.')
parser.add_argument('--apply-config', action='store_true', help='Explicitly consent to shell.json and Hyprland binding edits')
if not parser.parse_args().apply_config:
    parser.error('No files changed. Pass --apply-config to consent to the rollback configuration edits.')
def write_atomic(path, text):
    """Replace a file in one step, keeping its permissions."""
    path = path.resolve()
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.rollback-')
    try:
        with os.fdopen(fd, 'w') as output: output.write(text)
        os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)

home = Path.home()
source = Path(__file__).resolve().parent
backups = sorted((source / 'backups').glob('[0-9]*/bindings.lua'))
if not backups:
    raise SystemExit('No activation backup found')
config = home / '.config/omarchy/shell.json'
bindings = home / '.config/hypr/bindings.lua'
# Back up both files before touching them; the folder is private to this user.
saved = source / 'backups' / ('rollback-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
saved.mkdir(mode=0o700, parents=True)
shutil.copy2(config, saved / 'shell.json')
shutil.copy2(bindings, saved / 'bindings.lua')
cfg = json.loads(config.read_text())
cfg['plugins'] = [p for p in cfg.get('plugins', []) if p.get('id') != 'io.github.aicyraa.workspace-gallery']
write_atomic(config, json.dumps(cfg, indent=2) + '\n')
text = bindings.read_text()
for marker in ('io.github.aicyraa.workspace-gallery', 'io.github.aicyraa.overview'):
    text = re.sub(r'\n-- >>> ' + re.escape(marker) + r'\n.*?-- <<< ' + re.escape(marker) + r'\n?', '\n', text, flags=re.S)
text = re.sub(r'\n-- >>> jee\.desktop-gallery\n.*?-- <<< jee\.desktop-gallery\n?', '\n', text, flags=re.S)
old = backups[0].read_text()
block = re.search(r'-- >>> aerial.*?-- <<< aerial', old, re.S)
if block and '-- >>> aerial' not in text:
    text = text.rstrip() + '\n\n' + block.group(0) + '\n'
write_atomic(bindings, text)
print(f'Disabled io.github.aicyraa.workspace-gallery; restored the previous shortcut.\nBackups: {saved}\nRun hyprctl reload and hyprctl configerrors.')
