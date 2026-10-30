#!/usr/bin/env python3
"""Install/update only user-owned plugin files, backing up activation config first."""
import json
import argparse
from pathlib import Path
import shutil
from datetime import datetime

parser = argparse.ArgumentParser(description="Back up and replace the installed plugin and edit shell.json and Hyprland bindings. For ordinary installation, use omarchy plugin add instead.")
parser.add_argument('--apply-config', action='store_true', help='Explicitly consent to configuration edits and replacing the installed plugin')
if not parser.parse_args().apply_config:
    parser.error('No files changed. Pass --apply-config to consent to the configuration changes described in README.md.')

source = Path(__file__).resolve().parent
home = Path.home()
config = home / '.config/omarchy/shell.json'
bindings = home / '.config/hypr/bindings.lua'
target = home / '.config/omarchy/plugins/io.github.aicyraa.workspace-gallery'
backup = source / 'backups' / datetime.now().strftime('%Y%m%d-%H%M%S')
backup.mkdir(parents=True)
shutil.copy2(config, backup / 'shell.json')
shutil.copy2(bindings, backup / 'bindings.lua')
if target.exists():
    shutil.copytree(target, backup / 'plugin')
target.mkdir(parents=True, exist_ok=True)
for name in ['manifest.json', 'ThemeTokens.qml', 'qmldir', 'Service.qml', 'WorkspaceModel.js', 'WorkspaceName.qml', 'OverviewSettings.qml', 'Overview.qml', 'WorkspaceOrbit.qml', 'WorkspaceScene.qml', 'WindowPreview.qml', 'WorkspaceTabs.qml', 'reorder_workspaces.py']:
    shutil.copy2(source / name, target / name)
shutil.copytree(source / "icons", target / "icons", dirs_exist_ok=True)
# Remove retired dock components only after the existing plugin is backed up.
for name in ['DesktopDock.qml', 'Dock.qml', 'DesktopGallery.qml']:
    (target / name).unlink(missing_ok=True)
cfg = json.loads(config.read_text())
for entry in cfg.get('plugins', []):
    if entry.get('id') == 'io.github.aicyraa.workspace-gallery':
        entry.pop('pins', None)
if not any(p.get('id') == 'io.github.aicyraa.workspace-gallery' for p in cfg.get('plugins', [])):
    cfg.setdefault('plugins', []).append({'id': 'io.github.aicyraa.workspace-gallery'})
config.write_text(json.dumps(cfg, indent=2) + '\n')
text = bindings.read_text()
start = text.find('-- >>> aerial')
end = text.find('-- <<< aerial', start)
if start >= 0 and end >= 0:
    text = text[:start] + text[end + len('-- <<< aerial'):]
if '-- >>> io.github.aicyraa.workspace-gallery' not in text:
    text = text.rstrip() + '''\n\n-- >>> io.github.aicyraa.workspace-gallery
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Workspace overview", "omarchy-shell shell toggle io.github.aicyraa.workspace-gallery")
-- <<< io.github.aicyraa.workspace-gallery
'''
if '-- >>> jee.desktop-gallery' not in text:
    gallery_command = 'omarchy-shell io.github.aicyraa.workspace-gallery.perspective toggle'
    text += '\n-- >>> jee.desktop-gallery\nhl.unbind("SUPER + SHIFT + CTRL + W")\no.bind("SUPER + SHIFT + CTRL + W", "Workspace orbit", ' + json.dumps(gallery_command) + ')\n-- <<< jee.desktop-gallery\n'
bindings.write_text(text)
print(f'Installed {target}\nBackups: {backup}')
