<div align="center">

<img src="assets/logo.svg" width="96" alt="Workspace Gallery logo" />

# Workspace Gallery

Searchable workspace previews and a 3D workspace ring for Omarchy.

<p>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-yellow.svg"></a>
  <img alt="Version 1.3.0" src="https://img.shields.io/badge/version-1.3.0-8ab4f8">
  <img alt="Omarchy Quattro" src="https://img.shields.io/badge/Omarchy-Quattro-a78bfa">
  <img alt="Hyprland 0.56.2" src="https://img.shields.io/badge/Hyprland-0.56.2-58e1ff">
  <img alt="Quickshell 0.3.2" src="https://img.shields.io/badge/Quickshell-0.3.2-7ee787">
</p>

[Install](#install) · [Controls](#controls) · [Configuration](#configuration) · [Troubleshooting](#troubleshooting)

</div>

<p align="center">

https://github.com/user-attachments/assets/26bdeebb-0f9c-48dc-b6ae-9da0cce2a47e

</p>

---

### Features

| Feature | Description |
| --- | --- |
| Two views | The normal overview, or a 3D workspace ring. |
| Search | Find windows by title, app name, class, or workspace name. |
| Reorder and pin | Drag workspace tabs. Pinned workspaces stay where they are. |
| Move, close and undo | Drag or key-move windows between workspaces, close them from their preview, and undo up to 20 actions. |
| Current workspace | The workspace you are on is outlined and labelled. |
| New workspace | Open the next free workspace from the `+` tab. |
| Names and motion | Name workspaces. Adjust preview size, duration, and reduced motion. |
| Key guide | A shortcut legend you can hide with <kbd>F1</kbd>. |

---

### Requirements

- Omarchy Quattro shell, Hyprland `0.56.2`, Quickshell `0.3.2`, Qt `6.9+`
- `omarchy`, `omarchy-shell`, `hyprctl`, and `python3` on your PATH

No extra packages, accounts, or network services.

---

### Install

```sh
omarchy plugin add https://github.com/Aicyraa/omarchy-workspace-gallery.git --enable
```

Optional shortcuts, added to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + W", "Workspace overview", "omarchy-shell shell toggle io.github.aicyraa.workspace-gallery")
o.bind("SUPER + SHIFT + CTRL + W", "Workspace ring", "omarchy-shell io.github.aicyraa.workspace-gallery.perspective toggle")
```

Then apply and check:

```sh
hyprctl reload
hyprctl configerrors
```

---

### Controls

| Action | Input |
| --- | --- |
| Switch workspace | <kbd>←</kbd> <kbd>→</kbd>, scroll, two-finger swipe, or click a tab |
| Jump to a workspace | <kbd>Alt</kbd> + <kbd>1</kbd>–<kbd>9</kbd>, <kbd>Home</kbd>, or <kbd>End</kbd> |
| New workspace | <kbd>Ctrl</kbd> + <kbd>N</kbd> or the `+` tab |
| Pin or unpin a workspace | <kbd>Ctrl</kbd> + <kbd>P</kbd> |
| Move the selected window | <kbd>Shift</kbd> + <kbd>←</kbd> <kbd>→</kbd> |
| Close the selected window | <kbd>Delete</kbd>, the × button, or middle-click |
| Show or hide the key guide | <kbd>F1</kbd> |
| Select window | <kbd>Tab</kbd> or <kbd>Shift</kbd> + <kbd>Tab</kbd> |
| Open workspace or window | <kbd>Enter</kbd> or click |
| Search | Type, or <kbd>Ctrl</kbd> + <kbd>F</kbd> |
| Rename workspace | <kbd>F2</kbd> or click the label |
| Preferences | <kbd>Ctrl</kbd> + <kbd>,</kbd> or the gear button |
| Undo | <kbd>Ctrl</kbd> + <kbd>Z</kbd> |
| Close | <kbd>Esc</kbd> |
| Orbit the ring | Drag the background, or right-drag |
| Zoom the ring (1× to 2×) | <kbd>Ctrl</kbd> + scroll, or trackpad pinch |
| Reset the view | Double-click the background |

Drag a window preview onto another workspace to move it. Closing a window sends the application a normal close request, so it can still ask to save. The × button appears after the pointer rests on a preview for a moment, so a quick tap never closes anything.

---

### Configuration

- **Rename:** <kbd>F2</kbd>. Names are up to 48 characters. An empty name restores `Workspace N`.
- **Preview size:** 65–100%.
- **Transition:** 120–500 ms, or reduced motion.
- **Key guide:** show or hide the shortcut legend.
- **Open in ring view:** start in the 3D ring instead of the flat overview.
- **Pinned workspaces:** <kbd>Ctrl</kbd> + <kbd>P</kbd> keeps a workspace's position when others are reordered.

Settings are saved in this plugin's entry in `~/.config/omarchy/shell.json`.

---

### Privacy

- Plugins run **unsandboxed** with your permissions. Review the code before you enable it.
- Window previews stay in memory and are never saved to disk.
- Nothing is sent to a remote service. Window titles and workspace names are drawn as plain text, so markup in a title is never interpreted or fetched.
- Closing a window sends a standard close request and moves or renumbers only what you ask for.
- Recovery journals are kept in `~/.local/state/omarchy/workspace-reorder/`. They hold workspace numbering, names and window counts, never window titles, and the last 20 are kept.

---

### Update and remove

```sh
omarchy plugin update io.github.aicyraa.workspace-gallery
omarchy plugin remove io.github.aicyraa.workspace-gallery
```

After removing, delete any shortcut lines you added and run `hyprctl reload`. Removal does not undo completed window moves or workspace renumbering.

If the shell still shows old QML after an update, run `omarchy restart shell`. This briefly restarts the bar.

<details>
<summary>Optional deployment helpers</summary>

<br>

`deploy.py` and `rollback.py` change your shell config and keybindings. They run only with `--apply-config`. Review them before you use them.

</details>

---

### Troubleshooting

| Problem | Fix |
| --- | --- |
| Plugin does not load | `omarchy plugin validate ~/.config/omarchy/plugins/io.github.aicyraa.workspace-gallery` |
| Old UI still shows | `omarchy restart shell` |
| Previews are blank | Check `qs log -p /usr/share/omarchy/shell --tail 100` for capture errors. |

Logs can contain window titles, so redact them before you share them. Report issues on [GitHub](https://github.com/Aicyraa/omarchy-workspace-gallery/issues).

Not fully tested: multi-monitor reconnection and fractional scaling.

---

### Development

```sh
omarchy plugin validate .
node --test tests/model.test.cjs
python3 tests/reorder_test.py
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic \
  /usr/lib/qt6/bin/qmltestrunner -input tests/ui -import tests/ui/imports -o -,txt
```

Regenerate the preview images from a Wayland session with `bash tools/preview/render.sh`.

---

### License

MIT © 2026 Aicyraa. See [LICENSE](LICENSE).

Marketplace approval covers the listing only. It is not a security review.
