#!/bin/sh
set -eu

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$APP_DIR"

python3 backend/detector_api.py &
DETECTOR_PID=$!

cleanup() {
  kill "$DETECTOR_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if ! curl --silent --show-error --fail --max-time 2 \
  --retry 45 --retry-connrefused --retry-delay 1 \
  http://127.0.0.1:8765/health >/dev/null 2>&1; then
  echo 'The TynsAI detector bridge did not start.' >&2
  exit 1
fi

flutter run -d chrome