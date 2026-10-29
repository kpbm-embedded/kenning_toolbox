#!/usr/bin/env bash
# about: grid search over optimizer/runtime pipelines (TFLite fp32/int8, TFLite->TVM) picking the fastest
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"

build() { render search.json "$EX_OUT/search.json"; echo "search config: $EX_OUT/search.json"; }
run() {
  build
  echo "== kenning fine-tune-optimizers --cfg search.json"
  (cd "$EX_OUT" && kenning fine-tune-optimizers --cfg "$EX_OUT/search.json" --output "$EX_OUT/best.json" --verbosity WARNING) \
    >"$EX_OUT/search.log" 2>&1 || { tail -30 "$EX_OUT/search.log"; return 1; }
  python -I - "$EX_OUT/best.json" <<'PY'
import json, sys
best = json.load(open(sys.argv[1]))
blocks = best["pipeline"]["blocks"]
opts = " -> ".join(f"{k}({v['parameters'].get('target', '')})" for k, v in blocks.get("optimizers", {}).items())
rt = ", ".join(blocks.get("runtimes", {}))
m = best["metrics"]
assert rt, "no runtime in best.json"
print(f"best pipeline: {opts or '-'} | runtime: {rt} | inference mean {1000 * m['inferencetime_mean']:.4f} ms "
      f"(median {1000 * m['inferencetime_median']:.4f} ms)")
PY
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
