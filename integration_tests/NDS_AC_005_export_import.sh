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
cp "$(dirname "$0")/list_symlink_tree.sh" "$HOST_TMP/"
cp "$(dirname "$0")/strip_prefix.sh" "$HOST_TMP/"

# create dataset
IN="$HOST_TMP/in"; mkdir -p "$IN"; echo "X" > "$IN/x.txt"
RES=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in /nix-datasets /pins mydataset")
S=$(echo "$RES" | cut -d'|' -f1)
echo "S is $S"

# export closure to nar
OUT_NAR="$HOST_TMP/dataset.nar"

bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --store /nix-datasets --export \$(/tmp/list_symlink_tree.sh /nix-datasets$S | /tmp/strip_prefix.sh /nix-datasets)" > "$OUT_NAR"

# import into a fresh store (simulate remote)
IMPORT_STORE="$IMPORT_BASE/nix-store"
IMPORT_VAR="$IMPORT_BASE/nix-var"
IMPORT_PINS="$IMPORT_BASE/pins"
PIN_NAME="$(ls $HOST_PINS | head -1)"
mkdir -p "$IMPORT_STORE" "$IMPORT_VAR" "$IMPORT_PINS"

# import and register pin on target in one liner (target mounts defined)
docker run --rm -v "$IMPORT_STORE":/nix-datasets/nix/store -v "$IMPORT_VAR":/nix-datasets/nix/var -v "$IMPORT_PINS":/pins -i nixos/nix:latest \
  sh -c "nix-store --store /nix-datasets --import && nix-store --store /nix-datasets --realise '$S' --add-root /pins/'$PIN_NAME' --indirect" < "$OUT_NAR"

echo "Imported into fresh store at $IMPORT_BASE"
echo "NDS_AC_005 done. You can inspect $IMPORT_BASE to verify imported paths."
