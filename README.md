# Workspace Overview

User-owned Omarchy plugin `jee.overview`. Working source lives here; installed files live in `~/.config/omarchy/plugins/jee.overview/`.

Super + Shift + W opens the overview. Left/right selects a workspace, Tab/Shift+Tab selects a window, Enter activates, and Escape dismisses. Click the top indicator to select a workspace or a window to focus it. The selected window is raised above overlapping previews.

The dock has been removed from both the desktop and overview. Workspace previews have no outer container or padding: only the windows are rendered. Switching defaults to a 300 ms eased slide, lift, scale and slight tilt, with dimmed neighbors. Arrow keys, the top indicator, and the mouse wheel select workspaces. Existing workspace navigation and live previews remain available. Preview captures exist only while the overview is open; screenshots are never saved.

## Workspace names

The bottom label shows the selected workspace name. Click it or press **F2** to edit. **Enter** or the checkmark saves; **Escape** cancels. Saving an empty name restores `Workspace N`. Names are limited to 48 characters and displayed as plain text. Names are saved by workspace ID, so numeric shortcuts continue to work across shell restarts.

## Search

Start typing or press **Ctrl + F** to search windows by title, desktop-entry application name, or application class. Search is case-insensitive, matches every word, and spans workspaces on the focused monitor. Only workspaces with results appear while searching. **Tab / Shift + Tab** selects a result within the preview and **Enter** focuses it. Enter with no matches has no effect. **Escape** clears search first; a second Escape closes the overview. Use Down to leave the search input for workspace arrow navigation.

## Preferences

Click the gear or press **Ctrl + ,** for preview size (65–100%), transition duration (120–500 ms), and reduced motion. Reduced motion disables animated transitions and tilt. The controls support mouse and keyboard; Escape closes preferences without closing the overview.

Names and preferences are stored inline on the `jee.overview` entry in `~/.config/omarchy/shell.json`, for example:

```json
{
  "id": "jee.overview",
  "workspaceNames": {"1": "Code", "2": "Research"},
  "previewScale": 0.9,
  "animationDuration": 240,
  "reducedMotion": false
}
```

Each save preserves the other settings on the entry. This version does not include window dragging.

## Tests

Run `node tests/model.test.cjs` from this directory. The tests cover naming, resets, search matching, invalid preference values and bounds. Live checks cover editing/cancellation, persistence after a shell restart, app search, zero-result activation, keyboard preference saves, and capture cleanup.

## Update

Run `python ~/Work/omarchy-overview/deploy.py`, then `omarchy restart shell`. The installer backs up configuration and the existing plugin in timestamped `backups/` before replacing files. Persistent services require a shell restart to load changed code.

## Rollback

Run `python ~/Work/omarchy-overview/rollback.py`, then `omarchy restart shell`, `hyprctl reload`, and `hyprctl configerrors`. This disables the overview and restores the original Aerial shortcut, preserving unrelated configuration.

## Diagnostics

`omarchy-shell shell call jee.overview diagnostics ''` reports open state, capture counts, selected workspace and window count. Closed state should report zero captures.

The plugin now uses the host `qs.Commons` theme module. Validate it inside the Omarchy shell; local development harnesses are excluded from publication.

See VALIDATION.md for earlier rollout checks. Display reconnection and fractional scaling still need physical testing.

Colors are derived live from the host Omarchy palette through `ThemeTokens.qml`, including accents, surfaces, text, and focus states. No personal theme colors are baked into the plugin.

## Public installation

After a repository is published, install it through `omarchy plugin add <repository-url> --enable --yes`. The repository URL is intentionally unspecified until publishing. The plugin manager does not run `deploy.py`; that script applies this workstation's opinionated layout and shortcuts.

Summon it with `omarchy-shell shell toggle jee.overview`. Add a shortcut in your personal Hyprland bindings; this workstation uses Super + Shift + W. The plugin requires native Hyprland window capture and the Omarchy shell host.

### Elevated workspace perspective

Open the normal overview with **Super + Shift + W**. While it is open,
**Super + Shift + Ctrl + W** raises the perspective into the workspace ring;
press the same shortcut again to return. It does nothing outside the overview.
The selected workspace is preserved across the transition. The top bar stays mapped underneath the fullscreen overlay.

Drag the backdrop or scroll to rotate the ring. Click a side card to bring it
forward, then click a window to focus it or press Enter to enter the workspace.
Escape closes the overview. Reduced motion bypasses camera tilt and animation.

Diagnostic controls:
`omarchy-shell jee.overview.perspective toggle`
`omarchy-shell jee.overview.perspective status`

The elevated perspective uses a low 14-degree camera pitch and smaller,
more widely spaced workspace scenes. Both perspectives share the normal
workspace indicators, name editor, preferences, and theme. Workspaces have
no enclosing panel, wallpaper sheet, or border; their windows form the scene.

Workspace activation now releases overlay focus before switching desktops,
then focuses a still-valid window using a normalized Hyprland address. In the
elevated view, clicking a workspace enters it; drag or scroll to browse.

Workspace surfaces now face radially outward around the ring: side workspaces
are seen edge-on, and rear workspaces reveal their reverse side. The front
workspace faces the viewer. The camera is farther back with smaller scenes.

Preview quality: the ring renders each workspace into a 2× offscreen surface
(capped at 1280×720), with smooth filtering, mipmaps for angled/minified views,
and 4× edge sampling where supported by Qt's renderer. Captures retain native
window resolution. Only the selected workspace streams live frames, and the
extra render surfaces exist only while the elevated perspective is loaded.
This improves sampling rather than increasing the size of the preview cards.

### Drag to reorder workspaces

Drag the numbered tabs at the top of either overview. Neighboring tabs slide
aside to preview the insertion point; dropping commits the new order. This
renumbers real Hyprland workspace identities so Super+1…9 follows the new
positions. Windows retain their workspace grouping and layouts; custom names
follow the moved workspace. Workspace rules explicitly bound to a number
continue to apply to that number.

Renumbering uses unused temporary IDs to avoid collisions, records a small
transaction journal, and rolls completed steps back if an operation fails.
Custom-name changes are saved in the same operation. Dragging is disabled
while search is filtering workspaces or another reorder is being committed.
The normal desktop order is restored after integration tests.

Window previews now have square corners and no outline, with soft rectangular
shadows for elevation.

### Undo workspace reordering

After a reorder, an eight-second notice offers **Undo**. **Ctrl+Z** also undoes
the latest reorder while the overview is focused. Up to ten successful
reorders are retained for the current shell session, including across closing
and reopening the overview. Failed reorders do not consume history. Undo
restores numbering and custom-name mapping; it does not close or recreate apps.

### Move a window by dragging

In either perspective, drag a window from the selected workspace onto another
workspace tab or preview. Valid destinations highlight and the drag preview
shows the window title. Release to move the window without changing the active
desktop or closing the overview. Dropping outside a destination, dropping onto
the same workspace, or pressing Escape cancels. Pinned windows cannot be moved
this way. Ordinary clicks still focus windows. Tab rearranging is unavailable
while a window drag or move is in progress.

Validation covered the move dispatcher against live windows, preserving active
desktop/overview state and restoring the moved window afterward. Model tests
cover invalid, pinned, and same-workspace targets. Pointer drag/drop gestures
still need hands-on testing on each supported display scale.

### Fullscreen overlay without layout changes

The overview fills the entire output on the Wayland overlay layer, above
applications and the top bar. It ignores reserved areas and reserves no space
itself. The bar remains mapped underneath, retaining its normal reservation;
opening or closing the overview therefore does not resize application windows.
