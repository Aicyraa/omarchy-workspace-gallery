# Publishing checklist

This working directory is a local Git repository on `main`. Feature/section commits track the implementation locally. No remote, push, or public release has been configured. Backups, local harnesses, logs, and machine-specific validation notes are ignored.

Before a public release:

- Choose a license and add LICENSE. Review author/name/id metadata and decide whether to retain the `jee` namespace.
- Review `git status --short`, `git diff`, and `git log --oneline` before publishing. Confirm personal backups and runtime artifacts remain ignored.
- Declare supported Omarchy/Quickshell/Hyprland versions and required system commands. The plugin uses the Omarchy host's `qs.Commons` palette, so it is intended to run inside that shell.
- Add a preview screenshot/GIF captured from a clean desktop, avoiding personal windows or network information.
- Document installation via `omarchy plugin add <repository-url> --enable --yes`, configuration, shortcuts, uninstall, and known limitations.
- Test installation in a fresh user configuration, including multiple displays, fractional scaling, missing hardware, and light/dark theme changes.
- Keep `deploy.py` as an explicit local customization tool: it updates user configuration. The Omarchy plugin installer does not run it automatically. Public installation should not silently replace another user's bar or bindings.
- Review the existing commits, configure your chosen remote, then publish when ready.

No license or hosting provider has been selected automatically.
