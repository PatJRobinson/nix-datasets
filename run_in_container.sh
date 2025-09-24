#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 5 ]; then
  cat <<'USAGE' >&2
Usage:
  run_in_container.sh HOST_STORE HOST_VAR HOST_PINS HOST_TMP <cmd...>

Example:
  ./run_in_container.sh /tmp/host-store /tmp/host-var /tmp/pins /tmp/tmpdir "nix-store --query --requisites /nix-datasets/<hash>"
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

# Join remaining args into a single command script
CMD="$*"

# stream the command script into the container's bash -s -- 
# (safe: no nested quoting, expansions/$(...) run inside the container)
printf '%s\n' "$CMD" | docker run --rm -i \
  -v "${HOST_STORE}":/nix-datasets/nix/store \
  -v "${HOST_VAR}":/nix-datasets/nix/var \
  -v "${HOST_PINS}":/pins \
  -v "${HOST_TMP}":/tmp \
  nixos/nix:latest \
  bash -s --
