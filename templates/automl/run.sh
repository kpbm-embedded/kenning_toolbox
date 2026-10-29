#!/bin/sh
# @NAME@: Kenning AutoML (AutoPyTorch, SMAC + Hyperband) on CATS within a board's RAM budget, then the RAM check of
# the returned models and a host test of the best one. Needs the optional env: kenning-box extra install automl.
# KENNING_BOX = the 32_07_kenning folder (default: $BOX_KENNING from box_env.sh).
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
kb=${KENNING_BOX:-${BOX_KENNING:?set BOX_KENNING or KENNING_BOX to the 32_07_kenning folder}}
dry=""; [ "${1:-}" = --dry-run ] && dry=--dry-run
cd "$here"
mkdir -p build
lib="$kb/examples/_lib"
plats="$("$kb/kenning-box" where | sed -n 's/^root  *//p')/cache/kenning/platforms/platforms.yml"
board=$(sed -n 's/^    name: \(.*\)$/\1/p' "@NAME@.yml" | head -1)
app=$(sed -n 's/^    application_size: \([0-9.]*\).*/\1/p' "@NAME@.yml" | head -1)
"$kb/kenning-box" $dry extra run automl timeout -k 30 1800 kenning automl --cfg "$here/@NAME@.yml" --verbosity INFO
[ -n "$dry" ] && exit 0
"$kb/kenning-box" run python -I "$lib/automl_conf.py" check build/automl "$plats" "$board" "$app" --md build/ram_check.md
"$kb/kenning-box" run python -I "$lib/automl_conf.py" derive build/automl/automl_conf_0.yml build/best.yml "$here/build/best.tflite"
"$kb/kenning-box" extra run automl kenning optimize test --cfg "$here/build/best.yml" \
  --measurements "$here/build/@NAME@_measurements.json" --verbosity WARNING
"$kb/kenning-box" run python -I "$lib/summarize.py" "$here/build/@NAME@_measurements.json"
