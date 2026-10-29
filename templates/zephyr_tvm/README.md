# @NAME@: microTVM model on a Zephyr board simulated in Renode

Made by `kenning-box new zephyr_tvm @NAME@`. With microTVM the operators are C code compiled into the firmware, so the
order is: `kenning optimize` (Keras -> TFLite -> TVM 0.18 target `zephyr`: `build/model/model.{c,h,graph_data}`),
then `kenning-box kzr build <board> tvm --model build/model/model.graph_data -- -DCONFIG_KENNING_TVM_MODEL_PRE_GEN=y`
(kenning-zephyr-runtime with these operators, Zephyr from `32_03_zephyr`), then `kenning test`: Kenning sends the
graph + parameters over the simulated UART and runs the test set in Renode.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand CNN (Keras; TVM reads it via TFLite: Keras -> microTVM directly is unsupported on Python 3.12) | any TFLite-convertible model |
| `platform.name` / `target_microtvm_board` | `stm32f746g_disco` (Cortex-M7) | another board with a kzr UART overlay; keep both names equal |
| `zephyr_header_template` | kzr's `model_impl.h.template` (`@KZR@` is filled in by `run.sh`) | keep |

Run: `./run.sh` (about 1 min) or `./run.sh --dry-run`. Needs `kenning-box kzr setup` and `32_03_zephyr` (exit 3 without).
Example: `kenning-box examples run kzr_tvm_renode`.
