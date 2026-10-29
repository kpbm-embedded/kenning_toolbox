#!/usr/bin/env bash
# about: microTVM: TFLite -> TVM target "zephyr" (C sources + graph for the Kenning Zephyr runtime), compiled with the host C compiler (no board)
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
CC=${CC:-cc}

build() {
  render optimize.json "$EX_OUT/optimize.json" EXDIR="$EX_DIR"
  echo "== kenning optimize --cfg optimize.json (no test step: the C model runs on an MCU, not on the host)"
  (cd "$EX_OUT" && kenning optimize --cfg "$EX_OUT/optimize.json" --verbosity WARNING) >"$EX_OUT/optimize.log" 2>&1 \
    || { tail -30 "$EX_OUT/optimize.log"; return 1; }
  ls -l "$EX_OUT/model"
}
run() {
  build
  local d=$EX_OUT/model crt n
  for f in model.c model.h model.graph_data model.graph.json; do [ -s "$d/$f" ] || { echo "missing $d/$f"; return 1; }; done
  n=$(grep -c 'FUNC(tvmgen_' "$d/model.h")
  [ "$n" -gt 0 ] || { echo "no operator functions in model.h"; return 1; }
  echo "model.h: $n TVM operator functions; graph $(wc -c <"$d/model.graph.json") B, params+graph blob $(wc -c <"$d/model.graph_data") B"
  # the generated C must compile stand-alone against TVM's C runtime headers (standalone_crt)
  crt=$(python -I -c 'import os, tvm; print(os.path.join(os.path.dirname(tvm.__file__), "standalone_crt", "include"))')
  command -v "$CC" >/dev/null || { echo "no C compiler ($CC): install gcc or set CC"; return 1; }
  "$CC" -std=c11 -O2 -c -I "$crt" "$d/model.c" -o "$d/model.o"
  printf '#include "model.h"\n#define F(x) +1\nint n = 0 TVMGEN_FUNCTIONS_MAGIC_WAND(F);\n' >"$d/check_header.c"
  "$CC" -c -I "$d" "$d/check_header.c" -o "$d/check_header.o"
  size "$d/model.o" 2>/dev/null || ls -l "$d/model.o"
  echo "C sources compile ($CC); flash a board with kenning-zephyr-runtime + this model (not done here)"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
