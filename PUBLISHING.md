# Publishing Workspace Gallery

Release checklist for [`Aicyraa/omarchy-overview`](https://github.com/Aicyraa/omarchy-overview).

| Field | Value |
| --- | --- |
| Plugin ID | `io.github.aicyraa.workspace-gallery` — permanent; replaces the earlier `io.github.aicyraa.overview` and `jee.overview`; settings under old IDs do not carry over |
| Version | `1.2.0` |
| Author | Aicyraa |
| License | MIT |
| Repository | Public; verified through the GitHub API on 2026-10-29 |
| Submission status | Preparation in progress; no marketplace listing submitted |

Follow the official [development guide](https://plugins.omarchy.org/develop.html) and [publishing guide](https://plugins.omarchy.org/publish.html). The marketplace validates the commit available in the public repository, so the release files must be committed and pushed before submission.

## Required submission checklist

- [x] Public repository exists. README documents installation, optional setup, updates, removal, and dependencies. Revised release files are prepared locally and still need to be pushed.
- [x] Author chose MIT. LICENSE is included, the manifest declares MIT, and the README covers runtime/test dependencies and external services.
- [x] Author explicitly confirmed ownership or permission to submit the code and assets on 2026-10-29. Preview content is original and contains no personal desktop captures or third-party artwork.
- [x] No silent configuration replacement during installation. The manager handles activation; the optional deployment/rollback helpers require `--apply-config`. Preference saves and workspace-name remapping follow user actions and are documented.
- [ ] Author acknowledges that approval is for listing and is not a security review. Plugins run unsandboxed with the user's permissions.

Only the author can confirm the remaining declaration. Do not mark it complete based on repository access or technical validation.

## Release checks

| Check | Status |
| --- | --- |
| Root manifest and entry points | `omarchy plugin validate .` passes. |
| License, README, dependency declarations | Prepared; README links and metadata checked locally. |
| Automated checks | JavaScript model assertions, 5 Python transaction tests, and 23 Qt test cases pass. |
| Local compositor behavior | Activation, ring switching, workspace reorder/Undo, window move/Undo, empty guides, and unchanged desktop geometry checked. Lower camera default inspected after shell restart. |
| Preview assets | Three full-HD staged renders generated and visually reviewed; provenance and reproduction instructions included. |
| Configuration consent | Both helpers refuse execution without `--apply-config`; Python compilation passed. |
| Repository hygiene | `git diff --check` passes; no repository symlinks found. Backups, logs, and personal configuration snapshots are ignored. Recheck the final staged file list. |
| Clean-user install and removal | **Pending.** Do not remove the author's active installation to test this. |
| Display compatibility | Physical multi-monitor reconnection and fractional scaling remain unverified. |
| Commit and push | **Pending.** Group visual/interaction work, consent changes, and publication assets/docs into separate sections. |
| Marketplace submission | **Pending.** Separate action after the release is ready. |

These checks describe actual evidence, not a guarantee for every GPU, theme, host version, or display configuration. Qt pointer tests use capture fixtures and do not establish native capture compatibility on their own.

## Preview assets

| File | Contents |
| --- | --- |
| [`preview.png`](preview.png) | Interactive workspace ring at its starting viewpoint. |
| [`assets/previews/overview.png`](assets/previews/overview.png) | Normal overview with editor and terminal samples. |
| [`assets/previews/empty-workspace.png`](assets/previews/empty-workspace.png) | Empty workspace with dashed guide in the ring. |

Each image is 1920 × 1080. They render the production components with original staged sample windows, rather than capturing personal applications. The images, fixture content, and renderer are MIT licensed, Copyright © 2026 Aicyraa. See [asset provenance and regeneration instructions](assets/previews/README.md).

A preview is optional for the marketplace. If replacing these images, inspect window titles, browser tabs, account names, and documents before publishing. Keep attribution and license notices for any reused assets.

## Before committing

1. Complete the author declaration above and the clean-user installation/removal check, or explicitly document any unresolved verification before deciding on release readiness.
2. Validate the manifest and run the README checks. Inspect QML against the installed shell imports; existing unqualified-access lint warnings in the window delegate have not been treated as a clean lint pass.
3. Review `git diff --check`, `git diff`, and the staged file list. Keep backups, credentials, runtime logs, private screenshots, and personal configuration out of the commits.
4. Commit by section and review the resulting history. Do not run the deployment helpers merely to validate packaging.

## Submit the listing

1. Push the reviewed commits to the public repository. Confirm the remote contains the manifest, LICENSE, updated README, runtime entry points, and selected preview assets.
2. Open the submission issue form linked from the official publishing guide.
3. Supply the repository URL, category, and tags that describe a workspace-management overlay.
4. Confirm the submission declarations personally. Listing approval is not a security audit, and no approval or marketplace submission is implied by this checklist.
