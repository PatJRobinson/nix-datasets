#!/usr/bin/env bash
set -euo pipefail

# list_symlink_tree.sh - List absolute symlink entries and the absolute targets they point to.
# Usage: list_symlink_tree.sh /path/to/symlink-tree
# Outputs two sections:
#   --- SYMLINKS ---
#   (absolute symlink paths)
#
#   --- TARGETS ---
#   (absolute target paths, canonicalized where possible)

usage() {
  cat <<'EOF' >&2
Usage: list_symlink_tree.sh /path/to/symlink-tree

Prints two sections:
  -- SYMLINKS --  : absolute paths of every symlink under the tree
  -- TARGETS  --  : absolute target paths the symlinks point to (canonicalized)
EOF
  exit 2
}

[ "${1:-}" ] || usage
ROOT="$1"

# Normalize ROOT to an absolute path (must exist)
if [ ! -e "$ROOT" ] && [ ! -L "$ROOT" ]; then
  echo "Error: root path does not exist: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$ROOT")" && pwd -P)/$(basename "$ROOT")"

echo "$ROOT"

# Choose canonicalizer: prefer realpath -m, then readlink -m, then python3, else bash fallback
canonicalize_cmd=""
if command -v realpath >/dev/null 2>&1; then
  if realpath -m / >/dev/null 2>&1; then
    canonicalize_cmd="realpath -m --"
  fi
fi
if [ -z "$canonicalize_cmd" ] && command -v readlink >/dev/null 2>&1; then
  # some readlink support -m
  if readlink -m / >/dev/null 2>&1; then
    canonicalize_cmd="readlink -m --"
  fi
fi
if [ -z "$canonicalize_cmd" ] && command -v python3 >/dev/null 2>&1; then
  canonicalize_cmd="python3 -c 'import os,sys;print(os.path.normpath(sys.argv[1]))'"
fi

# Bash-only normalizer (no external deps). Used if no canonicalizer found.
normalize_bash() {
  # normalize without resolving symlinks; handles .. and . components
  local p="$1"
  local abs=false
  if [[ "$p" == /* ]]; then abs=true; fi

  # split by '/' into array
  IFS='/' read -r -a parts <<< "$p"
  local -a stack=()
  for part in "${parts[@]}"; do
    case "$part" in
      ''|'.') continue ;;
      '..')
        if [ "${#stack[@]}" -gt 0 ]; then
          unset 'stack[${#stack[@]}-1]'
        fi
        ;;
      *) stack+=("$part") ;;
    esac
  done

  local out
  if $abs; then
    out="/"
    if [ "${#stack[@]}" -gt 0 ]; then
      out="/$(printf '%s' "${stack[0]}")"
      for ((i=1;i<${#stack[@]};i++)); do
        out="$out/${stack[i]}"
      done
    fi
  else
    if [ "${#stack[@]}" -eq 0 ]; then
      out="."
    else
      out="${stack[0]}"
      for ((i=1;i<${#stack[@]};i++)); do
        out="$out/${stack[i]}"
      done
    fi
  fi
  printf '%s' "$out"
}

canonicalize_path() {
  local p="$1"
  if [ -n "$canonicalize_cmd" ]; then
    # If python fallback command is selected, it requires passing the argument differently.
    if [[ "$canonicalize_cmd" == python3* ]]; then
      # Use python command with argument
      python3 -c 'import os,sys;print(os.path.normpath(sys.argv[1]))' "$p"
    else
      $canonicalize_cmd "$p"
    fi
  else
    normalize_bash "$p"
  fi
}

# Collect symlinks and targets
declare -a symlinks
declare -A targets_map  # map for uniqueness

# find symlinks (use -type l) and iterate robustly with NUL separation
while IFS= read -r -d $'\0' entry; do
  # produce absolute path for the symlink entry
  # If find gave absolute path already (we passed ROOT absolute), use it as is
  symlinks+=("$entry")

  # read literal target stored in the symlink (may be absolute or relative)
  target_literal="$(readlink -- "$entry" 2>/dev/null || true)"

  # compute absolute target: if literal begins with / it's absolute; else join with symlink dir
  if [ -z "$target_literal" ]; then
    absolute_target=""
  else
    if [[ "$target_literal" == /* ]]; then
      absolute_target="$target_literal"
    else
      linkdir="$(dirname "$entry")"
      joined="$linkdir/$target_literal"
      absolute_target="$(canonicalize_path "$joined")"
    fi
  fi

  # add to targets_map (use empty-string key if empty)
  targets_map["$absolute_target"]=1
done < <(find "$ROOT" -type l -print0)

# Print symlink list
for s in "${symlinks[@]}"; do
  echo "$s"
done

for t in "${!targets_map[@]}"; do
  # Print non-empty targets first; then print empty/failed lines if any
  :
done

# Print sorted targets (non-empty then empty). Sorting for determinism.
# collect non-empty targets
non_empty=()
empty_seen=false
for t in "${!targets_map[@]}"; do
  if [ -z "$t" ]; then
    empty_seen=true
  else
    non_empty+=("$t")
  fi
done

if [ "${#non_empty[@]}" -gt 0 ]; then
  # sort and print
  printf '%s\n' "${non_empty[@]}" | sort -u
fi
if $empty_seen; then
  echo "<(empty or unreadable target)>" >&2
  echo ""
fi
