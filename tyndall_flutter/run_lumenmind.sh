#!/bin/sh
set -eu

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$APP_DIR"

if [ ! -f web/wasm/tyndall_detector.js ] ||
  [ ! -f web/wasm/tyndall_detector.wasm ] ||
  [ ! -f web/wasm/tyndall_detector.data ]; then
  sh tool/build_tynsai_wasm.sh
fi

flutter run -d chrome