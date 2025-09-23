#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_004 - Pin/unpin and GC
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP"
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"

# create two versions
IN1="$HOST_TMP/in1"; mkdir -p "$IN1"; echo "A" > "$IN1/a.txt"
RES1=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in1 /nix-datasets /pins mydataset")
S1=$(echo "$RES1" | cut -d'|' -f1)
PIN1=$(echo "$RES1" | cut -d'|' -f2)

IN2="$HOST_TMP/in2"; mkdir -p "$IN2"; echo "B" > "$IN2/b.txt"
RES2=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in2 /nix-datasets /pins mydataset")
S2=$(echo "$RES2" | cut -d'|' -f1)
PIN2=$(echo "$RES2" | cut -d'|' -f2)

# unpin first
rm -f "$HOST_PINS/$PIN1"

# run GC inside container (danger: this will prune unreferenced store items in host_store)
bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-collect-garbage -d" 

# check S1 removed
if [ -e "$HOST_STORE/$(basename "$S1")" ]; then
  echo "S1 still present (expected to be removed if unreferenced)" >&2
else
  echo "S1 removed as expected"
fi

echo "NDS_AC_004 done (verify results)."
