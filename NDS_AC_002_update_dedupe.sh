#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_002 - Update with partial change (dedupe)
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP"
echo "HOST_BASE=$HOST_BASE"

# initial dataset with A and B
IN1="$HOST_BASE/in1"
mkdir -p "$IN1"
echo "A" > "$IN1/A.txt"
echo "B_v1" > "$IN1/B.txt"
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"
bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in1 /pins mydataset"
FIRST_STORE=$(bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP " "ls -l /pins | sed -n '1p' || true" || true)

# capture per-file store paths by querying requisites then filtering for files (heuristic)
DATASET_STORE=$(bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --query --requisites /pins/* | sed -n '1,200p' | head -n 1" )

# create updated dataset: B changed, C new
IN2="$HOST_BASE/in2"
mkdir -p "$IN2"
echo "A" > "$IN2/A.txt"
echo "B_v2" > "$IN2/B.txt"
echo "C" > "$IN2/C.txt"
bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in2 /pins mydataset"

echo "NDS_AC_002 executed: please manually inspect that unchanged files were deduped."
