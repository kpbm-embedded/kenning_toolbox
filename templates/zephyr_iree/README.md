# @NAME@: IREE (vmvx) model on a Zephyr board simulated in Renode

Made by `kenning-box new zephyr_iree @NAME@`. `run.sh` builds kenning-zephyr-runtime with its IREE runtime
(`app/iree_vmvx.conf`: VMVX bytecode loader, 160 KB IREE heap, 60 KB model buffer) for `b_u585i_iot02a` (STM32U585,
Cortex-M33, 768 KB RAM) with `32_03_zephyr`, then `kenning optimize test` compiles the model with IREE 3.11 (`vmvx`
backend: portable bytecode, no target code generation) and uploads the `.vmfb` over the simulated UART.

| block | here | swap for |
|---|---|---|
| `platform.name` | `b_u585i_iot02a` (kzr's own IREE target) | a board with enough RAM and a kzr UART overlay; on `stm32f746g_disco` (320 KB) the IREE app does not fit with its default heap |
| `optimizers` | `IREECompiler` `vmvx` | keep `vmvx` (the `llvm-cpu` embedded-ELF loader is another kzr config, not tried here) |

Run: `./run.sh` (about 2 min: vmvx is an interpreter, about 0.45 s per inference in simulation) or `./run.sh --dry-run`.
Needs `kenning-box kzr setup` and `32_03_zephyr` (exit 3 without). Example: `kenning-box examples run kzr_iree_renode`.
