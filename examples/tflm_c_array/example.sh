#!/usr/bin/env bash
# about: TensorFlow Lite Micro export: int8 model as an aligned C array + the op-resolver header with exactly its ops; compiled with the host C compiler
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
CC=${CC:-cc}

build() { render scenario.json "$EX_OUT/scenario.json"; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_int8.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_int8.json"
  tflite_info info "$EX_OUT/magic_wand_int8.tflite" | tee "$EX_OUT/info.txt"
  tflite_info carray "$EX_OUT/magic_wand_int8.tflite" magic_wand "$EX_OUT/tflm"
  command -v "$CC" >/dev/null || { echo "no C compiler ($CC): install gcc or set CC"; return 1; }
  "$CC" -std=c11 -Wall -Werror -c "$EX_OUT/tflm/magic_wand_model_data.c" -o "$EX_OUT/tflm/magic_wand_model_data.o"
  local n sz
  n=$(grep -c 'resolver.Add' "$EX_OUT/tflm/magic_wand_op_resolver.h")
  sz=$(stat -c %s "$EX_OUT/magic_wand_int8.tflite")
  grep -q "magic_wand_model_data_len = $sz;" "$EX_OUT/tflm/magic_wand_model_data.c" || { echo "array length != model size"; return 1; }
  grep -q 'in=int8' "$EX_OUT/info.txt" || { echo "expected int8 input"; return 1; }
  echo "TFLM files in $EX_OUT/tflm: $sz B model, $n ops (MicroMutableOpResolver<$n>); arena upper bound in info.txt"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
