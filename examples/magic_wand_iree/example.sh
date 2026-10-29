#!/usr/bin/env bash
# about: magic-wand model -> ONNX -> IREE 3.11 (backends llvm-cpu and vmvx, the portable interpreter MCU runtimes use), IREE runtime on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
BACKENDS=${KENNING_EX_IREE_BACKENDS:-llvm-cpu vmvx}

build() { local b; for b in $BACKENDS; do render scenario.json "$EX_OUT/scenario_$b.json" BACKEND="$b"; done; echo "scenarios: $EX_OUT/scenario_*.json"; }
run() {
  build
  local b m=()
  for b in $BACKENDS; do scenario "$EX_OUT/scenario_$b.json" "$EX_OUT/measurements_$b.json"; m+=("$EX_OUT/measurements_$b.json"); done
  summarize --out "$EX_OUT/summary.json" "${m[@]}"
  # each .vmfb must load as an IREE VM module with an entry function (Kenning imports Keras via ONNX)
  python -I - "$EX_OUT"/magic_wand_*.vmfb <<'PY'
import sys
import iree.runtime as rt
for f in sys.argv[1:]:
    mod = rt.VmModule.mmap(rt.VmInstance(), f)
    funcs = [n for n in mod.function_names if not n.startswith("__")]
    assert funcs, f"{f}: no entry function"
    print(f"IREE module ok: {f.rsplit('/', 1)[-1]} functions {funcs}")
PY
  ls -l "$EX_OUT"/*.vmfb
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
