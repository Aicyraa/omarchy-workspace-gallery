#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
mkdir -p assets/previews
# The capture fixture is only on this preview renderer's import path.
# It is never installed or used by the production plugin.
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}" QT_QUICK_BACKEND=rhi \
QSG_RHI_BACKEND=opengl QT_QPA_PLATFORMTHEME= \
QT_QUICK_CONTROLS_STYLE=Basic /usr/lib/qt6/bin/qmltestrunner \
  -input tools/preview -import tests/ui/imports -import tools/preview/imports -o -,txt

for preview_file in preview.png assets/previews/overview.png assets/previews/empty-workspace.png; do
  test -s "$preview_file"
done
