#!/usr/bin/env bash
set -euo pipefail
# NDS_AC_003 - Atomic pointer swap (basic)
HOST_BASE=$(mktemp -d /tmp/nds-test-XXXXXX)
HOST_STORE="$HOST_BASE/nix-store"
HOST_VAR="$HOST_BASE/nix-var"
HOST_PINS="$HOST_BASE/pins"
HOST_TMP="$HOST_BASE/tmp"

mkdir -p "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP"
echo "HOST_BASE=$HOST_BASE"

# add first version
IN1="$HOST_TMP/in1"
mkdir -p "$IN1"
echo "V1" > "$IN1/x.txt"
cp "$(dirname "$0")/add_dataset.sh" "$HOST_TMP/"
RES1=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in1 /nix-datasets /nix-datasets /pins mydataset")
S1=$(echo "$RES1" | cut -d'|' -f1)
sleep 1

# add second version
IN2="$HOST_TMP/in2"
mkdir -p "$IN2"
echo "V2" > "$IN2/x.txt"
RES2=$(bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "/tmp/add_dataset.sh /tmp/in2 /nix-datasets /pins mydataset")
S2=$(echo "$RES2" | cut -d'|' -f1)

# create a tmp pointer and atomically swap
ln -s "$S2" "$HOST_PINS/mydataset-current.tmp"
# register root inside container for the tmp (so it's protected)
bash "$(dirname "$0")/run_in_container.sh" "$HOST_STORE" "$HOST_VAR" "$HOST_PINS" "$HOST_TMP" "nix-store --store /nix-datasets --realise --add-root /pins/mydataset-current.tmp --indirect $S2" || true
mv -T "$HOST_PINS/mydataset-current.tmp" "$HOST_PINS/mydataset-current"

if [ "$(readlink "$HOST_PINS/mydataset-current")" != "$S2" ]; then
  echo "❌ Atomic swap failed" >&2
  exit 1
fi

echo "✅ NDS_AC_003 passed: atomic pointer points to new version."
