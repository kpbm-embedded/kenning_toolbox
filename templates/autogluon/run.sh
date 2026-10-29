#!/bin/sh
# @NAME@: AutoGluon TabularPredictor baseline (CPU, time-limited) on the CATS windows Kenning uses, optionally compared
# with Kenning measurements files: ./run.sh [kenning_measurements.json ...]. Host only: AutoGluon models have no
# TFLite/microTVM export. Needs: kenning-box extra install automl autogluon. KENNING_BOX = the 32_07_kenning folder.
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
kb=${KENNING_BOX:-${BOX_KENNING:?set BOX_KENNING or KENNING_BOX to the 32_07_kenning folder}}
dry=""; [ "${1:-}" = --dry-run ] && { dry=--dry-run; shift; }
cd "$here"
mkdir -p build
lib="$kb/examples/_lib"
seconds=60                      # AutoGluon time limit
# the same windows and split as the Kenning AutoML scenarios (seed 12345, 10 % test, window 5)
"$kb/kenning-box" $dry extra run automl python -I "$lib/cats_export.py" build/CATS build/cats.npz
if [ $# -gt 0 ]; then set -- --kenning "$@"; fi
"$kb/kenning-box" $dry extra run autogluon python -I "$lib/autogluon_baseline.py" build/cats.npz build/@NAME@ \
  --time-limit "$seconds" --cpus 8 "$@"
