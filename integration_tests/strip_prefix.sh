#!/usr/bin/env bash
# strip - remove a leading prefix from each stdin line
# Usage: strip PREFIX
# Example: list_symlink_tree.sh | strip /nix-datasets

set -euo pipefail

if [ $# -ne 1 ]; then
  printf 'Usage: %s PREFIX\n' "$(basename "$0")" >&2
  exit 2
fi

prefix="$1"

# Normalize prefix: don't force a trailing slash, we'll handle both cases.
# But remember the slash-terminated variant for convenience.
prefix_slash="${prefix%/}/"   # ensures exactly one trailing slash

# Read stdin line-by-line safely, handle last line without newline
while IFS= read -r line || [ -n "$line" ]; do
  # strip a trailing CR if present
  line=${line%$'\r'}

  if [[ "$line" == "$prefix_slash"* ]]; then
    # strip the prefix including the trailing slash -> "foo/bar" from "/nix-datasets/foo/bar"
    printf '%s\n' "${line#"$prefix_slash"}"
  elif [[ "$line" == "$prefix"* ]]; then
    # strip the prefix without a trailing slash -> e.g. "/nix-datasets" -> ""
    # this preserves the remainder (may be empty)
    printf '%s\n' "${line#"$prefix"}"
  else
    # leave unchanged
    printf '%s\n' "$line"
  fi
done
