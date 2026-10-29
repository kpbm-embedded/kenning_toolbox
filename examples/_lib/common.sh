# shellcheck shell=bash
# Shared helpers for examples/*/example.sh (sourced; run inside ./kenning-box examples ...,
# which sets EX_OUT, EX_DIR, BOXT_BUILD and the cache variables).
set -euo pipefail
: "${EX_OUT:?run through ./kenning-box examples}" "${EX_DIR:?}" "${BOXT_BUILD:?}"
EX_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DATASET="$BOXT_BUILD/datasets/MagicWandDataset"   # shared by all examples (kenning-box fetch)
MIN_ACC=${KENNING_EX_MIN_ACCURACY:-0.80}

# render <template.json> <out.json> KEY=VALUE...   (@OUT@ and @DATASET@ always set)
render() {
  local src=$1 dst=$2; shift 2
  local args=(-e "s|@OUT@|$EX_OUT|g" -e "s|@DATASET@|$DATASET|g") kv
  for kv in "$@"; do args+=(-e "s|@${kv%%=*}@|${kv#*=}|g"); done
  sed "${args[@]}" "$src" >"$dst"
  if grep -q '@[A-Z_]*@' "$dst"; then echo "render: unreplaced placeholder in $dst" >&2; return 1; fi
}

# scenario <cfg.json> <measurements.json>: kenning optimize + test, log next to it
scenario() {
  local cfg=$1 meas=$2
  echo "== kenning optimize test --cfg $(basename "$cfg")"
  (cd "$EX_OUT" && kenning optimize test --cfg "$cfg" --measurements "$meas" --verbosity WARNING) \
    >"${meas%.json}.log" 2>&1 || { tail -30 "${meas%.json}.log"; return 1; }
}

summarize() { python -I "$EX_LIB/summarize.py" --min-accuracy "$MIN_ACC" "$@"; }

# tflite_info info|json|weights|carray ...: inspect a .tflite (I/O types, ops, arena, sparsity, C array)
tflite_info() { python -I "$EX_LIB/tflite_info.py" "$@"; }
export PLATFORMS_YML="$KENNING_CACHE_DIR/platforms/platforms.yml"   # Kenning's board list (kenning-box fetch)
