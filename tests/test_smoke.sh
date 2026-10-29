#!/usr/bin/env bash
# Smoke test of the installed kenning-box: CLI, Kenning class registry, every runtime's Python
# package, pyrenode3 driving this ID's Renode, a 5-sample TFLite inference of the cached
# magic-wand model (offline once ./kenning-box fetch ran), and every template: `new`, `run.sh`
# (zephyr_renode: checks + dry run, no runtime ELF), result above 80 % accuracy.
# Usage: tests/test_smoke.sh   (KENNING_SMOKE_TEMPLATES=0 skips the template runs, about 2 min)
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd -P)
K="$HERE/kenning-box"
pass=0; failn=0
ok()  { printf 'ok    %s\n' "$*"; pass=$((pass+1)); }
bad() { printf 'FAIL  %s\n' "$*"; failn=$((failn+1)); }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT   # own temp files only
in_k() { timeout 600 "$K" run bash -c "$1" >"$tmp/out" 2>&1; }

if in_k 'kenning --help' && grep -q 'fine-tune-optimizers' "$tmp/out"; then ok "kenning --help"; else bad "kenning --help"; tail -5 "$tmp/out"; fi
if in_k 'kenning list optimizers' && grep -q 'TVMCompiler' "$tmp/out" && grep -q 'TFLiteCompiler' "$tmp/out"; then
  ok "kenning list optimizers (TFLite, TVM, ...)"; else bad "kenning list optimizers"; tail -5 "$tmp/out"; fi
if in_k 'python -I -c "import tensorflow, ai_edge_litert, tvm, onnxruntime, iree.compiler, iree.runtime, pyrenode3, serial; print(\"imports\", tensorflow.__version__, tvm.__version__, onnxruntime.__version__)"'; then
  ok "$(grep '^imports' "$tmp/out")"; else bad "runtime imports"; tail -5 "$tmp/out"; fi
py3='from pyrenode3.wrappers import Emulation, Monitor
e = Emulation(); m = Monitor()
m.execute("mach create \"smoke\"")
m.execute("machine LoadPlatformDescription @platforms/cpus/stm32f746.repl")
print("pyrenode3 machines:", e.MachinesCount, "peripherals:", len(m.execute("peripherals")[0].splitlines()))'
printf '%s\n' "$py3" >"$tmp/r.py"
if in_k "python -I '$tmp/r.py'" && grep -q 'pyrenode3 machines: 1' "$tmp/out"; then
  ok "pyrenode3 + Renode $(sed -n 's/^renode\t\([^\t]*\)\t.*/\1/p' "$HERE/config/pins.tsv" | head -1): stm32f746 machine ($(grep -o 'peripherals: [0-9]*' "$tmp/out"))"
else bad "pyrenode3/Renode"; tail -8 "$tmp/out"; fi
m="$HERE/cache/kenning/models/classification/magic_wand.h5"
if [ -r "$m" ]; then
  py="import sys, numpy as np, tensorflow as tf
m = tf.keras.models.load_model(sys.argv[1], compile=False)
tfl = tf.lite.TFLiteConverter.from_keras_model(m).convert()
from ai_edge_litert.interpreter import Interpreter
it = Interpreter(model_content=tfl); it.allocate_tensors()
i = it.get_input_details()[0]; o = it.get_output_details()[0]
for _ in range(5):
    it.set_tensor(i['index'], np.random.rand(*i['shape']).astype(np.float32)); it.invoke()
print('tflite', len(tfl), 'bytes, output', it.get_tensor(o['index']).shape)"
  printf '%s\n' "$py" >"$tmp/t.py"
  if in_k "python -I '$tmp/t.py' '$m'" && grep -q '^tflite' "$tmp/out"; then ok "$(grep '^tflite' "$tmp/out") (keras -> TFLite -> LiteRT)"; else bad "TFLite inference"; tail -5 "$tmp/out"; fi
else bad "magic_wand.h5 not cached (./kenning-box fetch)"; fi

# templates: instantiate each kind, run it (4 at a time), check its measurements
mapfile -t kinds < <(find "$HERE/templates" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
for k in "${kinds[@]}"; do
  if "$K" new "$k" "t_$k" --dir "$tmp/tpl" >"$tmp/new_$k.log" 2>&1 && [ -x "$tmp/tpl/t_$k/run.sh" ]; then ok "new $k"; else bad "new $k"; tail -3 "$tmp/new_$k.log"; fi
done
if [ "${KENNING_SMOKE_TEMPLATES:-1}" != 0 ]; then
  run_tpl() { KENNING_BOX="$HERE" timeout 900 "$tmp/tpl/t_$1/run.sh" >"$tmp/run_$1.log" 2>&1; echo $? >"$tmp/rc_$1"; }
  set -- "${kinds[@]}"
  while [ $# -gt 0 ]; do
    for k in "${@:1:4}"; do run_tpl "$k" & done; wait
    shift $(( $# < 4 ? $# : 4 ))
  done
  for k in "${kinds[@]}"; do
    m="$tmp/tpl/t_$k/build/t_${k}_measurements.json"
    case $k in
      zephyr_renode) chk() { grep -q 'kenning optimize test --cfg' "$tmp/run_$k.log"; } ;;              # dry run (no runtime ELF)
      optimizer_search) chk() { [ -s "$tmp/tpl/t_$k/build/t_${k}_best.json" ]; } ;;
      microtvm_c) chk() { [ -s "$tmp/tpl/t_$k/build/model/model.o" ]; } ;;
      *) chk() { python3 -I "$HERE/examples/_lib/summarize.py" --min-accuracy 0.8 "$m" >>"$tmp/run_$k.log" 2>&1; } ;;
    esac
    if [ "$(cat "$tmp/rc_$k")" = 0 ] && chk; then ok "template $k runs"; else bad "template $k (log below)"; tail -5 "$tmp/run_$k.log"; fi
  done
fi

echo "smoke: $pass ok, $failn failed"
[ "$failn" -eq 0 ]
