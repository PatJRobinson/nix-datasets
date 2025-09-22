#!/usr/bin/env bash
set -euo pipefail
#
# NDS_AC_002 - Update with partial change (dedupe)

HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP"
echo "HOST_BASE=$HOST_BASE"

# initial dataset with A and B
IN1="$HOST_TMP/in1"
mkdir -p "$IN1"
echo "A" > "$IN1/A.txt"
echo "B_v1" > "$IN1/B.txt"

cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"

bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in1 /nix-datasets /pins mydataset"

FIRST_STORE=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP " "ls -l /pins | sed -n '1p' || true" || true)

# capture per-file store paths by querying requisites then filtering for files (heuristic)
DATASET_STORE=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --store /nix-datasets --query --requisites /pins/* | sed -n '1,200p' | head -n 1" )

read A1 B1 < <(bash "$(dirname "$0")/run_in_container.sh" \
  "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" \
  "PIN=\$(ls -1 /pins | tail -n1); \
   SYM=\$(readlink /pins/\$PIN); \
   A=\$(readlink /nix-datasets\$SYM/A.txt); \
   B=\$(readlink /nix-datasets\$SYM/B.txt); \
   echo \$A \$B")

# create updated dataset: B changed, C new
IN2="$HOST_TMP/in2"
mkdir -p "$IN2"
echo "A" > "$IN2/A.txt"
echo "B_v2" > "$IN2/B.txt"
echo "C" > "$IN2/C.txt"
bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in2 /nix-datasets /pins mydataset"

echo "NDS_AC_002 executed: please manually inspect that unchanged files were deduped."

read A2 B2 C2 < <(bash "$(dirname "$0")/run_in_container.sh" \
  "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" \
  "PIN=\$(ls -1 /pins | tail -n1); \
   SYM=\$(readlink /pins/\$PIN); \
   A=\$(readlink /nix-datasets\$SYM/A.txt); \
   B=\$(readlink /nix-datasets\$SYM/B.txt); \
   C=\$(readlink /nix-datasets\$SYM/B.txt); \
   echo \$A \$B \$C")

# 3. assertions
if [[ "$A1" != "$A2" ]]; then
  echo "❌ FAIL: A.txt was not deduplicated (store paths differ: $A1 vs $A2)"
  exit 1
fi
if [[ "$B1" == "$B2" ]]; then
  echo "❌ FAIL: B.txt was incorrectly deduplicated (expected new path but got $B2)"
  exit 1
fi
if [[ -z "$C2" ]]; then
  echo "❌ FAIL: C.txt missing from second dataset"
  exit 1
fi

echo "✅ NDS_AC_002 passed: dedupe worked (A same, B new, C new)."
