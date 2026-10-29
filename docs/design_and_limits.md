# 32_07_kenning: design decisions, upstream workarounds, Renode/Zephyr targets

Moved out of `README.md` (nothing removed). Checked 2026-10-24/25; Zephyr runtime, AutoML and AutoGluon parts 2026-10-29.

## Why main and not the v0.8.2 tag (f85992e2)

The tag's `tvm` extra requires `apache-tvm==0.14.dev273`, which is no longer on PyPI (pixi: "no version of
apache-tvm==0.14.dev273"), and it pins TensorFlow 2.15 (Python 3.11 or older). Main ships TVM 0.18 as Antmicro
wheels and supports Python 3.12; Kenning's own README installs from git main as well. Pin: commit
`ae35386b15104edeae03972670b4901072d7028c` in `pixi.toml`.

## Workarounds for upstream main@ae35386b (both inside the examples)

- `LocalPlatform.needs_protocol` is False, so a LocalPlatform scenario ignores its `protocol` block and the client runs
  the model in-process (upstream `scripts/jsonconfigs/tflite-tvm-classification-client-server.json` fails with
  "Could not open compiled_model.tar"). Custom platform classes cannot be named in a scenario, so
  `examples/client_server_tflite/client_patch/sitecustomize.py` flips the flag for the client process only.
- `kenning fine-tune-optimizers` always computes detection metrics and imports `cv2`, even for classification:
  `opencv-python-headless` is in `pixi.toml` instead of the whole `object_detection` extra.

## Renode / Zephyr targets: what works and what does not

- Works: this ID's Renode 1.17.0 is wired to Kenning through pyrenode3 (`PYRENODE_PATH=install/renode`);
  `tests/test_smoke.sh` creates an stm32f746 machine (356 peripherals) from Python.
- Zephyr runtime (2026-10-29): `./kenning-box kzr setup` fetches kenning-zephyr-runtime and its modules at the commits
  in `config/kzr.tsv` into `install/kzr` (shallow fetch, `git rev-parse` must match). `kzr build` uses the west, CMake,
  Ninja and Zephyr SDK of `32_03_zephyr` (`toolchain/zephyr/env.sh`; west finds the 32_03 workspace through
  `ZEPHYR_BASE`). Nothing is copied into 32_03: kzr's `scripts/prepare_modules.sh` copies module glue into
  `zephyr/modules/`; here the glue is found through `-DMODULE_EXT_ROOT=<kzr>` (kzr's `modules/modules.cmake`) and
  `-DZEPHYR_EXTRA_MODULES`, the `module.yml` files go into the fetched module trees, and TVM's `crt_config.h` into
  `install/kzr/tvm/include`. kzr's TVM CRT patches (`memory_leak_fix.patch`, `nop.patch`) are applied once.
  Kenning's own `ZephyrRuntimeBuilder` is not used (it creates its own venv and may run `west init/update`); the
  scenarios name the build directory instead (`ZephyrPlatform.zephyr_build_path`: `.repl`, `zephyr.dts`, `zephyr.elf`).
- Version skew: kzr's west.yml pins Zephyr v4.3.0 and tflite-micro `zephyr-v4.1.0`; 32_03 has v4.4.2, whose tflite-micro
  glue needs `decode.cc` from the `zephyr-v4.4.0` branch, so that branch is pinned. TFLite, TVM and IREE apps build and
  run with it; picolibc replaces newlib silently.
- Keras -> microTVM is refused by Kenning on Python 3.12 (needs keras <= 2.15), so the TVM firmware is built from
  Kenning's own TFLite -> TVM output (`CONFIG_KENNING_TVM_MODEL_PRE_GEN`), and the test sends the same graph.
- `build_tflite.py` (op resolver) imports jinja2, which Kenning lists only under `reports`: `jinja2` is in `pixi.toml`.
- Renode profiler: on by default in `ZephyrPlatform`; one 140-sample run wrote a 5.8 GB dump to `TMPDIR`. Every
  scenario here sets `disable_profiler: true`.
- Board results: `stm32f746g_disco` works for TFLite, TVM and the AutoML VAE. IREE on it: RAM overflow by 3.6 KB; with
  `CONFIG_KENNING_IREE_HEAP_SIZE=144` it links (95 % RAM) and boots, but every request fails with
  `PROTOCOL_STATUS_UNINIT` (the UART-initialised flag gets overwritten), so IREE runs on `b_u585i_iot02a` as in kzr's
  own scenarios. `nrf52840dk/nrf52840`: the app boots and listens on uart1, but Kenning's UART session never starts
  (also with `CONFIG_KENNING_NRF_UART_SLEEP_AFTER_POLL_WORKAROUND`); not solved.
- Bare-metal IREE runtime on Renode (`rv32-springbok`): its prebuilt `kenning:///renode/springbok/iree_runtime` still
  returns HTTP 404 on dl.antmicro.com.

## AutoML and AutoGluon (2026-10-29)

- automl-embedded (ADI + Antmicro) is a VS Code front end: it fills a scenario (`src/kenning/autoMLScenarioTemplate.ts`:
  `AutoPyTorchML`, `PyTorchAnomalyDetectionVAE`, CATS CSV, `ZephyrRuntimeBuilder`, `TFLiteCompiler`) and runs
  `kenning automl optimize test report`. The examples run the same `kenning automl` from the CLI.
- `AutoPyTorchML` = Antmicro's AutoPyTorch fork on SMAC3 1.4 (Bayesian optimisation with Hyperband budgets in epochs).
  Before training a candidate, Kenning converts it with the scenario's optimizers and drops it when
  `application_size + optimized size > RAM` of the platform (`platforms.yml`), counted as "failed due to the too large
  size" in `automl_statistics.json`. `examples/_lib/automl_conf.py check` re-checks every returned model.
- The `automl` env is separate (`pixi.toml` feature `automl`, solve group `automl`): torch from the PyTorch CPU index (no
  CUDA wheels), Kenning with `auto_pytorch` + `anomaly_detection`, git pins for autoPyTorch and smac. The default env
  stays torch-free.
- AutoGluon (`autogluon` env, no default feature): `autogluon.tabular[lightgbm,xgboost]` 1.6.3 only. TimeSeriesPredictor
  is not installed: it forecasts values (it is not an anomaly classifier) and pulls torch, Lightning, transformers and
  Chronos (several GB). Windows are flattened into 90 columns; NN_TORCH, FASTAI and CatBoost are excluded.
  AutoGluon models have no TFLite/microTVM export: host baseline only.
- Deploying AutoML results with kzr's TFLite runtime: the model and the TFLite Micro tensor arena share one
  `CONFIG_KENNING_TFLITE_BUFFER_SIZE` buffer (64 KB), so the AutoML budget must leave room for the arena (a 60.5 KB
  VAE passed a 64 KB budget and failed with "upload model"; the example budgets 56 KB). Some VAE candidates contain
  SELECT, which TFLite Micro cannot register (`MicroMutableOpResolver` has no `AddSelect`): kzr build fails for them,
  so `automl_cats_renode` takes the best returned model that builds. Kenning's AutoML size check does not see either.

## Owned boards as Kenning targets

Kenning's `platforms.yml` (`./kenning-box kenning available-platforms`) lists Zephyr boards. The owned ones that map:

| Owned board | Kenning / Zephyr target | Status |
|---|---|---|
| nRF52840 Pro Micro / nice!nano, nRF52840 mini | `nrf52840dk/nrf52840` (Cortex-M4F, 1 MB / 256 KB) | kzr app builds (125 KB / 75 KB) and boots in Renode (`kzr_nrf52840_boot`); Kenning UART session not working yet |
| STM32H743 min-system, H743 flight controllers | `nucleo_h743zi`-class (Cortex-M7) | same |
| STM32F411 BlackPill | `stm32f4_disco`-class (512 KB / 128 KB: only tiny models such as magic-wand int8 9.5 KB) | same |
| ESP32-S3 / C3 | `esp32s3_devkitc` / `esp32c3_devkitc` (Zephyr) | same, no Renode model |
| This PC, any Linux SBC (H616, RK3506, K230 Linux) | `LocalPlatform` / `kenning server` on the device + `NetworkProtocol` | works (`client_server_tflite`) |

K210/K230 KPU, BL616 and CH32V are not Kenning targets.

## Other platforms

`pixi.toml` lists `linux-64` only. On macOS/Windows remove the `tvm` and `iree` extras, add the platform to `pixi.toml`,
then run `./kenning-box update --env`.
