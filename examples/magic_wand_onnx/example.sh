#!/usr/bin/env bash
# about: magic-wand model -> ONNX (tf2onnx via Kenning's ONNXCompiler), ONNX Runtime CPU benchmark on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"

build() { render scenario.json "$EX_OUT/scenario.json"; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_onnx.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_onnx.json"
  python -I -c 'import onnx, sys; m = onnx.load(sys.argv[1]); onnx.checker.check_model(m); print("onnx.checker ok:", sys.argv[1], "opset", m.opset_import[0].version)' "$EX_OUT/magic_wand.onnx"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
