#!/usr/bin/env bash
# about: TFLite float16 weights vs fp32: half the weight bytes, float32 I/O (DEQUANTIZE ops added), same accuracy
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
build() {
  render scenario.json "$EX_OUT/scenario_default.json" TARGET=default
  render scenario.json "$EX_OUT/scenario_float16.json" TARGET=float16
  echo "scenarios: $EX_OUT/scenario_{default,float16}.json"
}
run() {
  build
  scenario "$EX_OUT/scenario_default.json" "$EX_OUT/measurements_fp32.json"
  scenario "$EX_OUT/scenario_float16.json" "$EX_OUT/measurements_float16.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_fp32.json" "$EX_OUT/measurements_float16.json"
  tflite_info info "$EX_OUT/magic_wand_default.tflite" "$EX_OUT/magic_wand_float16.tflite" | tee "$EX_OUT/info.txt"
  grep 'magic_wand_float16' "$EX_OUT/info.txt" | grep -q 'in=float32.*DEQUANTIZE' || { echo "float16 model: expected float32 input and DEQUANTIZE ops"; return 1; }
  local a b
  a=$(stat -c %s "$EX_OUT/magic_wand_default.tflite"); b=$(stat -c %s "$EX_OUT/magic_wand_float16.tflite")
  echo "size: fp32 $a B, float16 $b B"
  [ "$b" -lt $((a * 3 / 4)) ] || { echo "float16 model not smaller than 3/4 of fp32"; return 1; }
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
