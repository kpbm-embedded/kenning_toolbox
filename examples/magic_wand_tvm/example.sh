#!/usr/bin/env bash
# about: magic-wand model -> TFLite -> Apache TVM 0.18 (llvm, opt_level 3), TVM runtime benchmark on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
TVM_TARGET=${KENNING_EX_TVM_TARGET:-llvm}   # e.g. "llvm -mcpu=native"

build() { render scenario.json "$EX_OUT/scenario.json" TVM_TARGET="$TVM_TARGET"; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_tvm.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_tvm.json"
  ls -l "$EX_OUT"/magic_wand_tvm.tar
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
