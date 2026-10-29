# 32_07_kenning - Kenning (deep-learning deployment pipelines for edge devices)

[Kenning](https://github.com/antmicro/kenning) (Antmicro) builds and benchmarks deployment pipelines for edge
ML: model wrapper + dataset + optimizer chain (TFLite, TVM, ONNX, IREE) + runtime, run on the host or on a target
(board or Renode simulation) over a protocol (TCP, UART). Use it to compare how a model performs after
optimization (accuracy, latency, size). This ID holds Kenning, every runtime the examples need and its own Renode,
all inside the folder: no sudo, no system packages.

Status: **ready for host, TCP and pipe targets; partial for Renode/Zephyr targets** (inference on a simulated MCU
needs a runtime build, see Limitations). Doctor 18 ok; examples 18/18; templates 14 (13 run, 1 dry run); smoke 33/33;
dry run 33/33 (2026-10-29). Launcher: `./kenning-box`.

## What's included

| Component | Version | Notes |
|---|---|---|
| Kenning | main @ ae35386b (2026-10-01, v0.8.2-596) | from git, not on PyPI; the v0.8.2 tag does not resolve (see `docs/design_and_limits.md`) |
| Python | 3.12 | conda-forge |
| TensorFlow / tf-keras | 2.21.0 | extra `tensorflow` |
| LiteRT (TFLite runtime) | ai-edge-litert 2.3.0 | extra `tflite` |
| Apache TVM | 0.18.0 | Antmicro cp312 wheel, extra `tvm` |
| ONNX / ONNX Runtime | onnx 1.22.0 / onnxruntime 1.31.0 (tf2onnx 1.17.0, onnx2tf 1.28.8) | extra `onnxruntime` |
| IREE | iree-base-compiler / -runtime 3.11.0 | extra `iree` |
| pyrenode3 / renode-run | git 27362def / c3937440 | extra `renode`, locked |
| Renode | 1.17.0 portable | own copy in `install/renode-1.17.0`, sha256 pinned |
| pixi | 0.81.0 | sha256 pinned in `kenning-box` |

Also installed: extra `uart` and `opencv-python-headless`. Not installed: `torch`, `reports`/`docs`/`pipeline_manager`,
`object_detection`, `nni`, `auto_pytorch`, `tinygrad`, `coralnpu` (add an extra in `pixi.toml`, then `update --env`).

## Quick start

```sh
cd "$BOX_KENNING"                              # or: cd $BOX/30_39_tools/32_embedded/32_07_kenning
./kenning-box install && ./kenning-box doctor  # env (4.6 GB), Renode, example resources (~1 MB); 17 checks
./kenning-box examples test                    # 18 examples, 6-9 min, offline after install
./kenning-box kenning list optimizers          # any Kenning CLI command
./kenning-box new scenario my_scn --dir .      # scenario JSON + run.sh + README to edit
```

With the Box shell set up once (`box shell install --apply`), the `kenning-box` shim works from any folder,
and `box test|doctor|status kenning` run this launcher (`box clean kenning` is a dry run until `--apply`).
Standalone (no Box, or `BOX_INTEGRATION=0`), `./kenning-box` keeps its output in this folder.

## Commands

Global option: `--dry-run` / `-n` prints what a command would do. Exit codes: 0 ok, 1 failure, 2 usage error (unknown command or option, or arguments given to `where`, `status`, `doctor`, `bootstrap` or `relocate`), 3 not applicable. `help` ends with this tool's own examples and variables (`tool examples`, `tool environment`).

| Command | What it does | Example |
|---|---|---|
| `bootstrap` | pinned pixi + env + core downloads (sha-checked) | `./kenning-box bootstrap` |
| `install [--no-demos]` | bootstrap + demo downloads + Kenning resources (magic-wand model + dataset, springbok runtime) | `./kenning-box install` |
| `update [--check\|--env]` | `--check` (default): pins vs newest upstream; `--env`: re-solve pixi env (rewrites `pixi.lock`) | `./kenning-box update --check` |
| `clean [--all] [--yes]` | move build/log output (`--all`: also install/, .pixi, native/, downloads) to the Trash; dry run unless `--yes` | `./kenning-box --dry-run clean --all` |
| `status`, `where`, `doctor` | versions and sizes, paths, health checks (exit 1 on failure) | `./kenning-box doctor` |
| `shell [-- cmd ...]` | bash (or a command) with the tools on PATH | `./kenning-box shell` |
| `run <cmd> [args]` | one command inside the environment | `./kenning-box run python -V` |
| `kenning <args>` | the Kenning CLI | `./kenning-box kenning optimize test --cfg x.json` |
| `scenario <cfg.json> [--measurements F] [--report F]` | optimize + test (+ report) one scenario | `./kenning-box scenario my.json --measurements m.json` |
| `fetch` | pre-download the example resources into `cache/kenning` (offline afterwards) | `./kenning-box fetch` |
| `renode [args]` | this ID's Renode (Kenning's simulated platforms run on it) | `./kenning-box renode --version` |
| `test [--all]` | `tests/test_smoke.sh`; `--all` adds dry-run and examples tests | `./kenning-box test` |
| `new <kind> <name> [--dir D] [--force]` | create from `templates/` (14 kinds, see below) | `./kenning-box new tvm my_scn --dir .` |
| `examples list \| run <ex> [args] \| build [ex...] \| test [ex...]` | list, run, build or test examples | `./kenning-box examples run magic_wand_tflite` |
| `native [--print]` | write `native/{native.zsh,native.bash,bin/}` | `./kenning-box native` |
| `relocate` | after moving the folder: re-create the env, rewrite `native/` | `./kenning-box relocate` |
| `pack [--with-cache] [--out F]` | tarball of this folder for another machine | `./kenning-box pack` |
| `help`, `-h`, `--help` | command list | `./kenning-box help` |

## Examples and templates

All run on the host and offline after `install`. Output (scenarios, compiled models, `measurements_*.json`,
`summary.json`) goes to `$BOX_V3/30_39_tools/32_embedded/32_07_kenning/build/examples/<ex>/`. The test step fails below
80 % accuracy (`KENNING_EX_MIN_ACCURACY`). `examples/_lib/summarize.py` prints the table for any measurements file.

| Example | What | Result 2026-10-25 (accuracy / mean, median inference / model size) |
|---|---|---|
| `magic_wand_tflite` | gesture CNN (Keras .h5, 46 KB) to TFLite fp32 and int8, LiteRT runtime | fp32 0.993 / 0.010, 0.008 ms / 20.8 KB; int8 0.993 / 0.008, 0.008 ms / 9.5 KB |
| `magic_wand_tvm` | to TFLite then TVM 0.18 (`llvm`, opt 3) | 0.993 / 1.5, 0.015 ms / 47 KB (mean includes first-call warm-up) |
| `magic_wand_onnx` | to ONNX (tf2onnx, opset 15), ONNX Runtime CPU | 0.993 / 0.58, 0.037 ms / 20 KB |
| `client_server_tflite` | `kenning server` + client over TCP 127.0.0.1 (the same split drives a board via `UARTProtocol`) | 0.993 / 0.76, 0.49 ms round trip |
| `optimizer_search` | `kenning fine-tune-optimizers` grid search over TFLite fp32/int8 and TFLite-to-TVM, writes `best.json` | best: TFLite int8 + LiteRT |

Added 2026-10-29 (results from one run on the shared machine; TVM latencies swing 0.02-30 ms with the load of other builds):

| Example | What is shown and checked | Result 2026-10-29 |
|---|---|---|
| `magic_wand_iree` | Keras -> ONNX -> IREE 3.11, backends `llvm-cpu` and `vmvx` (the portable interpreter MCU runtimes use); each `.vmfb` loads as an IREE module | 0.993; median 0.12 / 1.53 ms; 37 / 32 KB |
| `tflite_pruning` | magnitude pruning to 50 % sparsity (TF Model Optimization, 3 epochs) then TFLite int8; sparsity per weight tensor and gzip size vs plain int8 | 0.979; 0.500 zeros; gzip 4982 vs 6180 B |
| `tflite_clustering` | weight clustering (16 centroids, fine-tuned) then TFLite; at most 16 distinct values per weight tensor | 1.000; gzip 5.4 KB vs 20.3 KB raw |
| `tflite_float16` | float16 weights vs fp32; float32 I/O with DEQUANTIZE ops | 0.993; 13.1 KB vs 20.3 KB |
| `onnx_to_tvm` | two chained optimizers: ONNXCompiler then TVM's ONNX frontend; intermediate `.onnx` checked, chain read from the measurements | 0.993; 47 KB |
| `tvm_executors` | TVM graph executor at `opt_level` 0 and 3 vs the Relay VM; Markdown comparison (`report.md`) | o3 2.6x faster than o0, 20 % smaller |
| `microtvm_c_codegen` | TVM target `zephyr`: C operator sources + graph blob for kenning-zephyr-runtime, compiled with the host `cc` against TVM's standalone CRT headers (no board) | 9 operator functions, 21 KB graph+params |
| `tflm_c_array` | TFLite Micro export: int8 model (int8 I/O) as a 16-byte aligned C array + an op-resolver header with exactly its 5 ops; host `cc -Wall -Werror` | 9.3 KB, arena upper bound 4.8 KB |
| `board_fit` | fp32 and int8 models against 10 owned boards (CH32V003, BlackPill F411, WeAct G431/H562/H743, Pico, Pico 2, nRF52840 Pro Micro, ESP32-S3, ESP32-C3) from Kenning's `platforms.yml`; writes `board_fit.md` | int8 fits all but CH32V003; fp32 also misses G431 RAM |
| `renode_model_flash` | Renode 1.17 via pyrenode3: int8 model loaded into the simulated flash of nRF52840 and STM32F746, read back byte for byte; Renode memory sizes vs `platforms.yml` | identical; F746 model is 2 MB / 384 KB (board 1 MB / 320 KB) |
| `client_server_pipe` | `kenning server` + client over named pipes (PipeProtocol): model and I/O spec uploaded, inference served by the server (UARTProtocol is client-only) | 0.993; 0.43 ms round trip |
| `model_inserter` | bring your own compiled model: ModelInserter benchmarks a `.tflite` made outside Kenning (plain TensorFlow here, or `KENNING_EX_MODEL`); writes the I/O spec from the file | 0.993; file byte-identical |
| `pipeline_compare` | the same model through TFLite fp32/int8, ONNX Runtime, TVM and IREE; `report.md` with speed-up and size ratio (replaces `kenning report`) | smallest: TFLite int8 (0.46x) |

Helpers: `examples/_lib/tflite_info.py` (I/O types, ops, arena upper bound, sparsity, C array), `examples/_lib/compare.py`
(Markdown comparison of measurements files), `examples/board_fit/board_fit.py`, `examples/renode_model_flash/renode_flash.py`.
`microtvm_c_codegen` and `tflm_c_array` need a host C compiler (`cc`; doctor checks it).

Templates: `./kenning-box new <kind> <name> [--dir D]` gives `<name>.json`, `run.sh` (`--dry-run` prints the commands) and a
README with the blocks to swap. `run.sh` links kenning-box's dataset copy into `build/` (offline) and writes measurements
there. `tests/test_smoke.sh` instantiates and runs every kind. Reports (`kenning report`) need the `reports` extra, which
is not installed: use `examples/_lib/compare.py`.

| Kind | Pipeline | Checked by the smoke test |
|---|---|---|
| `scenario` | TFLite int8 (the original template) | runs, accuracy >= 80 % |
| `tflite_fp32` | TFLite fp32 baseline | runs |
| `tflite_float16` | TFLite float16 weights | runs |
| `tvm` | TFLite -> TVM `llvm` | runs |
| `onnx` | ONNX + ONNX Runtime CPU | runs |
| `onnx_tvm` | ONNX -> TVM chain | runs |
| `iree` | IREE `llvm-cpu` (`vmvx` in the README) | runs |
| `pruning` | magnitude pruning -> TFLite int8 | runs |
| `clustering` | weight clustering -> TFLite | runs |
| `client_server` | `kenning server` + client over TCP (board/SBC split) | runs, client connected |
| `model_inserter` | your own `model.tflite` (demo model made when missing) | runs |
| `optimizer_search` | `fine-tune-optimizers` grid search | `best.json` written |
| `microtvm_c` | TVM target `zephyr`: C sources for an MCU + host compile | `model.o` built |
| `zephyr_renode` | `ZephyrPlatform` simulated in Renode, UART protocol | JSON + platform check, dry run (needs a kenning-zephyr-runtime ELF) |

## Configuration and environment variables

| Variable | Default | Meaning |
|---|---|---|
| `BOXT_OUT` | same ID path on idisk03, else here | output root (`build/`, `log/`); or `config/local.env` |
| `BOXT_JOBS` | 8 (maximum 8) | parallel jobs |
| `BOXT_MIN_FREE_GB` / `BOXT_RAM_WAIT_MAX` | 8 / 3600 | pause builds below this free RAM (GB) / give up after this many seconds |
| `BOXT_NET_TIMEOUT` | 3600 | seconds for one download |
| `BOXT_PLATFORM` | detected (`linux-x64`) | override platform |
| `GITHUB_TOKEN` | unset | optional, lifts the API limit for `update --check` |
| `BOX_INTEGRATION` | 1 | `0` = standalone: ignore `$BOX`/`$BOX_V3`, keep output in this folder |
| `NO_COLOR` | unset | set to print plain text (colour is only used on a terminal anyway) |
| `KENNING_CACHE_DIR` | `cache/kenning` | Kenning resources (set by the launcher) |
| `KENNING_EX_MIN_ACCURACY` | 0.8 (80 %) | accuracy floor in `examples test` |
| `PYRENODE_PATH` | `install/renode` | how pyrenode3 finds Renode (set by the launcher) |
| `BOX_KENNING` | set by `box_env.sh` | path of this ID, used by the native snippet |

HF, Keras, TF Hub, matplotlib, pip/uv and XDG caches are pointed into `cache/`.

## Where files go

| What | Where |
|---|---|
| Source, launcher, examples, templates | this ID (`kenning-box`, `lib/kenning.bash`, `examples/`, `templates/scenario`) |
| Env | `.pixi/` 4.6 GB; Renode `install/renode-1.17.0` 185 MB; `.bin/` pinned pixi |
| Cache | `cache/` (downloads, pixi/uv packages hardlinked with `.pixi`, `cache/kenning` resources) |
| Build output, dataset, logs | `$BOX_V3/30_39_tools/32_embedded/32_07_kenning/{build,log}` (7 MB) |

Whole folder: about 5.4 GB. Platform is `linux-64` only in `pixi.toml` (TVM wheel and IREE are x86_64 Linux). Downloads:
pixi 20 MB, conda + PyPI packages about 1.5 GB, Renode 61 MB, magic-wand model/dataset/`platforms.yml` about 1.5 MB.
Kenning logs a notice about `kenning:///VERSION` when offline; that is harmless.

## Native mode

`./kenning-box native` writes `native/native.{zsh,bash}` and `native/bin/{kenning,kenning-renode}`. The wrappers are
relative and `kenning` goes through `kenning-box run`, so nothing from the env lands on PATH. Load it in every shell
(zsh, bash, fish) with `box native enable kenning --apply`: it runs `./kenning-box native` when the files are missing
and rebuilds `box_env.d/native.*` (without `--apply` it only shows the plan; `box native disable kenning --apply`
undoes it). `BOX_NATIVE_OFF_KENNING=1` skips it for one shell (the old `KENNINGBOX_NATIVE_OFF` still works for now).
Without Box, source `native/native.zsh` or `native/native.bash` from your shell rc.

## Tests

```sh
./kenning-box test --all       # smoke + dry-run + examples
tests/test_smoke.sh            # CLI, class registry, runtime imports, pyrenode3 + Renode, TFLite inference
tests/test_dry_run.sh          # every command dry-run + shellcheck + python syntax
```

Last known (2026-10-29): doctor 18 ok / 0 warn / 0 fail; `examples test` 18/18 (9 min on the loaded shared machine);
`test_smoke.sh` 33/33 (5 env checks, 14 `new`, 14 template runs; 3.7 min); `test_dry_run.sh` 33/33.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Pixi cannot resolve `apache-tvm==0.14.dev273` | that is the v0.8.2 tag; this ID pins main @ ae35386b on purpose |
| "Could not open compiled_model.tar" in a client/server scenario | upstream bug: LocalPlatform ignores `protocol`; see `examples/client_server_tflite/client_patch/sitecustomize.py` |
| `fine-tune-optimizers` fails importing `cv2` | `opencv-python-headless` is in `pixi.toml`; re-run `install` / `update --env` |
| springbok runtime download gives HTTP 404 | upstream URL is gone; the bare-metal IREE-on-Renode scenario cannot run |
| Notice about `kenning:///VERSION` offline | harmless |
| Folder moved, env broken | `./kenning-box relocate` |

More detail on these workarounds: [docs/design_and_limits.md](docs/design_and_limits.md).

## Limitations / needs you

- **Renode/Zephyr targets do not run here**: no prebuilt kenning-zephyr-runtime, and building it needs `west` plus a Zephyr
  SDK (several GB; the Zephyr toolchain lives in `32_03_zephyr` and is not referenced from this ID). The springbok IREE
  runtime URL returns 404. Open item 5 in `$BOX/00_09_meta/02_logs/2026_10_25_open_items.md`. Details and the later route in the docs file.
- One `pixi install` during setup used the host `~/.cache/rattler` (1.5 GB, listed in open items); later installs use `cache/`.
- Owned-board mapping (nRF52840, STM32H743, BlackPill, ESP32, Linux SBCs) is in the docs file; K210/K230 KPU, BL616 and CH32V are not Kenning targets.
- No sudo, licence or hardware needed for the host examples.
- `tflite_qat` was not added: `TFLiteCompiler` with `quantization_aware_training: true` fails in main@ae35386b
  (`UnboundLocalError: is_model` in `optimizers/tflite.py`; with the default `model_framework` it asserts on `keras`).
- Hardware-only parts are not verified: no board ran a model. `microtvm_c_codegen`/`tflm_c_array` only compile the C on the
  host, `renode_model_flash` only places the model in simulated flash, `zephyr_renode` is a dry run without a runtime ELF.
- Rust: not supported because Kenning (Python) has no Rust runtime, optimizer or protocol client; its outputs (`.tflite`,
  microTVM C) can be embedded in Rust firmware with `include_bytes!`, which is 32_17_embedded_rust's job, not a Kenning feature.
- Zig: not supported because Kenning has no Zig runtime or code generator; `tflm_c_array` / `microtvm_c_codegen` output is
  plain C that a 32_24_microzig project can link, outside Kenning.
- BEAM (AtomVM): not supported because Kenning has no BEAM runtime and AtomVM has no tensor/NN runtime to run a model.

## Scripts

Each script has a `[scripts.*]` descriptor in `.box.toml` (`box scripts show 32_07`; `box scripts check 32_07` must stay clean).

- `examples/_lib/common.sh`: Shared helpers for examples/*/example.sh (sourced; run inside ./kenning-box examples ..., which sets EX_OUT, EX_DIR, BOXT_BUILD and the cache variables)
- `examples/_lib/summarize.py`: Summarize (and check) Kenning measurements JSON files
- `examples/_lib/compare.py`: Markdown comparison report of several measurements files (speed-up, size ratio)
- `examples/_lib/tflite_info.py`: Inspect a .tflite for MCU deployment: I/O types, ops, arena upper bound, sparsity, TFLM C array
- `examples/board_fit/board_fit.py`: model size and arena vs flash/RAM of 10 owned boards (Kenning platforms.yml)
- `examples/renode_model_flash/renode_flash.py`: load a model into simulated flash in Renode (pyrenode3) and read it back
- `examples/<13 new examples>/example.sh`: see the examples table (their `# about:` lines)
- `examples/client_server_tflite/client_patch/sitecustomize.py`: Client-side switch for examples/client_server_tflite (on PYTHONPATH of the client only)
- `examples/client_server_tflite/example.sh`: target-device flow over a protocol: `kenning server` (TFLite runtime) + client on 127.0.0.1 TCP
- `examples/magic_wand_onnx/example.sh`: magic-wand model -> ONNX (tf2onnx via Kenning's ONNXCompiler), ONNX Runtime CPU benchmark on the host
- `examples/magic_wand_tflite/example.sh`: magic-wand gesture model (Keras .h5, 46 KB) -> TFLite fp32 and int8, benchmarked on the host
- `examples/magic_wand_tvm/example.sh`: magic-wand model -> TFLite -> Apache TVM 0.18 (llvm, opt_level 3), TVM runtime benchmark on the host
- `examples/optimizer_search/example.sh`: grid search over optimizer/runtime pipelines (TFLite fp32/int8, TFLite->TVM) picking the fastest
- `kenning-box`: the launcher (POSIX sh): bootstraps the pinned pixi, keeps caches inside this folder, then runs lib/; `./kenning-box help` lists the commands
- `lib/boxtool.bash`: shared launcher framework (boxtool 3: bootstrap, pinned downloads, pixi env, every common command); byte-identical copy of `$BOX/00_09_meta/05_policy/templates/tool/lib/boxtool.bash` (edit there, then sync)
- `lib/kenning.bash`: this tool's part of the launcher: TOOL_* settings, hook_* functions and extra commands (`./kenning-box help`)
- `templates/scenario/run.sh`: Run the @NAME@ scenario with kenning-box (optimize + test); measurements in build/
- `templates/<kind>/run.sh` (13 more kinds): run that template's scenario (or search / optimize / client-server) with kenning-box; `--dry-run` prints the commands
- `tests/test_dry_run.sh`: every launcher command in --dry-run mode, the read-only commands for real, plus shellcheck (no downloads or builds)
- `tests/test_smoke.sh`: Smoke test of the installed kenning-box: CLI, Kenning class registry, every runtime's Python package, pyrenode3 driving this ID's Renode, a 5-sample TFLite inference of the cached magic-wand model, and every template instantiated and run
- `native/`: written by `./kenning-box native` (wrappers in native/bin, native.zsh / native.bash); regenerate, do not edit

## Links

- Kenning: <https://github.com/antmicro/kenning>; Zephyr runtime: <https://github.com/antmicro/kenning-zephyr-runtime>
- pyrenode3: <https://github.com/antmicro/pyrenode3>; renode-run: <https://github.com/antmicro/renode-run>; Renode: <https://github.com/renode/renode/releases/tag/v1.17.0>
- TVM wheels: <https://dl.antmicro.com/kenning/packages/tvm/>; pixi: <https://github.com/prefix-dev/pixi>
- History: `NOTES.md`; deep notes: `docs/design_and_limits.md`. Reports: `$BOX/00_09_meta/02_logs/2026_10_25_readability_embedded_tools_verification_report.md`.
