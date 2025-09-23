#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_001 - Add + Inspect
# Creates temp host store, runs container, adds dataset with two files, verifies pin and store entries.
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"

echo "TMP dir at: $HOST_BASE"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP"
# note: for many nix operations the store dir is expected to be root-owned.
# If tests fail with permission errors, run with sudo or adjust ownership.

# create sample dataset
INCOMING="$HOST_TMP/incoming"
mkdir -p "$INCOMING"
echo "file A" > "$INCOMING/A.txt"
echo "file B" > "$INCOMING/B.txt"

# copy helper script into HOST_TMP so container can run it
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"

# run add_dataset inside container
RESULT=$(bash $(dirname "$0")/run_in_container.sh "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/incoming /nix-datasets /pins mydataset")
echo "Result: $RESULT"
DATASET_STORE=$(echo "$RESULT" | cut -d'|' -f1)
PIN_NAME=$(echo "$RESULT" | cut -d'|' -f2)

echo "Dataset store: $DATASET_STORE"
echo "Pin: $PIN_NAME"

# verify pin exists on host
if [ ! -L "$HOST_PINS/$PIN_NAME" ]; then
  echo "❌ Pin symlink missing: $HOST_PINS/$PIN_NAME" >&2
  exit 1
fi

# verify nix-store knows the requisites (files)
bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --store /nix-datasets --query --requisites $DATASET_STORE" | sed -n '1,200p'

echo "✅ NDS_AC_001 passed: dataset added, pinned, and reports requisites."
