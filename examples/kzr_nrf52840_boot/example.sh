#!/usr/bin/env bash
# about: kenning-zephyr-runtime for nrf52840dk/nrf52840 (the nice!nano / Pro Micro SoC) with an int8 TFLite Micro op resolver from the model; flash/RAM vs the board, boot checked in Renode (no Kenning session, see README)
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/kzr.sh
. "$(dirname "$0")/../_lib/kzr.sh"
BOARD=nrf52840dk/nrf52840

build() {
  kzr_need
  render optimize.json "$EX_OUT/optimize.json"
  echo "== kenning optimize: magic wand -> TFLite int8 (int8 I/O)"
  (cd "$EX_OUT" && kenning optimize --cfg "$EX_OUT/optimize.json" --verbosity ERROR) >"$EX_OUT/optimize.log" 2>&1 \
    || { tail -30 "$EX_OUT/optimize.log"; return 1; }
  # --model: build_tflite.py writes an op resolver with exactly the model's ops
  kzr_fw "$BOARD" tflite "$EX_OUT/fw" --model "$EX_OUT/magic_wand_int8.tflite"
}
run() {
  build
  local fw=$EX_OUT/fw resolver
  resolver=$(find "$fw/modules" -name ops_resolver.h | head -1)
  echo "   op resolver: $(grep -o 'Add[A-Za-z0-9]*()' "$resolver" | tr '\n' ' ')"
  # flash/RAM of the image (Zephyr's memory report) vs the board in Kenning's platforms.yml (as the nice!nano)
  python -I - "$PLATFORMS_YML" "$BOARD" "$fw.log" <<'PY'
import re, sys, yaml
plat = yaml.safe_load(open(sys.argv[1]))[sys.argv[2]]
used = {m[0]: int(m[1]) for m in re.findall(r"^\s+(FLASH|RAM):\s+(\d+) B", open(sys.argv[3]).read(), re.M)}
print(f"   image: flash {used['FLASH'] / 1024:.0f} of {plat['flash_size_kb']} KB, static RAM {used['RAM'] / 1024:.0f} of {plat['ram_size_kb']} KB")
assert used["FLASH"] <= plat["flash_size_kb"] * 1024 and used["RAM"] <= plat["ram_size_kb"] * 1024, "does not fit the board"
PY
  # boot the image in Renode: the evaluation app must come up and wait for Kenning on the kcomms UART (uart1)
  local log=$EX_OUT/console_uart0.txt
  rm -f "$log"
  timeout -k 10 120 "$KENNING_KZR_RENODE/renode" --console --disable-xwt --plain -e \
    "mach create \"nrf\"; machine LoadPlatformDescription @$(ls "$fw"/*.repl); sysbus LoadELF @$fw/zephyr/zephyr.elf; uart0 CreateFileBackend @$log true; start; sleep 4; quit" \
    >"$EX_OUT/renode.log" 2>&1 || true
  if ! { grep -m1 'Booting Zephyr' "$log" && grep -m1 'Inference server started' "$log" && grep -m1 'Listening timeout' "$log"; }; then
    echo "app did not boot in Renode"; tail -20 "$EX_OUT/renode.log"; return 1
  fi
  echo "   booted in Renode $(basename "$(readlink -f "$KENNING_KZR_RENODE")"); serving Kenning on uart1 (kcomms)"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
