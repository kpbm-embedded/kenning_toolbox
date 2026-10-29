# 32_07_kenning: design decisions, upstream workarounds, Renode/Zephyr targets

Moved out of `README.md` (nothing removed). Checked 2026-10-24/25.

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
- Not feasible offline here:
  - **Zephyr runtime** (`ZephyrPlatform`, e.g. `stm32f746g_disco`, scenarios `zephyr-*-magic-wand-inference.json`):
    Kenning has no prebuilt kenning-zephyr-runtime binaries (no GitHub releases, no dl.antmicro.com URL in
    `platforms.yml`). `ZephyrRuntimeBuilder` builds [kenning-zephyr-runtime](https://github.com/antmicro/kenning-zephyr-runtime)
    with `west` in a Zephyr workspace + Zephyr SDK (several GB), which this self-contained ID does not carry.
  - **Bare-metal IREE runtime on Renode** (`rv32-springbok`, `renode-magic-wand-iree-bare-metal-inference.json`):
    its prebuilt `kenning:///renode/springbok/iree_runtime` returns HTTP 404 on dl.antmicro.com.
- To run on Renode later: build kenning-zephyr-runtime for a board (see that repo's README), then use a scenario with
  `"platform": {"type": "ZephyrPlatform", "parameters": {"name": "stm32f746g_disco", "simulated": true, "runtime_binary_path": "<elf>"}}`
  plus `UARTProtocol`. Kenning starts this ID's Renode itself.

## Owned boards as Kenning targets

Kenning's `platforms.yml` (`./kenning-box kenning available-platforms`) lists Zephyr boards. The owned ones that map:

| Owned board | Kenning / Zephyr target | Status |
|---|---|---|
| nRF52840 Pro Micro / nice!nano, nRF52840 mini | `nrf52840dk/nrf52840` (Cortex-M4F, 1 MB / 256 KB) | needs a kenning-zephyr-runtime build; Renode model exists |
| STM32H743 min-system, H743 flight controllers | `nucleo_h743zi`-class (Cortex-M7) | same |
| STM32F411 BlackPill | `stm32f4_disco`-class (512 KB / 128 KB: only tiny models such as magic-wand int8 9.5 KB) | same |
| ESP32-S3 / C3 | `esp32s3_devkitc` / `esp32c3_devkitc` (Zephyr) | same, no Renode model |
| This PC, any Linux SBC (H616, RK3506, K230 Linux) | `LocalPlatform` / `kenning server` on the device + `NetworkProtocol` | works (`client_server_tflite`) |

K210/K230 KPU, BL616 and CH32V are not Kenning targets.

## Other platforms

`pixi.toml` lists `linux-64` only. On macOS/Windows remove the `tvm` and `iree` extras, add the platform to `pixi.toml`,
then run `./kenning-box update --env`.
