#!/usr/bin/env bash
# about: fp32 and int8 TFLite models checked against 10 owned boards (CH32V003 ... ESP32-S3) using flash/RAM sizes from Kenning's platforms.yml
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
build() {
  render scenario.json "$EX_OUT/scenario_default.json" TARGET=default
  render scenario.json "$EX_OUT/scenario_int8.json" TARGET=int8
  echo "scenarios: $EX_OUT/scenario_{default,int8}.json"
}
run() {
  build
  scenario "$EX_OUT/scenario_default.json" "$EX_OUT/measurements_fp32.json"
  scenario "$EX_OUT/scenario_int8.json" "$EX_OUT/measurements_int8.json"
  summarize "$EX_OUT/measurements_fp32.json" "$EX_OUT/measurements_int8.json"
  [ -r "$PLATFORMS_YML" ] || { echo "no $PLATFORMS_YML (./kenning-box fetch)"; return 1; }
  python -I "$EX_DIR/board_fit.py" "$PLATFORMS_YML" "$EX_OUT/board_fit.md" \
    "$EX_OUT/magic_wand_default.tflite" "$EX_OUT/magic_wand_int8.tflite"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
