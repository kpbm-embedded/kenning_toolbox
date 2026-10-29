#!/usr/bin/env bash
# about: chained optimizers: Keras -> ONNX (ONNXCompiler) -> Apache TVM (ONNX frontend, llvm), TVM runtime on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
build() { render scenario.json "$EX_OUT/scenario.json"; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_onnx_tvm.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_onnx_tvm.json"
  # both stages leave their artefact: the intermediate ONNX file and the TVM library
  python -I -c 'import onnx, sys; m = onnx.load(sys.argv[1]); onnx.checker.check_model(m); print("intermediate ONNX ok, opset", m.opset_import[0].version)' "$EX_OUT/magic_wand.onnx"
  python -I - "$EX_OUT/measurements_onnx_tvm.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
fw = [o.get("compiler_framework") for o in d.get("optimizers", [])]
print("optimizer chain:", " -> ".join(map(str, fw)))
assert fw == ["onnx", "tvm"], fw
PY
  ls -l "$EX_OUT"/magic_wand.onnx "$EX_OUT"/magic_wand_onnx_tvm.tar
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
