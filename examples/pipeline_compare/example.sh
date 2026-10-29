#!/usr/bin/env bash
# about: one model, five pipelines (TFLite fp32/int8, ONNX Runtime, TVM, IREE) -> Markdown comparison report (speed-up, size ratio)
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# Reuses the scenario files of the single-pipeline examples; report.md replaces `kenning report`
# (its `reports` extra is not installed).
build() {
  render ../magic_wand_tflite/scenario.json "$EX_OUT/tflite_fp32.json" TARGET=default ITYPE=float32
  render ../magic_wand_tflite/scenario.json "$EX_OUT/tflite_int8.json" TARGET=int8 ITYPE=int8
  render ../magic_wand_onnx/scenario.json "$EX_OUT/onnx.json"
  render ../magic_wand_tvm/scenario.json "$EX_OUT/tvm.json" TVM_TARGET=llvm
  render ../magic_wand_iree/scenario.json "$EX_OUT/iree.json" BACKEND=llvm-cpu
  echo "scenarios: $EX_OUT/{tflite_fp32,tflite_int8,onnx,tvm,iree}.json"
}
run() {
  build
  local p runs=()
  for p in tflite_fp32 tflite_int8 onnx tvm iree; do
    scenario "$EX_OUT/$p.json" "$EX_OUT/measurements_$p.json"
    runs+=("$p=$EX_OUT/measurements_$p.json")
  done
  summarize "${runs[@]#*=}"
  python -I "$EX_LIB/compare.py" --out "$EX_OUT/report.md" "${runs[@]}"
  grep -c '^| [a-z]' "$EX_OUT/report.md" | grep -qx 5 || { echo "report.md: expected 5 pipeline rows"; return 1; }
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
