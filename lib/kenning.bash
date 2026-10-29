# shellcheck shell=bash disable=SC2015,SC2034  # d_* return 0; TOOL_* are read by boxtool.bash
# kenning-box: tool part (hooks for lib/boxtool.bash). Kenning main@ae35386b (git) in a pixi env with
# the TensorFlow/TFLite, TVM, ONNX Runtime, IREE, UART and Renode extras, plus an own Renode
# portable for Kenning's simulated-platform runtime.
TOOL_TITLE="32_07_kenning: Kenning 0.8.2+main@ae35386b (Antmicro) + TFLite/TVM/ONNX Runtime/IREE + Renode $(sed -n 's/^renode\t\([^\t]*\)\t.*/\1/p' "${BOXT_ROOT:?}/config/pins.tsv" | head -1)"
TOOL_INSTALL_WHAT="Kenning resources for the examples (magic-wand model + dataset, springbok runtime)"
TOOL_HELP_USE="  kenning <args>          the Kenning CLI (kenning optimize test --cfg x.json, kenning report ...)
  scenario <cfg.json> [--measurements F] [--report F]   optimize + test (+ report) one scenario
  fetch                   pre-download the example resources into cache/kenning (offline afterwards)
  renode [args]           this ID's Renode (Kenning's simulated platforms run on it)
  kzr setup|status        kenning-zephyr-runtime + modules (config/kzr.tsv) into install/kzr
  kzr build <board> <tflite|tvm|iree_vmvx> [--model M] [--out D] [-- cmake args]
                          build kzr's evaluation app with 32_03_zephyr (BOX_ZEPHYR) + board .repl for Renode
  extra list|install <env>|run <env> <cmd>   optional pixi envs: automl (AutoPyTorch, CPU torch), autogluon"
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
  # kenning-zephyr-runtime flow (examples kzr_*, automl_cats_renode; templates zephyr_*): 32_03 Zephyr, kzr sources,
  # and the Renode those runs use (32_06_renode's when present)
  export KENNING_ZEPHYR_ID="$ZEPHYR_ID" KENNING_KZR_DIR="$KZR_DIR" KENNING_KZR_RENODE; KENNING_KZR_RENODE=$(kzr_renode_dir)
  mkdir -p "$KENNING_CACHE_DIR" "$HF_HOME" "$KERAS_HOME" "$MPLCONFIGDIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" 2>/dev/null || true
}

hook_bootstrap() { cachedir_tag "$ROOT/cache"; }

# Resources the examples need (all small): kenning:// URIs resolved into cache/kenning.
KENNING_RESOURCES="models/classification/magic_wand.h5 models/classification/magic_wand_updated.h5 platforms/platforms.yml
  datasets/anomaly_detection/cats_nano.csv renode/scripts/stm32f746g_disco.resc"   # (the rv32-springbok iree_runtime is 404 upstream, see README)
# Renode script of the AutoML target board (max32690evkit, as in kzr's AutoML scenario): cached as renode/scripts/max32690evkit.resc
KENNING_RESOURCES_GH="gh://antmicro:kenning-zephyr-runtime/renode/scripts/max32690evkit.resc;branch=main"
tool_cmd_fetch() {
  activate
  local r
  for r in $KENNING_RESOURCES $KENNING_RESOURCES_GH; do
    case $r in *://*) ;; *) r="kenning:///$r" ;; esac
    info "resource $r"
    run python -I -c 'import sys; from kenning.utils.resource_manager import ResourceURI; p = ResourceURI(sys.argv[1]); print(" ->", p, p.stat().st_size, "bytes")' "$r"
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
  for r in $KENNING_RESOURCES renode/scripts/max32690evkit.resc; do [ -e "$ROOT/cache/kenning/$r" ] || miss=$((miss+1)); done
  [ -d "$BUILD/datasets/MagicWandDataset" ] || miss=$((miss+1))
  [ "$miss" = 0 ] && d_ok "example resources cached (offline)" || d_warn "$miss example resources not cached (./$NAME fetch)"
  # host C compiler: compile checks of generated model code (microtvm_c_codegen, tflm_c_array, template microtvm_c)
  v=$("${CC:-cc}" -dumpfullversion -dumpversion 2>/dev/null | head -1) && d_ok "host C compiler ${CC:-cc} $v" || d_warn "no host C compiler (cc): examples microtvm_c_codegen, tflm_c_array and template microtvm_c need one (gcc or clang)"
  # kenning-zephyr-runtime flow: sibling 32_03_zephyr (west + SDK), fetched kzr sources, Renode for the runs
  if [ -n "$ZEPHYR_ID" ]; then d_ok "Zephyr for kzr builds: $(sed -n 's/^| Zephyr | \([^|]*\) |.*/\1/p' "$ZEPHYR_ID/toolchain/zephyr/README.md" | head -1 | sed 's/ (.*//; s/ *$//') in $ZEPHYR_ID"
  else d_warn "Zephyr not found (BOX_ZEPHYR / sibling 32_03_zephyr): kzr_* examples and zephyr_* templates skip"; fi
  local n=0 name commit _r
  while IFS=$'\t' read -r name commit _r; do case $name in ''|'#'*) continue ;; esac
    [ "$(git -C "$KZR_DIR/$name" rev-parse HEAD 2>/dev/null)" = "$commit" ] || n=$((n+1)); done <"$KZR_PINS"
  [ "$n" = 0 ] && d_ok "kenning-zephyr-runtime workspace at the config/kzr.tsv pins" || d_warn "$n kzr sources missing or not at their pin (./$NAME kzr setup)"
  d_ok "Renode for kzr runs: $(kzr_renode_dir | sed "s|^$ROOT/||")"
  local e; for e in $EXTRA_ENVS; do
    [ -x "$ROOT/.pixi/envs/$e/bin/python" ] && d_ok "extra env $e" || d_warn "extra env $e not installed (./$NAME extra install $e): its examples and template fail"; done
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

# ---------- sibling IDs (reached, never copied): 32_03_zephyr (west + SDK), 32_06_renode ----------
sibling_id() { # ENV_VAR FOLDER MARKER -> another tool ID: the variable's folder or one above it that holds
  # MARKER (BOX_ZEPHYR names toolchain/zephyr inside the ID), else ../FOLDER (or nothing)
  local d=${!1:-} i
  for i in 1 2 3; do
    [ -n "$d" ] && [ -e "$d/$3" ] && { (cd -P "$d" && pwd -P); return 0; }
    d=${d%/*}
  done
  if [ -e "$ROOT/../$2/$3" ]; then (cd -P "$ROOT/../$2" && pwd -P); fi
}
ZEPHYR_ID=$(sibling_id BOX_ZEPHYR 32_03_zephyr toolchain/zephyr/env.sh)
RENODE_ID=$(sibling_id BOX_RENODE 32_06_renode renode-box)
KZR_DIR="$INST/kzr"           # kenning-zephyr-runtime + its modules (config/kzr.tsv), fetched by `kzr setup`
KZR_PINS="$ROOT/config/kzr.tsv"
need_zephyr() { [ -n "$ZEPHYR_ID" ] || not_applicable "Zephyr not found: set BOX_ZEPHYR or install the sibling 32_03_zephyr (toolchain/zephyr/env.sh)"; }
need_kzr() { [ -r "$KZR_DIR/kenning-zephyr-runtime/app/CMakeLists.txt" ] || not_applicable "kenning-zephyr-runtime not fetched: ./$NAME kzr setup"; }
kzr_renode_dir() { # Renode for the Zephyr runs: 32_06_renode's when present (same 1.17.0 pin), else this ID's own
  if [ -n "$RENODE_ID" ] && [ -x "$RENODE_ID/install/renode/renode" ]; then printf '%s' "$RENODE_ID/install/renode"; else printf '%s' "$RENODE_DIR"; fi
}

kzr_setup() { # fetch every source of config/kzr.tsv at its pinned commit (shallow), verify the commit
  local name commit ref url subs d have
  run mkdir -p "$KZR_DIR"
  while IFS=$'\t' read -r name commit ref url subs; do
    case $name in ''|'#'*) continue ;; esac
    d="$KZR_DIR/$name"
    have=$(git -C "$d" rev-parse HEAD 2>/dev/null || true)
    if [ "$have" = "$commit" ]; then info "$name $ref @ ${commit:0:12}: present"; else
      [ -e "$d" ] && trash_paths "kzr setup: $name not at the pinned commit" "$d"
      info "$name $ref @ ${commit:0:12} <- $url"
      run git init -q "$d"
      run timeout "$NET_TIMEOUT" git -C "$d" fetch -q --depth 1 "$url" "$commit"
      run git -C "$d" -c advice.detachedHead=false checkout -q FETCH_HEAD
      if [ "$DRY" != 1 ]; then have=$(git -C "$d" rev-parse HEAD); [ "$have" = "$commit" ] || die "$name: checked out $have, pinned $commit"; fi
    fi
    if [ "$subs" != - ]; then
      local s; for s in ${subs//,/ }; do run timeout "$NET_TIMEOUT" git -C "$d" submodule update -q --init --depth 1 -- "$s"; done
    fi
  done <"$KZR_PINS"
  # what kzr's scripts/prepare_modules.sh does, minus copying into zephyr/modules (32_03 stays untouched):
  # module.yml into each external module; kzr's modules/modules.cmake is found through MODULE_EXT_ROOT
  local m k="$KZR_DIR/kenning-zephyr-runtime"
  for m in tvm dlpack iree; do
    run mkdir -p "$KZR_DIR/$m/zephyr"
    run cp "$k/modules/$m/module.yml" "$KZR_DIR/$m/zephyr/module.yml"
  done
  run cp "$k/modules/iree/zephyr_config.h" "$KZR_DIR/iree/zephyr/"
  run cp "$k/modules/tvm/crt_config.h" "$KZR_DIR/tvm/include/"   # upstream reaches it via zephyr/modules/tvm
  # kzr's TVM CRT patches (graph executor: params loading leak, __nop/__copy ops), once on a clean checkout
  if [ "$DRY" = 1 ] || git -C "$KZR_DIR/tvm" diff --quiet; then
    run git -C "$KZR_DIR/tvm" apply "$k/modules/tvm/memory_leak_fix.patch"
    run patch -s --no-backup-if-mismatch -d "$KZR_DIR/tvm" -p0 -i "$k/modules/tvm/nop.patch"
  fi
  [ "$DRY" = 1 ] || info "kzr workspace ready: $KZR_DIR ($(human_size "$KZR_DIR"))"
}

# kzr build <board> <runtime> [--model M] [--out D] [-- extra cmake args]: kenning-zephyr-runtime evaluation app
# runtime: tflite | tvm | iree_vmvx (app/<runtime>.conf); then `board-repl` (dts2repl) for Renode
kzr_build() {
  [ $# -ge 2 ] || usage_error "usage: ./$NAME kzr build <board> <tflite|tvm|iree_vmvx> [--model M] [--out D] [-- cmake args]"
  local board=$1 rt=$2 model="" out="" extra=(); shift 2
  while [ $# -gt 0 ]; do
    case "$1" in --model) model=${2:?}; shift ;; --out) out=${2:?}; shift ;; --) shift; extra=("$@"); break ;; *) usage_error "kzr build: unknown option $1" ;; esac; shift
  done
  need_zephyr; [ "$DRY" = 1 ] || need_kzr
  local k="$KZR_DIR/kenning-zephyr-runtime"
  [ -r "$k/app/$rt.conf" ] || [ "$DRY" = 1 ] || usage_error "kzr build: no app/$rt.conf in kenning-zephyr-runtime"
  out=${out:-$BUILD/kzr/${board//\//_}_$rt}
  local conf="$rt.conf" bconf="$k/app/boards/${board//\//_}.conf"
  [ -r "$bconf" ] && conf="$conf;$bconf"
  activate
  local py; py=$(command -v python)
  local args=(-DEXTRA_CONF_FILE="$conf" -DMODULE_EXT_ROOT="$k"
    -DZEPHYR_EXTRA_MODULES="$k;$KZR_DIR/tflite-micro;$KZR_DIR/tvm;$KZR_DIR/dlpack;$KZR_DIR/iree"
    "-DCONFIG_KENNING_PYTHON_PATH=\"$py\"")
  [ -n "$model" ] && args+=("-DCONFIG_KENNING_MODEL_PATH=\"$model\"")
  wait_for_ram
  info "west build $board $rt -> $out (Zephyr from $ZEPHYR_ID)"
  # 32_03's env.sh: west, cmake, ninja, Zephyr SDK; west finds the 32_03 workspace through ZEPHYR_BASE
  # shellcheck source=/dev/null  # 32_03_zephyr's env.sh (another ID)
  ( set +u; . "$ZEPHYR_ID/toolchain/zephyr/env.sh"; set -u
    run west build -p auto -b "$board" -d "$out" -o="-j$JOBS" "$k/app" -- "${args[@]}" "${extra[@]+"${extra[@]}"}" &&
    run west build -d "$out" -o="-j$JOBS" -t board-repl ) || die "kzr build failed ($board, $rt)"
  [ "$DRY" = 1 ] || info "runtime: $out/zephyr/zephyr.elf ($(stat -c %s "$out/zephyr/zephyr.elf" 2>/dev/null) bytes), repl: $(ls "$out"/*.repl 2>/dev/null)"
}

tool_cmd_kzr() { # kenning-zephyr-runtime: setup | build | status
  local sub=${1:-status}; [ $# -gt 0 ] && shift
  case "$sub" in
    setup) kzr_setup ;;
    build) kzr_build "$@" ;;
    status)
      printf 'zephyr (32_03): %s\nrenode for kzr runs: %s\nkzr workspace: %s\n' "${ZEPHYR_ID:-not found (BOX_ZEPHYR)}" "$(kzr_renode_dir)" "$KZR_DIR"
      local name commit ref; while IFS=$'\t' read -r name commit ref _; do
        case $name in ''|'#'*) continue ;; esac
        printf '  %-24s %-20s %s\n' "$name" "$ref" "$([ "$(git -C "$KZR_DIR/$name" rev-parse HEAD 2>/dev/null)" = "$commit" ] && echo "ok ${commit:0:12}" || echo "missing (kzr setup)")"
      done <"$KZR_PINS" ;;
    *) usage_error "usage: ./$NAME kzr setup | build <board> <runtime> [--model M] [--out D] | status" ;;
  esac
}

# ---------- optional pixi environments (pixi.toml [environments]): automl, autogluon ----------
EXTRA_ENVS="automl autogluon"
tool_cmd_extra() { # extra install <env>... | run <env> <cmd> [args] | list
  local sub=${1:-list}; [ $# -gt 0 ] && shift
  case "$sub" in
    list) local e; for e in $EXTRA_ENVS; do printf '  %-10s %s\n' "$e" "$([ -x "$ROOT/.pixi/envs/$e/bin/python" ] && echo "installed $(human_size "$ROOT/.pixi/envs/$e")" || echo "not installed (./$NAME extra install $e)")"; done ;;
    install)
      [ $# -ge 1 ] || usage_error "usage: ./$NAME extra install <$(echo "$EXTRA_ENVS" | tr ' ' '|')>..."
      local e; for e in "$@"; do
        case " $EXTRA_ENVS " in *" $e "*) ;; *) usage_error "unknown extra env: $e ($EXTRA_ENVS)" ;; esac
        wait_for_ram
        run timeout "$NET_TIMEOUT" "$PIXI" install --manifest-path "$MANIFEST" --frozen -e "$e"
      done ;;
    run)
      [ $# -ge 2 ] || usage_error "usage: ./$NAME extra run <env> <cmd> [args]"
      local e=$1; shift
      [ -x "$ROOT/.pixi/envs/$e/bin/python" ] || [ "$DRY" = 1 ] || not_applicable "extra env $e not installed: ./$NAME extra install $e"
      activate   # caches, Renode, PYRENODE_PATH; then the extra env's activation on top
      local hook; hook=$("$PIXI" shell-hook --manifest-path "$MANIFEST" --frozen -e "$e" --shell bash) || die "pixi shell-hook -e $e failed"
      [ "$DRY" = 1 ] && { printf '+ (env %s)' "$e"; printf ' %q' "$@"; echo; return 0; }
      set +u; eval "$hook"; set -u
      exec "$@" ;;
    *) usage_error "usage: ./$NAME extra list | install <env>... | run <env> <cmd> [args]" ;;
  esac
}

boxt_main "$@"
