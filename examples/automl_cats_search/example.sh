#!/usr/bin/env bash
# about: Kenning AutoML (AutoPyTorch: SMAC + Hyperband, the automl-embedded engine) on CATS anomaly data: 3-min CPU search of VAE models within the RAM budget of max32690evkit, best model -> TFLite tested on the host
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/automl.sh
. "$(dirname "$0")/../_lib/automl.sh"
BOARD=${KENNING_EX_AUTOML_BOARD:-max32690evkit/max32690/m4}   # ADI MAX32690 EV kit, the plugin's default target
APP_KB=${KENNING_EX_AUTOML_APP_KB:-85}                        # upstream example: 85 KB for the rest of the app
MINUTES=${KENNING_EX_AUTOML_MINUTES:-3}

build() { env_need automl; automl_search "$MINUTES" "$BOARD" "$APP_KB"; }
run() {
  build
  echo "== best model (automl_conf_0.yml) -> TFLite, kenning optimize test on the host"
  automl_eval_host "$EX_OUT/automl/automl_conf_0.yml" best
  summarize "$EX_OUT/measurements_best.json"
  f1 "$EX_OUT/measurements_best.json"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
