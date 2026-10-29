#!/usr/bin/env python3
"""Disable this plugin and restore the original shortcut without replacing other settings."""
import json
from pathlib import Path
import re
home = Path.home()
source = Path(__file__).resolve().parent
backups = sorted((source / 'backups').glob('*/bindings.lua'))
if not backups:
    raise SystemExit('No activation backup found')
config = home / '.config/omarchy/shell.json'
cfg = json.loads(config.read_text())
cfg['plugins'] = [p for p in cfg.get('plugins', []) if p.get('id') != 'jee.overview']
config.write_text(json.dumps(cfg, indent=2) + '\n')
bindings = home / '.config/hypr/bindings.lua'
text = re.sub(r'\n-- >>> jee\.overview\n.*?-- <<< jee\.overview\n?', '\n', bindings.read_text(), flags=re.S)
old = backups[0].read_text()
block = re.search(r'-- >>> aerial.*?-- <<< aerial', old, re.S)
if block and '-- >>> aerial' not in text:
    text = text.rstrip() + '\n\n' + block.group(0) + '\n'
bindings.write_text(text)
print('Disabled jee.overview; restored the previous shortcut. Run hyprctl reload and hyprctl configerrors.')
