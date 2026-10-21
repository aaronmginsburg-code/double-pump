#!/usr/bin/env bash
# Rebuild the whole asset from scratch. Needs a Python with the `bpy` module
# (pip install bpy==5.2.2, Python 3.13) or run each script with
#   blender -b --python <script>.py
# Env: BAKE_RES (default 2048), BAKE_SAMPLES (24), PY (python with bpy).
set -euo pipefail
cd "$(dirname "$0")"
PY="${PY:-python}"
for s in 01_blockout 02_build_master 03_bake_textures 04_animate 05_variants 06_export 07_render 08_validate; do
  echo "=== $s"
  "$PY" "$s.py"
done
