#!/bin/sh
# Benchmark your own compiled model ./model.tflite (+ model.tflite.json I/O spec) with ModelInserter.
# KENNING_BOX = the 32_07_kenning folder (default: $BOX_KENNING from box_env.sh).
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
kb=${KENNING_BOX:-${BOX_KENNING:?set BOX_KENNING or KENNING_BOX to the 32_07_kenning folder}}
dry=""; [ "${1:-}" = --dry-run ] && dry=--dry-run
cd "$here"
mkdir -p build
# use kenning-box's copy of the dataset (offline) when this folder has none
ds="$("$kb/kenning-box" where | sed -n 's/^build  *//p')/datasets/MagicWandDataset"
[ -e build/MagicWandDataset ] || [ ! -d "$ds" ] || ln -s "$ds" build/MagicWandDataset
if [ ! -e model.tflite ]; then
  # no model of your own yet: make one with Kenning (also writes model.tflite.json, the I/O spec Kenning needs)
  echo "no ./model.tflite: creating a demo int8 model (make_demo_model.json)"
  "$kb/kenning-box" $dry kenning optimize --cfg "$here/make_demo_model.json"
fi
exec "$kb/kenning-box" $dry scenario "$here/@NAME@.json" --measurements "$here/build/@NAME@_measurements.json"
