# shellcheck shell=bash disable=SC2015,SC2034  # d_* return 0; TOOL_* are read by boxtool.bash
# kenning-box: tool part (hooks for lib/boxtool.bash). Kenning main@ae35386b (git) in a pixi env with
# the TensorFlow/TFLite, TVM, ONNX Runtime, IREE, UART and Renode extras, plus an own Renode
# portable for Kenning's simulated-platform runtime.
TOOL_TITLE="32_07_kenning: Kenning 0.8.2+main@ae35386b (Antmicro) + TFLite/TVM/ONNX Runtime/IREE + Renode $(sed -n 's/^renode\t\([^\t]*\)\t.*/\1/p' "${BOXT_ROOT:?}/config/pins.tsv" | head -1)"
TOOL_INSTALL_WHAT="Kenning resources for the examples (magic-wand model + dataset, springbok runtime)"
TOOL_HELP_USE="  kenning <args>          the Kenning CLI (kenning optimize test --cfg x.json, kenning report ...)
  scenario <cfg.json> [--measurements F] [--report F]   optimize + test (+ report) one scenario
  fetch                   pre-download the example resources into cache/kenning (offline afterwards)
  renode [args]           this ID's Renode (Kenning's simulated platforms run on it)"
hook_help() { # printed after boxtool's help: tool-specific examples and environment
  cat <<EOF

tool examples
  ./$BOXT_NAME fetch                            example resources into cache/kenning (then offline)
  ./$BOXT_NAME scenario examples/magic_wand_tflite/scenario.json --report report.md
  ./$BOXT_NAME kenning --help                   the Kenning CLI itself
tool environment
  TF_CPP_MIN_LOG_LEVEL (2), CUDA_VISIBLE_DEVICES (empty: CPU only), OMP_NUM_THREADS and
  TVM_NUM_THREADS (default BOXT_JOBS) are kept when set; set inside: KENNING_CACHE_DIR,
  HF_HOME, KERAS_HOME (all under cache/), PYRENODE_PATH (this ID's Renode)
EOF
}
# shellcheck source-path=SCRIPTDIR source=boxtool.bash
. "$BOXT_ROOT/lib/boxtool.bash"

RENODE_DIR="$INST/renode"
renode_bin() { if [ -x "$RENODE_DIR/renode" ]; then printf '%s' "$RENODE_DIR/renode"; else printf '%s' "$RENODE_DIR/bin/Renode.exe"; fi; }

hook_env() {
  [ -d "$RENODE_DIR" ] && PATH="$RENODE_DIR:$PATH"
  export PATH
  # every cache inside this folder (cache/ is regenerable, CACHEDIR.TAG)
  local c="$ROOT/cache"
  export KENNING_CACHE_DIR="$c/kenning"           # kenning:///... resources (models, runtimes)
  export HF_HOME="$c/huggingface" HF_DATASETS_CACHE="$c/huggingface/datasets"
  export KERAS_HOME="$c/keras" TFHUB_CACHE_DIR="$c/tfhub" TVM_HOME_CACHE="$c/tvm"
  export MPLCONFIGDIR="$c/matplotlib" PIP_CACHE_DIR="$c/pip" UV_CACHE_DIR="$c/uv"
  export XDG_CONFIG_HOME="$c/xdg-config" XDG_CACHE_HOME="$c/xdg-cache"
  export TF_CPP_MIN_LOG_LEVEL=${TF_CPP_MIN_LOG_LEVEL:-2} CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-}
  export OMP_NUM_THREADS=${OMP_NUM_THREADS:-$JOBS} TVM_NUM_THREADS=${TVM_NUM_THREADS:-$JOBS}
  # pyrenode3 (Kenning's Renode bridge) uses the portable Renode of this ID
  unset PYRENODE_PKG PYRENODE_BIN PYRENODE_BUILD_DIR
  export PYRENODE_PATH="$RENODE_DIR"
  RENODE=$(renode_bin); export RENODE RENODE_DIR
  export KENNING_BOX_ROOT="$ROOT" KENNING_BOX_EXAMPLES="$ROOT/examples"
  mkdir -p "$KENNING_CACHE_DIR" "$HF_HOME" "$KERAS_HOME" "$MPLCONFIGDIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" 2>/dev/null || true
}

hook_bootstrap() { cachedir_tag "$ROOT/cache"; }

# Resources the examples need (all small): kenning:// URIs resolved into cache/kenning.
KENNING_RESOURCES="models/classification/magic_wand.h5 models/classification/magic_wand_updated.h5 platforms/platforms.yml"   # (the rv32-springbok iree_runtime is 404 upstream, see README)
tool_cmd_fetch() {
  activate
  local r
  for r in $KENNING_RESOURCES; do
    info "resource kenning:///$r"
    run python -I -c 'import sys; from kenning.utils.resource_manager import ResourceURI; p = ResourceURI(sys.argv[1]); print(" ->", p, p.stat().st_size, "bytes")' "kenning:///$r"
  done
  info "magic-wand dataset -> $BUILD/datasets/MagicWandDataset"
  run python -I -c 'import sys; from pathlib import Path; from kenning.datasets.magic_wand_dataset import MagicWandDataset as D; d = D(Path(sys.argv[1]), download_dataset=True); print(" ->", len(d.dataX), "samples")' "$BUILD/datasets/MagicWandDataset"
}

hook_install() { # demos-flag
  [ "$1" = 1 ] || return 0
  ( tool_cmd_fetch )
}

hook_status() {
  printf '  %-22s %s\n' kenning-cache "$(human_size "$ROOT/cache/kenning")" datasets "$(human_size "$BUILD/datasets")"
  local e n=0
  for e in $(ex_list); do [ -d "$BUILD/examples/$e" ] && n=$((n+1)); done
  printf '  %-22s %s of %s run in %s\n' examples "$n" "$(ex_list | wc -l)" "$BUILD/examples"
}

hook_doctor() {
  local v m
  v=$(python -I -c 'import importlib.metadata as m; print(m.version("kenning"))' 2>/dev/null) && d_ok "kenning $v (git main@ae35386b)" || d_fail "kenning not installed in the pixi env"
  command -v kenning >/dev/null && d_ok "kenning CLI: $(command -v kenning | sed "s|$ROOT/||")" || d_fail "kenning CLI missing"
  for m in tensorflow:tensorflow tflite_runtime_or_litert:ai_edge_litert tvm:tvm onnxruntime:onnxruntime iree:iree.compiler pyrenode3:pyrenode3 serial:serial; do
    v=$(python -I -c "import ${m#*:} as x; print(getattr(x, '__version__', 'ok'))" 2>/dev/null) && d_ok "${m%%:*} ${v}" || d_fail "${m%%:*} (import ${m#*:}) failed"
  done
  if [ -x "$(renode_bin)" ]; then
    v=$("$(renode_bin)" --version 2>/dev/null | head -1) && d_ok "renode: $v" || d_fail "renode --version failed"
  else d_fail "renode missing in $RENODE_DIR"; fi
  local r miss=0
  for r in $KENNING_RESOURCES; do [ -e "$ROOT/cache/kenning/$r" ] || miss=$((miss+1)); done
  [ -d "$BUILD/datasets/MagicWandDataset" ] || miss=$((miss+1))
  [ "$miss" = 0 ] && d_ok "example resources cached (offline)" || d_warn "$miss example resources not cached (./$NAME fetch)"
  # host C compiler: compile checks of generated model code (microtvm_c_codegen, tflm_c_array, template microtvm_c)
  v=$("${CC:-cc}" -dumpfullversion -dumpversion 2>/dev/null | head -1) && d_ok "host C compiler ${CC:-cc} $v" || d_warn "no host C compiler (cc): examples microtvm_c_codegen, tflm_c_array and template microtvm_c need one (gcc or clang)"
}

hook_native_bins() {
  echo "kenning @run kenning"
  echo "kenning-renode install/renode/renode"
}

tool_cmd_kenning() { cmd_shell -- kenning "$@"; }
tool_cmd_renode() { activate; [ "$DRY" = 1 ] && { printf '+ renode %s\n' "$*"; return 0; }; exec "$(renode_bin)" "$@"; }

# scenario <cfg.json> [--measurements F] [--report F]: optimize+test, optionally a report
tool_cmd_scenario() {
  [ $# -ge 1 ] || usage_error "usage: ./$NAME scenario <cfg.json> [--measurements F] [--report F]"
  local cfg=$1 meas="" rep=""; shift
  while [ $# -gt 0 ]; do
    case "$1" in --measurements) meas=${2:?--measurements needs a file}; shift ;; --report) rep=${2:?--report needs a file}; shift ;; *) usage_error "scenario: unknown option $1" ;; esac; shift
  done
  [ -r "$cfg" ] || [ "$DRY" = 1 ] || die "no such scenario file: $cfg"
  meas=${meas:-$BUILD/scenarios/$(basename "${cfg%.json}")/measurements.json}
  activate
  run mkdir -p "$(dirname "$meas")"
  run kenning optimize test --cfg "$cfg" --measurements "$meas" --verbosity INFO
  if [ -n "$rep" ]; then run kenning report --measurements "$meas" --report-path "$rep" --report-types performance classification; fi
  [ "$DRY" = 1 ] || info "measurements: $meas"
}

boxt_main "$@"
