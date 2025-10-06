# inside container: remove the pin, then remove any dangling gcroots that pointed to it
VAR_PATH="$1"
PIN_PATH="$2"

# remove pin file (user-visible)
rm -f "$PIN_PATH"

# remove dangling auto gcroots that point to non-existent targets
for g in $VAR_PATH/nix/gcroots/auto/*; do
  # skip if glob didn't match
  [ -e "$g" ] || continue

  # What the auto symlink points to (could be /pins/foo)
  tgt="$(readlink "$g" 2>/dev/null || true)"

  # If the target is empty or doesn't exist on the filesystem, this auto root is dangling.
  if [ -z "$tgt" ] || [ ! -e "$tgt" ]; then
    echo "Removing dangling gcroot: $g -> $tgt"
    rm -f "$g"
  fi
done
