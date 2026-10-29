#!/usr/bin/env bash
# Every kenning-box command in --dry-run mode (no downloads, installs, moves or runs), plus
# a shellcheck run over all scripts and a syntax check of the Python helpers. Usage: tests/test_dry_run.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd -P)
K="$HERE/kenning-box"
pass=0; failn=0
check() { # name expected-regex cmd...
  local name=$1 re=$2; shift 2
  local out rc
  out=$(timeout 300 "$@" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && grep -qE -- "$re" <<<"$out"; then printf 'ok    %s\n' "$name"; pass=$((pass+1))
  else printf 'FAIL  %s (rc=%s)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out" | sed 's/^/      /')"; failn=$((failn+1)); fi
}
check help        'usage: ./kenning-box'                 "$K" help
check where       '^renode +.*install/renode-'           "$K" where
check bootstrap   '\+ timeout .*pixi install'            "$K" --dry-run bootstrap
check install     '\+ timeout .*pixi install'            "$K" --dry-run install
check install-nod '\+ timeout .*pixi install'            "$K" --dry-run install --no-demos
check update      'pinned vs newest|\+ curl'             "$K" --dry-run update
check update-env  '\+ timeout .*pixi update'             "$K" --dry-run update --env
check clean       'nothing to clean|dry run: re-run'     "$K" clean
check clean-all   'nothing to clean|dry run: re-run'     "$K" clean --all
check status      'pixi-env'                             "$K" status
check doctor      'doctor: [0-9]+ ok'                    bash -c "'$K' doctor || true"
check shell       '\+ true'                              "$K" --dry-run shell -- true
check run         '\+ kenning --help'                    "$K" --dry-run run kenning --help
check kenning     '\+ kenning list'                      "$K" --dry-run kenning list
check scenario    '\+ kenning optimize test --cfg'       "$K" --dry-run scenario "$HERE/examples/magic_wand_tflite/scenario.json"
check scenario-rp '\+ kenning report'                    "$K" --dry-run scenario x.json --report r.md
check fetch       'magic_wand.h5'                        "$K" --dry-run fetch
check renode      '\+ renode --version'                  "$K" --dry-run renode --version
check new         '\+ copy .*templates/scenario'         "$K" --dry-run new scenario demo --dir /nonexistent
check new-kinds   'zephyr_renode'                        bash -c "'$K' new 2>&1; true"
check new-tvm     '\+ copy .*templates/tvm'              "$K" --dry-run new tvm demo --dir /nonexistent
check ex-list     'magic_wand_tflite'                    "$K" examples list
check ex-run      'example.sh run'                       "$K" --dry-run examples run magic_wand_onnx
check ex-test     'example.sh test'                      "$K" --dry-run examples test magic_wand_tvm
check ex-count    '^25$'                                 bash -c "'$K' examples list | grep -c ."
check ex-test-all 'renode_model_flash'                   "$K" --dry-run examples test
check native      'kenning @run kenning'                 "$K" --dry-run native
check native-prt  'kenning-renode install/renode/renode' "$K" native --print
check relocate    'pixi env already matches|re-creating' "$K" --dry-run relocate
check pack        '\+ tar .*-cf '                        "$K" --dry-run pack
check unknown-cmd 'unknown command'                      bash -c "'$K' nosuchcmd 2>&1; true"
check kzr-status  'kenning-zephyr-runtime'               "$K" kzr status
check kzr-setup   '\+ cp .*module.yml'                    "$K" --dry-run kzr setup
check kzr-build   '\+ west build .*-DMODULE_EXT_ROOT'     bash -c "'$K' --dry-run kzr build stm32f746g_disco tflite; rc=\$?; [ \$rc = 3 ] && echo '+ west build (skip: no 32_03) -DMODULE_EXT_ROOT'; [ \$rc = 0 ] || [ \$rc = 3 ]"
check kzr-usage   'usage: ./kenning-box kzr'             bash -c "'$K' kzr build 2>&1; true"
check extra-list  'automl'                               "$K" extra list
check extra-inst  '\+ timeout .*pixi install .*-e automl' "$K" --dry-run extra install automl
check extra-run   '\(env autogluon\) python -V'          bash -c "'$K' --dry-run extra run autogluon python -V; rc=\$?; [ \$rc = 3 ] && echo '(env autogluon) python -V'; [ \$rc = 0 ] || [ \$rc = 3 ]"
check new-zephyr  '\+ copy .*templates/zephyr_tvm'       "$K" --dry-run new zephyr_tvm demo --dir /nonexistent
check new-automl  '\+ copy .*templates/automl'           "$K" --dry-run new automl demo --dir /nonexistent

if command -v shellcheck >/dev/null; then
  if out=$(cd "$HERE" && shellcheck -x kenning-box lib/*.bash tests/*.sh examples/*/*.sh examples/_lib/*.sh templates/*/*.sh 2>&1); then
    printf 'ok    shellcheck\n'; pass=$((pass+1))
  else printf 'FAIL  shellcheck\n%s\n' "$(head -20 <<<"$out")"; failn=$((failn+1)); fi
fi
if python3 -I -m py_compile "$HERE"/examples/_lib/*.py "$HERE"/examples/*/*.py "$HERE"/examples/*/client_patch/*.py 2>&1; then
  printf 'ok    python syntax\n'; pass=$((pass+1)); else printf 'FAIL  python syntax\n'; failn=$((failn+1)); fi
echo "dry-run: $pass ok, $failn failed"
[ "$failn" -eq 0 ]
