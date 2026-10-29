#!/bin/sh
# microTVM C code for @NAME@ (kenning optimize, TVM target zephyr) + a host compile check of the C sources.
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
"$kb/kenning-box" $dry kenning optimize --cfg "$here/@NAME@.json"
[ -n "$dry" ] && exit 0
crt=$("$kb/kenning-box" run python -I -c 'import os, tvm; print(os.path.join(os.path.dirname(tvm.__file__), "standalone_crt", "include"))' 2>/dev/null | tail -1)
${CC:-cc} -std=c11 -O2 -c -I "$crt" build/model/model.c -o build/model/model.o
echo "build/model: model.c compiles; $(grep -c 'FUNC(tvmgen_' build/model/model.h) operator functions in model.h"
