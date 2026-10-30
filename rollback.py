#!/usr/bin/env python3
"""Disable this plugin and restore the original shortcut without replacing other settings."""
import json
import argparse
from pathlib import Path
import re
parser = argparse.ArgumentParser(description='Disable io.github.aicyraa.workspace-gallery in shell.json and restore its backed-up Aerial shortcut.')
parser.add_argument('--apply-config', action='store_true', help='Explicitly consent to shell.json and Hyprland binding edits')
if not parser.parse_args().apply_config:
    parser.error('No files changed. Pass --apply-config to consent to the rollback configuration edits.')
home = Path.home()
source = Path(__file__).resolve().parent
backups = sorted((source / 'backups').glob('*/bindings.lua'))
if not backups:
    raise SystemExit('No activation backup found')
config = home / '.config/omarchy/shell.json'
cfg = json.loads(config.read_text())
cfg['plugins'] = [p for p in cfg.get('plugins', []) if p.get('id') != 'io.github.aicyraa.workspace-gallery']
config.write_text(json.dumps(cfg, indent=2) + '\n')
bindings = home / '.config/hypr/bindings.lua'
text = re.sub(r'\n-- >>> io\.github\.aicyraa\.overview\n.*?-- <<< io\.github\.aicyraa\.overview\n?', '\n', bindings.read_text(), flags=re.S)
text = re.sub(r'\n-- >>> jee\.desktop-gallery\n.*?-- <<< jee\.desktop-gallery\n?', '\n', text, flags=re.S)
old = backups[0].read_text()
block = re.search(r'-- >>> aerial.*?-- <<< aerial', old, re.S)
if block and '-- >>> aerial' not in text:
    text = text.rstrip() + '\n\n' + block.group(0) + '\n'
bindings.write_text(text)
print('Disabled io.github.aicyraa.workspace-gallery; restored the previous shortcut. Run hyprctl reload and hyprctl configerrors.')
