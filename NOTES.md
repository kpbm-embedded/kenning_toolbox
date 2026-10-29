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

## 2026-10-29: kenning-zephyr-runtime in Renode, AutoML, AutoGluon (7 examples, 4 templates)

- User requests: AutoML for Embedded (ADI + Antmicro, automl-embedded), kenning-zephyr-runtime with 32_03_zephyr,
  AutoGluon as an optional host baseline.
- kzr: new commands `kzr setup|build|status`; pins in `config/kzr.tsv` (kzr main @ 8c884814, tflite-micro zephyr-v4.4.0,
  TVM v0.18.0, dlpack, IREE v3.11.0), fetched shallow into `install/kzr`, commit-checked. Zephyr 4.4.2 + SDK 1.0.1 from
  32_03 (BOX_ZEPHYR or sibling, exit 3 without), nothing copied or changed there: module glue through
  `MODULE_EXT_ROOT` + `ZEPHYR_EXTRA_MODULES` instead of kzr's prepare_modules.sh. Renode: 32_06's (same 1.17.0) when present.
- Problems found: tflite-micro zephyr-v4.1.0 (kzr's pin) fails with Zephyr 4.4 (`decode.cc` missing) -> zephyr-v4.4.0
  branch. `build_tflite.py` needs jinja2 (added to the default env). TVM's `crt_config.h` only reachable through
  zephyr/modules upstream -> copied into the fetched TVM tree. Keras -> microTVM refused on Python 3.12 -> TFLite -> TVM
  with `CONFIG_KENNING_TVM_MODEL_PRE_GEN`. Renode profiler dump 5.8 GB per run -> `disable_profiler` everywhere.
  IREE on stm32f746g_disco: RAM overflow, with a smaller heap the UART state is lost (PROTOCOL_STATUS_UNINIT) -> IREE
  on b_u585i_iot02a. nrf52840dk: boots, but Kenning gets no UART answer (also with the nRF poll workaround) -> boot
  check only. Kenning hangs after a UART error -> every simulated run has a timeout.
  kzr's TFLite buffer (64 KB) holds the model and the tensor arena: a 60.5 KB VAE passed a 64 KB AutoML budget and
  then failed to load ("upload model"); `automl_cats_renode` now budgets 56 KB. Time-limited searches differ run to run.
  Some candidates use the SELECT op, which TFLite Micro cannot register (no `AddSelect`): `automl_cats_renode` deploys
  the best returned model that builds.
- AutoML: optional pixi env `automl` (Kenning extras auto_pytorch + anomaly_detection, torch 2.13.0+cpu from the PyTorch
  CPU index; autoPyTorch and SMAC git commits pinned in pixi.lock: an own rev/branch spec next to Kenning's makes
  `pixi install --locked` fail, found by the fresh-clone check). `kenning automl` with AutoPyTorchML (SMAC + Hyperband, epochs
  1-5) on CATS nano, CPU, 1.5-3 min; the RAM check (application size + TFLite size <= board RAM) rejected 3 of 10
  candidates for max32690evkit (128 - 85 KB). The VS Code plugin itself is not used.
- AutoGluon: optional env `autogluon` (autogluon.tabular 1.6.3, LightGBM, XGBoost, no torch). Same 250 test windows:
  AutoGluon accuracy 1.0 / F1 1.0 (7.7 MB, host only) vs Kenning AutoML VAE 0.972 / F1 0.53 (15.9 KB, runs on the MCU).
  TimeSeriesPredictor not added (forecasting, several GB of torch/transformers).
- Examples (25): kzr_tflite_renode, kzr_tvm_renode, kzr_iree_renode, kzr_nrf52840_boot, automl_cats_search,
  automl_cats_renode, autogluon_cats_baseline. Templates (18): zephyr_renode now a real run; new zephyr_tvm, zephyr_iree,
  automl, autogluon. Commands `extra list|install|run`. README: Bend line replaces the BEAM line.
- Results: doctor 23 ok / 0 warn; examples test 7/7 new (13 min) and 25/25 (automl_cats_renode re-run after the budget fix) all; test_smoke.sh 41/41;
  test_dry_run.sh 42/42 (shellcheck clean).
