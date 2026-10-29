#!/usr/bin/env bash
# about: magic-wand gesture model (Keras .h5, 46 KB) -> TFLite fp32 and int8, benchmarked on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"

build() {
  render scenario.json "$EX_OUT/scenario_fp32.json" TARGET=default ITYPE=float32
  render scenario.json "$EX_OUT/scenario_int8.json" TARGET=int8 ITYPE=int8
  echo "scenarios: $EX_OUT/scenario_{fp32,int8}.json"
}
run() {
  build
  scenario "$EX_OUT/scenario_fp32.json" "$EX_OUT/measurements_fp32.json"
  scenario "$EX_OUT/scenario_int8.json" "$EX_OUT/measurements_int8.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_fp32.json" "$EX_OUT/measurements_int8.json"
  ls -l "$EX_OUT"/*.tflite
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
