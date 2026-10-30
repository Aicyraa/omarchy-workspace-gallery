# Preview assets

These 1920×1080 images render the production WorkspaceScene, WindowPreview,
WorkspaceOrbit, WorkspaceTabs, and WorkspaceName components with staged sample
windows. The framing reproduces the normal and elevated overview layouts.
They are component previews, not captures of personal applications or proof of
compositor integration. The sample window content is original QML artwork and
text created for this project. No personal documents, account information,
third-party screenshots, stock artwork, or application logos are included.

- `../../preview.png`: interactive ring, starting camera angle.
- `overview.png`: normal overview with editor and terminal samples.
- `empty-workspace.png`: empty workspace in the ring, with dashed guide.

The images, fixture content, and renderer are covered by the repository's MIT
license, Copyright (c) 2026 Aicyraa.

Regenerate from a graphical Wayland session:

```sh
bash tools/preview/render.sh
```

This uses Qt Quick Test and a temporary rendering window, then saves the scene
directly as full-HD PNGs. The preview-only ScreencopyView fixture substitutes
staged content for native capture; the renderer does not capture the desktop,
move application windows, change configuration, or connect to a network.
Neither the fixture nor renderer is installed by `deploy.py` or imported by
the production plugin. Qt imports used for rendering are supplied by the shell
and the existing test fixture; no additional Python or image packages are needed.
