# 32_07_kenning notes

## 2026-10-24 / 25: set up

- New ID in the Box tool style (launcher + `lib/boxtool.bash` copied from 32_06_renode, pinned pixi 0.81.0).
- Kenning v0.8.2 tag (f85992e2) does not resolve: its `tvm` extra needs `apache-tvm==0.14.dev273`,
  gone from PyPI; tag also pins TensorFlow 2.15 (py ≤ 3.11). Pinned main @ ae35386b (2026-10-01,
  v0.8.2-596) with Python 3.12, TVM 0.18 (Antmicro wheel), TF 2.21, IREE 3.11, ONNX Runtime 1.31.
- Extras: tensorflow, tflite, tvm, onnxruntime, uart, renode, iree. Env 4.6 GB.
- Own Renode 1.17.0 portable (same pin as 32_06, downloaded again). pyrenode3 finds it with
  `PYRENODE_PATH=install/renode`; smoke test builds an stm32f746 machine.
- Renode/Zephyr Kenning targets not runnable here: no prebuilt kenning-zephyr-runtime (would need
  a Zephyr workspace + SDK in this ID); the springbok bare-metal IREE runtime URL is 404. README has details.
- Upstream issues worked around in examples: LocalPlatform ignores `protocol` (client_patch/sitecustomize.py);
  `fine-tune-optimizers` imports cv2 for classification (opencv-python-headless added).
- One `pixi install` was run with `.bin/pixi` directly (no PIXI_CACHE_DIR), so that solve may
  have used `~/.cache/rattler` on the host; later installs go through `./kenning-box` (cache/ inside).
- Results: install ok, doctor 17 ok / 0 warn / 0 fail, examples test 5/5 ok (~2 min),
  tests/test_smoke.sh 5/5, tests/test_dry_run.sh 29/29 (incl. shellcheck).

## 2026-10-25: readability pass 2 (script_style.md, scripts/README)
- lib/boxtool.bash (reference `00_09_meta/05_policy/templates/tool/lib/boxtool.bash`, synced to all 24 copies):
  `where`/`status`/`doctor`/`bootstrap`/`relocate` reject extra arguments (exit 2); colour only on a terminal
  and never with `NO_COLOR`; help lists `NO_COLOR`.
- `help` now ends with `tool examples` / `tool environment` (hook_help in lib/kenning.bash).
- README: exit codes, `BOX_INTEGRATION` and `NO_COLOR` rows. Backups:
  `00_09_meta/02_logs/config_backups/2026_10_25_readability2_embedded_tools/`.

## 2026-10-29: 13 examples, 13 templates, git repo (kenning-box)

- Examples added (18 in total): `magic_wand_iree` (llvm-cpu + vmvx), `tflite_pruning`, `tflite_clustering`,
  `tflite_float16`, `onnx_to_tvm`, `tvm_executors`, `microtvm_c_codegen`, `tflm_c_array`, `board_fit`,
  `renode_model_flash`, `client_server_pipe`, `model_inserter`, `pipeline_compare`. Helpers in `examples/_lib`:
  `tflite_info.py` (I/O types, ops, arena upper bound, sparsity, TFLM C array) and `compare.py` (Markdown report,
  instead of `kenning report`, whose extra is not installed).
- Templates added (14 kinds): `tflite_fp32`, `tflite_float16`, `tvm`, `onnx`, `onnx_tvm`, `iree`, `pruning`, `clustering`,
  `client_server`, `model_inserter`, `optimizer_search`, `microtvm_c`, `zephyr_renode`. Every `run.sh` links
  kenning-box's dataset copy (offline) and takes `--dry-run`; the `scenario` template got the same link.
- Problems found: the TFLite optimizer's I/O keys are `inferenceinputtype`/`inferenceoutputtype` (examples used
  `inference_input_type`; Kenning matched them anyway, renamed for clarity). `target: int8` alone gives float32 I/O with
  QUANTIZE/DEQUANTIZE ops; int8 I/O needs both keys. Quantization-aware training is broken upstream
  (`UnboundLocalError: is_model`), so no QAT example. UARTProtocol is client-only (server side is firmware): the
  host protocol example uses PipeProtocol. IREE imports Keras via ONNX (module function `tf2onnx`). `.vmfb` files are zip
  containers. ModelInserter needs `<model>.json` (I/O spec); `model_inserter` writes it from the `.tflite`.
  Renode's STM32F746 model has 2 MB flash / 384 KB RAM (board 1 MB / 320 KB). `kenning-box run` unsets PYTHONPATH,
  so the client patch is passed with `run env PYTHONPATH=...`. TVM latencies swing a lot when the machine is loaded.
- Rust, Zig, BEAM (brief addendum): skipped, Kenning has no runtime, generator or client for them (README lines).
- doctor: new check for a host C compiler (2 examples and the `microtvm_c` template compile generated C).
- `.gitignore` made strict (model files, logs, bytecode). `git init -b main`, one commit.
- Results: doctor 18 ok / 0 warn; examples test 18/18 (9 min on the loaded machine); test_smoke.sh 33/33 (14 `new` +
  14 template runs); test_dry_run.sh 33/33 (shellcheck clean).
