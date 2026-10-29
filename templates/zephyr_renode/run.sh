#!/bin/sh
# Run @NAME@ on a Renode-simulated Zephyr board (needs a kenning-zephyr-runtime ELF in ./runtime/zephyr.elf).
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
# checks that work without the runtime: the JSON parses and the platform is one Kenning knows
"$kb/kenning-box" run python -I - "$here/@NAME@.json" "$("$kb/kenning-box" where | sed -n 's/^root  *//p')/cache/kenning/platforms/platforms.yml" <<'PY'
import json, sys, yaml
cfg = json.load(open(sys.argv[1]))
name = cfg["platform"]["parameters"]["name"]
plats = yaml.safe_load(open(sys.argv[2]))
assert name in plats, f"{name} is not in platforms.yml (kenning-box kenning available-platforms)"
print(f"platform {name}: flash {plats[name]['flash_size_kb']} KB, RAM {plats[name]['ram_size_kb']} KB, ok")
PY
if [ ! -e runtime/zephyr.elf ]; then
  echo "no runtime/zephyr.elf: build kenning-zephyr-runtime for this board first (see README); dry run:"
  dry=--dry-run
fi
exec "$kb/kenning-box" $dry scenario "$here/@NAME@.json" --measurements "$here/build/@NAME@_measurements.json"
