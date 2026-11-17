#!/usr/bin/env bash
# Pantry Rat R02 - full rebuild (from this folder's parent: bash scripts/run_pipeline.sh <log dir>). Every step prints
# PANTRY_RAT_OK / PANTRY_RAT_FAIL; the chain stops at the first non-zero exit. build_pantry_rat.py rebuilds the .blend
# from nothing (drops clips and the dither UV0), so every later step must follow it.
set -u
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
D="${1:-review/round_06}"
mkdir -p "$D"
L="$D/pipeline_log.txt"; F="$D/pipeline_full.log"; : > "$L"; : > "$F"
run(){ echo "== $*" >> "$L"; "$B" -b --factory-startup "$@" >> "$F" 2>&1; e=$?; echo "exit $e" >> "$L"; return $e; }
run --python scripts/build_pantry_rat.py -- --no-renders &&
run source/PantryRat_R02.blend --python scripts/animate_pantry_rat.py &&
run source/PantryRat_R02.blend --python scripts/dither_uv_pantry_rat.py &&
run source/PantryRat_R02.blend --python scripts/write_rig_json.py &&
run source/PantryRat_R02.blend --python scripts/export_pantry_rat.py &&
run --python scripts/validate_roundtrip.py &&
run --python scripts/reopen_check.py &&
run source/PantryRat_R02.blend --python scripts/den_check.py
e=$?
cat "$L"
exit $e
