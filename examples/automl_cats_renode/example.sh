#!/usr/bin/env bash
# about: AutoML to a simulated MCU: 2-min Kenning AutoML search bounded by kzr's 64 KB TFLite buffer (model + arena) on stm32f746g_disco, best VAE -> TFLite -> kenning-zephyr-runtime (32_03_zephyr) -> evaluated over UART in Renode vs the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/automl.sh
. "$(dirname "$0")/../_lib/automl.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/kzr.sh
. "$(dirname "$0")/../_lib/kzr.sh"
# RAM 320 KB (platforms.yml) - 264 KB application = 56 KB for the model: kzr uploads it into its 64 KB
# CONFIG_KENNING_TFLITE_BUFFER_SIZE buffer, which also holds the TFLite Micro tensor arena (8 KB left for it).
# With 256 KB (64 KB budget) a 60.5 KB VAE passed the check and then failed to load ("upload model").
APP_KB=${KENNING_EX_AUTOML_APP_KB:-264}
MINUTES=${KENNING_EX_AUTOML_MINUTES:-2}

build() {
  env_need automl; kzr_need
  automl_search "$MINUTES" stm32f746g_disco/stm32f746xx "$APP_KB"
  # best first; the runtime's op resolver is generated from the .tflite (the VAE needs Logistic, Mul, Sub, Sqrt, ...).
  # Some candidates use SELECT, which TFLite Micro has no resolver entry for (AddSelect): those cannot be deployed.
  local conf
  for conf in $(find "$EX_OUT/automl" -maxdepth 1 -name "automl_conf_*.yml" | sort -V); do
    echo "== $(basename "$conf") -> TFLite, host test (reference), kzr app"
    automl_eval_host "$conf" host
    if KZR_QUIET=1 kzr_fw stm32f746g_disco tflite "$EX_OUT/fw" --model "$EX_OUT/host.tflite"; then
      cp "$conf" "$EX_OUT/deployed_conf.yml"; return 0; fi
    echo "   not buildable with TFLite Micro: $(grep -o "has no member named '[A-Za-z0-9]*'" "$EX_OUT/fw.log" | sort -u | tr '\n' ' '), next model"
  done
  echo "no AutoML model could be built for the board"; return 1
}
run() {
  build
  python -I "$EX_LIB/automl_conf.py" derive "$EX_OUT/deployed_conf.yml" "$EX_OUT/mcu.yml" "$EX_OUT/host.tflite" \
    --zephyr-build "$EX_OUT/fw" --board stm32f746g_disco
  KZR_RUN="$KB extra run automl" kzr_test "$EX_OUT/mcu.yml" "$EX_OUT/measurements_mcu.json"
  summarize "$EX_OUT/measurements_host.json" "$EX_OUT/measurements_mcu.json"
  f1 "$EX_OUT/measurements_host.json" "$EX_OUT/measurements_mcu.json"
  mcu_report "$EX_OUT/measurements_mcu.json"
  # same model, same windows: the simulated MCU must give the host's answers
  python -I -c 'import json,sys; a,b=(json.load(open(f))["eval_confusion_matrix"] for f in sys.argv[1:]); assert a==b, (a,b); print("   MCU confusion matrix == host confusion matrix")' \
    "$EX_OUT/measurements_host.json" "$EX_OUT/measurements_mcu.json"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
