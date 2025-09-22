#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 5 ]; then
  cat <<'USAGE' >&2
Usage:
  run_in_container.sh HOST_STORE HOST_VAR HOST_PINS HOST_TMP <cmd...>

Example:
  ./run_in_container.sh /tmp/host-store /tmp/host-var /tmp/pins /tmp/tmpdir "nix-store --query --requisites /nix/store/abcd"
USAGE
  exit 2
fi

HOST_STORE="$1"
HOST_VAR="$2"
HOST_PINS="$3"
HOST_TMP="$4"
shift 4

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for these integration tests" >&2
  exit 3
fi

# Join the remaining args into a single command string
CMD="$*"
echo "COMMAND WAS: $CMD" >> log.txt
docker run --rm \
  -v "${HOST_STORE}":/tool/nix/store \
  -v "${HOST_VAR}":/tool/nix/var \
  -v "${HOST_PINS}":/pins \
  -v "${HOST_TMP}":/tmp \
  nix-with-bash \
  bash -c "${CMD}"
