#!/bin/bash
# Regenera las capturas de los ajustes que usa la web (site/img/).
#
# Lanza el test de capturas dos veces, con la app en inglés y en español, porque
# algunos textos se traducen según el idioma de la app. Las capturas usan solo
# datos inventados: el test no pregunta nada a gh.
#
# Uso: scripts/screenshots.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/site/img"
cd "$ROOT"

mkdir -p "$OUT"
xcodegen generate --quiet

for lang in en es; do
  echo "▸ Capturas en '$lang'…"
  # Las variables TEST_RUNNER_* llegan al test sin el prefijo.
  TEST_RUNNER_GITSWITCHER_SCREENSHOTS_DIR="$OUT" \
  TEST_RUNNER_GITSWITCHER_SCREENSHOTS_LANG="$lang" \
  xcodebuild test -quiet \
    -project GitSwitcher.xcodeproj -scheme GitSwitcher \
    -derivedDataPath build -destination "platform=macOS" \
    -testLanguage "$lang" \
    "-only-testing:GitSwitcherTests/ScreenshotTests" \
    2>&1 | grep -E "error|✘|failed" || true
done

ls -1 "$OUT"/settings-*.png
