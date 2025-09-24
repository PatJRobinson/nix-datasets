#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_005 - Export and Import
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"
IMPORT_BASE="$HOST_BASE/import-store"

echo "HOST_BASE is $HOST_BASE"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "$IMPORT_BASE"
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"

# create dataset
IN="$HOST_TMP/in"; mkdir -p "$IN"; echo "X" > "$IN/x.txt"
RES=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in /nix-datasets /pins mydataset")
S=$(echo "$RES" | cut -d'|' -f1)
echo "S is $S"
OUT_NAR="$HOST_TMP/dataset.nar"

# import into a fresh store (simulate remote)
IMPORT_STORE="$IMPORT_BASE/nix-store"
IMPORT_VAR="$IMPORT_BASE/nix-var"
IMPORT_PINS="$IMPORT_BASE/pins"
mkdir -p "$IMPORT_STORE" "$IMPORT_VAR" "$IMPORT_PINS"

# in your script, after you compute S and IMPORT_STORE/IMPORT_VAR
STORE_B=$(basename "$S")   # e.g. d87klybp7ic2...-x.txt
echo "STORE_B is $STORE_B"

SCRIPTS="$IMPORT_BASE/scripts"
mkdir -p "$SCRIPTS"
cp "$(dirname "$0")/add_dataset.sh" "$SCRIPTS"

ls $HOST_STORE/${STORE_B}/x.txt
ls -l $HOST_STORE/${STORE_B}/x.txt
readlink $HOST_STORE/${STORE_B}/x.txt
file_name="$(basename "$(readlink $HOST_STORE/${STORE_B}/x.txt)")"
echo "File is $file_name"

# right - it hates mounting anything to /nix/store - understandably
# however, the symlinks are hard-coded to /nix/store
# and... readlink, etc, apparently aren't capable of reliably getting the path
# under the symlink, if the symlink isn't valid, which it cant be, becuase of the 
# above two conditions. Solution: create the input directory using a neutral container
# , then we can mount /nix/store no problem, run through the symlinks and rebuild the 
# tree. Then, run 'add_dataset' in the nix container as before. Phew
docker run --rm \
  -v "$SCRIPTS":/host/scripts \
  -v "$HOST_STORE":/host/store:ro \
  -v "$IMPORT_STORE":/nix-datasets/nix/store \
  -v "$HOST_VAR":/host/var:ro \
  -v "$IMPORT_VAR":/nix-datasets/nix/var \
  -v "$IMPORT_PINS":/pins \
  --workdir / \
  nixos/nix:latest \
  bash -c "
    ls /host/store/${STORE_B}/x.txt
    ls -l /host/store/${STORE_B}/x.txt
    readlink /host/store/${STORE_B}/x.txt
    file_name="$(basename "$(readlink /host/store/${STORE_B}/x.txt)")"
    echo "File is $file_name"


    mkdir input_dir
    cp /host/store/$file_name input_dir
    ls input_dir
    /host/scripts/add_dataset.sh input_dir /nix-datasets /pins mydataset

 "

echo "Imported into fresh store at $IMPORT_BASE"
echo "NDS_AC_005 done. You can inspect $IMPORT_BASE to verify imported paths."
