#!/bin/sh
# Run @NAME@ on a Renode-simulated Zephyr board: kenning-zephyr-runtime (IREE vmvx loader) built with 32_03_zephyr,
# Kenning talks to it over a simulated UART. Exit 3 when Zephyr (BOX_ZEPHYR / 32_03_zephyr) is not there.
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
board=$(sed -n 's/^ *"name": "\(.*\)",$/\1/p' "@NAME@.json" | head -1)   # the platform name is also the west board
"$kb/kenning-box" $dry kzr build "$board" iree_vmvx --out "$here/build/fw"
renode=$("$kb/kenning-box" kzr status | sed -n 's/^renode for kzr runs: //p')
"$kb/kenning-box" $dry run env PYRENODE_PATH="$renode" timeout -k 30 900 \
  kenning optimize test --cfg "$here/@NAME@.json" --measurements "$here/build/@NAME@_measurements.json" --verbosity WARNING
[ -n "$dry" ] || "$kb/kenning-box" run python -I "$kb/examples/_lib/summarize.py" "$here/build/@NAME@_measurements.json"
