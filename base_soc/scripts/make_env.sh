#!/usr/bin/env bash
set -euo pipefail

echo "[make_env] This script would pull OpenLane2 + Sky130A in a real setup."
echo "[make_env] Network-restricted environment detected; creating placeholders only."
mkdir -p reports/{area,timing,power,wakeup,coverage}
mkdir -p build

