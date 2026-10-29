#!/usr/bin/env bash
# about: Apache TVM build options: graph executor at opt_level 0 and 3 vs the Relay VM executor; latency compared
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
VARIANTS="graph_o0:0:false graph_o3:3:false vm_o3:3:true"   # name:opt_level:use_tvm_vm

build() {
  local v n o vm
  for v in $VARIANTS; do IFS=: read -r n o vm <<<"$v"; render scenario.json "$EX_OUT/scenario_$n.json" VARIANT="$n" OPT="$o" VM="$vm"; done
  echo "scenarios: $EX_OUT/scenario_*.json"
}
run() {
  build
  local v n o vm runs=()
  for v in $VARIANTS; do
    IFS=: read -r n o vm <<<"$v"
    scenario "$EX_OUT/scenario_$n.json" "$EX_OUT/measurements_$n.json"
    runs+=("$n=$EX_OUT/measurements_$n.json")
  done
  summarize "${runs[@]#*=}"
  python -I "$EX_LIB/compare.py" --out "$EX_OUT/report.md" --baseline graph_o0 "${runs[@]}"
  [ -s "$EX_OUT/tvm_vm_o3.tar.ro" ] || { echo "VM bytecode (tvm_vm_o3.tar.ro) missing"; return 1; }
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
