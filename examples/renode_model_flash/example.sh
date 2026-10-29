#!/usr/bin/env bash
# about: Renode (pyrenode3): int8 model loaded into the simulated flash of nRF52840 and STM32F746, read back byte for byte; memory sizes vs platforms.yml
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
build() { render scenario.json "$EX_OUT/scenario.json" TARGET=int8; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_int8.json"
  summarize "$EX_OUT/measurements_int8.json"
  [ -r "$PLATFORMS_YML" ] || { echo "no $PLATFORMS_YML (./kenning-box fetch)"; return 1; }
  echo "== Renode $("$RENODE" --version 2>/dev/null | head -1 | sed 's/^Renode, version //')"
  python -I "$EX_DIR/renode_flash.py" "$PLATFORMS_YML" "$EX_OUT/magic_wand_int8.tflite" | tee "$EX_OUT/renode.txt"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
