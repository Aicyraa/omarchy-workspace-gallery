#!/usr/bin/env python3
"""Install/update only user-owned plugin files, backing up activation config first."""
import json
from pathlib import Path
import shutil
from datetime import datetime

source = Path(__file__).resolve().parent
home = Path.home()
config = home / '.config/omarchy/shell.json'
bindings = home / '.config/hypr/bindings.lua'
target = home / '.config/omarchy/plugins/jee.overview'
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
    if entry.get('id') == 'jee.overview':
        entry.pop('pins', None)
if not any(p.get('id') == 'jee.overview' for p in cfg.get('plugins', [])):
    cfg.setdefault('plugins', []).append({'id': 'jee.overview'})
config.write_text(json.dumps(cfg, indent=2) + '\n')
text = bindings.read_text()
start = text.find('-- >>> aerial')
end = text.find('-- <<< aerial', start)
if start >= 0 and end >= 0:
    text = text[:start] + text[end + len('-- <<< aerial'):]
if '-- >>> jee.overview' not in text:
    text = text.rstrip() + '''\n\n-- >>> jee.overview
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Workspace overview", "omarchy-shell shell toggle jee.overview")
-- <<< jee.overview
'''
if '-- >>> jee.desktop-gallery' not in text:
    gallery_command = 'omarchy-shell jee.overview.perspective toggle'
    text += '\n-- >>> jee.desktop-gallery\nhl.unbind("SUPER + SHIFT + CTRL + W")\no.bind("SUPER + SHIFT + CTRL + W", "Workspace orbit", ' + json.dumps(gallery_command) + ')\n-- <<< jee.desktop-gallery\n'
bindings.write_text(text)
print(f'Installed {target}\nBackups: {backup}')
