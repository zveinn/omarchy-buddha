#!/usr/bin/env bash
# Splice the shared lotus corner ornament (lotus-corner.glsl) into every mala
# ring shader -- the window rings (theme/aura) and each self-contained plugin's
# fx/ copy -- and recompile the .qsb files. Run after editing lotus-corner.glsl.
set -euo pipefail
cd "$(dirname "$0")/.."
QSB=${QSB:-/usr/lib/qt6/bin/qsb}
src=shaders/lotus-corner.glsl
for f in theme/aura/mala.frag plugins/*/fx/mala.frag; do
  awk -v src="$src" '
    /^\/\/ >>> lotus-corner/ { print; while ((getline l < src) > 0) print l; close(src); skip = 1; next }
    /^\/\/ <<< lotus-corner/ { skip = 0 }
    !skip { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
  echo "built $f.qsb"
done
