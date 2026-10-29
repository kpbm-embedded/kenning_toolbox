#!/bin/sh
# Grid search over the pipelines in @NAME@.json (kenning fine-tune-optimizers); best one in build/@NAME@_best.json.
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
exec "$kb/kenning-box" $dry kenning fine-tune-optimizers --cfg "$here/@NAME@.json" --output "$here/build/@NAME@_best.json"
