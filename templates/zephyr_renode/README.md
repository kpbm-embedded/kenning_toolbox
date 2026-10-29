# @NAME@: Zephyr board simulated in Renode

Made by `kenning-box new zephyr_renode @NAME@`. `ZephyrPlatform` with `simulated: true`: Kenning starts kenning-box's Renode with the board, loads the Zephyr runtime ELF and talks to it over the simulated UART; the model is uploaded and benchmarked on the simulated MCU.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `platform` | `ZephyrPlatform` `nrf52840dk/nrf52840`, simulated | another `kenning available-platforms` name; `simulated: false` + real `port` for the board |
| `runtime_binary_path` | `./runtime/zephyr.elf` | your kenning-zephyr-runtime build |

Run:

```sh
./run.sh               # checks the JSON and platform; full run only when runtime/zephyr.elf exists (else a dry run)
./run.sh --dry-run     # print the commands only
```

Not runnable in this ID yet: the runtime ELF needs [kenning-zephyr-runtime](https://github.com/antmicro/kenning-zephyr-runtime) built with west + Zephyr SDK (see `docs/design_and_limits.md`).

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run renode_model_flash`).
