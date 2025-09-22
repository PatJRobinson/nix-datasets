set -euo pipefail
# Usage: add_dataset.sh /path/to/input-dir /path/to/host/pins dataset-name
IN_DIR="$1"
NIX_STORE_DIR="$2"
PINS_DIR="$3"
NAME="$4"

WORK=$(mktemp -d)
SYMLINK_TREE="$WORK/symlink_tree"
mkdir -p "$SYMLINK_TREE"

# add each file (preserve relative paths)
find "$IN_DIR" -type f | while read -r file; do
  rel=${file#${IN_DIR}/}
  destdir=$(dirname "$SYMLINK_TREE/$rel")
  mkdir -p "$destdir"
  file_store=$(nix-store --add-fixed sha256 --store $NIX_STORE_DIR "$file")
  ln -s "$file_store" "$SYMLINK_TREE/$rel"
done

dataset_store=$(nix-store --add-fixed --recursive sha256 --store $NIX_STORE_DIR "$SYMLINK_TREE")
ts=$(date -u +%Y%m%dT%H%M%SZ)
PIN_NAME="${NAME}-${ts}"
mkdir -p "$PINS_DIR"
pin_name_res=$(nix-store --store $NIX_STORE_DIR --realise $dataset_store --add-root "$PINS_DIR/$PIN_NAME" --indirect  || true)

echo "$dataset_store|$PIN_NAME"
rm -rf "$WORK"
