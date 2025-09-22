Integration tests for Nix-backed dataset tool (file-level CAS + symlink-tree).
Each test is named according to the GUID scheme you requested (NDS_AC_001 ...).

Prerequisites
-------------
- docker
- image: nixos/nix:latest will be pulled automatically by docker.
- Recommended: run as a user with permissions to create and own the host store directories, or run the scripts under sudo.

Files
-----
- run_in_container.sh   : helper to run commands inside the nix container
- add_dataset.sh        : helper that implements file-level CAS + symlink-tree + pin
- NDS_AC_001_add_inspect.sh
- NDS_AC_002_update_dedupe.sh
- NDS_AC_003_atomic_swap.sh
- NDS_AC_004_pin_unpin_gc.sh
- NDS_AC_005_export_import.sh

Usage
-----
Make the scripts executable (already set):
  chmod +x *.sh

Run a single test, e.g.:
  ./NDS_AC_001_add_inspect.sh

Each test creates a temporary host store under /tmp/nds-test-XXXX and mounts it into a nix container. The tests will print where the host store is for inspection.

Caveats
-------
- These tests operate on ephemeral host stores under /tmp; they will run `nix-collect-garbage -d` inside the host-store mount which may remove unreferenced store paths in that temporary store only.
- The tests **do not** touch your system /nix/store.
- If you need DB checks against your Rust CLI, integrate those assertions where noted: the current tests focus on validating the nix store operations, pins, and export/import behavior.

