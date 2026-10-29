#!/bin/sh
# @NAME@: microTVM on a Renode-simulated Zephyr board. 1. kenning optimize (TFLite -> TVM target zephyr: C operator
# sources), 2. kenning-zephyr-runtime built with exactly those operators (32_03_zephyr), 3. kenning test over UART.
# Exit 3 when Zephyr (BOX_ZEPHYR / 32_03_zephyr) is not there. KENNING_BOX = the 32_07_kenning folder.
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
kb=${KENNING_BOX:-${BOX_KENNING:?set BOX_KENNING or KENNING_BOX to the 32_07_kenning folder}}
dry=""; [ "${1:-}" = --dry-run ] && dry=--dry-run
cd "$here"
mkdir -p build
ds="$("$kb/kenning-box" where | sed -n 's/^build  *//p')/datasets/MagicWandDataset"
[ -e build/MagicWandDataset ] || [ ! -d "$ds" ] || ln -s "$ds" build/MagicWandDataset
kzr=$("$kb/kenning-box" kzr status | sed -n 's/^kzr workspace: //p')/kenning-zephyr-runtime   # its model_impl.h template
sed "s|@KZR@|$kzr|" "@NAME@.json" >build/scenario.json
board=$(sed -n 's/^ *"name": "\(.*\)",$/\1/p' "@NAME@.json" | head -1)
"$kb/kenning-box" $dry kenning optimize --cfg "$here/build/scenario.json" --verbosity ERROR
"$kb/kenning-box" $dry kzr build "$board" tvm --out "$here/build/fw" --model "$here/build/model/model.graph_data" \
  -- -DCONFIG_KENNING_TVM_MODEL_PRE_GEN=y
renode=$("$kb/kenning-box" kzr status | sed -n 's/^renode for kzr runs: //p')
"$kb/kenning-box" $dry run env PYRENODE_PATH="$renode" timeout -k 30 900 \
  kenning test --cfg "$here/build/scenario.json" --measurements "$here/build/@NAME@_measurements.json" --verbosity WARNING
[ -n "$dry" ] || "$kb/kenning-box" run python -I "$kb/examples/_lib/summarize.py" "$here/build/@NAME@_measurements.json"
