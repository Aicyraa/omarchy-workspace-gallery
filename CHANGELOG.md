# Changelog

## 1.3.0

### Security
- Window titles, workspace names and status messages are always drawn as plain text, so markup in a title can no longer make the shell fetch a remote image.
- App icons are only loaded from local sources.
- IPC `reorder` rejects anything but a short list of integers instead of throwing.
- The reorder helper keeps the permissions of `shell.json`, keeps its state folder private, and no longer writes window titles into its recovery journals.
- A stuck workspace reorder now times out after 30 seconds, so the overview, which holds exclusive keyboard focus, can always be closed.
- `rollback.py` now removes the shortcut block that `deploy.py` writes, backs up both files first and writes atomically.

### Added
- Close a window from its preview with the × button or a middle click, or press Delete on the selected window. The button only arms after the pointer rests on the preview.
- Move the selected window to the previous or next workspace with Shift + Left / Right.
- Jump with Alt + 1–9, Home and End. Ctrl + N opens a new workspace, and the new `+` tab does the same.
- Pin a workspace with Ctrl + P so reordering leaves it in place.
- The current workspace is marked in the previews and tabs. Every window preview shows its app icon.
- Search also matches workspace names.
- Preferences for the key guide (F1 toggles it), for opening in the ring view, and for keeping other workspaces' previews live (video and animations keep moving; off by default), and a high-quality preview mode that filters shrunken captures properly (off by default).
- Larger ring cards (about 25% bigger on a 1366×768 screen), a selection outline and stronger depth fade in the ring, and two-finger horizontal swipes change workspace there.
- GitHub Actions run the model, helper and UI tests, plus static guards for rich text, remote URLs, shell use and compositor command inputs.

### Fixed
- Ctrl + scroll zoom and plain scrolling now work on touchpads and mice.
- The reorder helper is found when the plugin path contains spaces.

## 1.2.0
- Searchable, named workspace previews, the 3D ring view, drag to move windows, and workspace reordering with undo.
