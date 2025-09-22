#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_005 - Export and Import
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"
IMPORT_BASE="$HOST_BASE/import-store"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "$IMPORT_BASE"
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"

# create dataset
IN="$HOST_BASE/in"; mkdir -p "$IN"; echo "X" > "$IN/x.txt"
RES=$(bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in /pins mydataset")
S=$(echo "$RES" | cut -d'|' -f1)

# export closure to nar
OUT_NAR="$HOST_BASE/dataset.nar"
bash -c "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --export \$(nix-store --query --requisites $S) > /tmp/dataset.nar"
# copy nar to host tmp
docker run --rm -v "$HOST_STORE":/nix/store -v "$HOST_VAR":/nix/var -v "$HOST_PINS":/pins -v "$HOST_TMP":/tmp nixos/nix:latest sh -c "cat /tmp/dataset.nar" > "$OUT_NAR"

# import into a fresh store (simulate remote)
IMPORT_STORE="$IMPORT_BASE/nix-store"
IMPORT_VAR="$IMPORT_BASE/nix-var"
IMPORT_PINS="$IMPORT_BASE/pins"
mkdir -p "$IMPORT_STORE" "$IMPORT_VAR" "$IMPORT_PINS"
# import using a container with mounts pointing to IMPORT_*
docker run --rm -v "$IMPORT_STORE":/nix/store -v "$IMPORT_VAR":/nix/var -v "$IMPORT_PINS":/pins -i nixos/nix:latest sh -c "nix-store --import" < "$OUT_NAR"

echo "Imported into fresh store at $IMPORT_BASE"
echo "NDS_AC_005 done. You can inspect $IMPORT_BASE to verify imported paths."
