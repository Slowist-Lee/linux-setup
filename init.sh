#!/usr/bin/env bash
# Modular interactive setup entry point. Tool implementations live in ./linux-setup/modules/.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd -P)"
exec bash "$ROOT/linux-setup/run.sh" "$@"
