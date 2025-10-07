#!/usr/bin/env python3
"""
ndms_prototype.py - simple content-addressed dataset store for prototyping

Usage:
  python ndms_prototype.py --store /path/to/store add /path/to/input dataset-name
  python ndms_prototype.py --store /path/to/store pin dataset-name-<ts>  # after add (or pin accepts tree-id)
  python ndms_prototype.py --store /path/to/store unpin dataset-name-<ts>
  python ndms_prototype.py --store /path/to/store ls-roots
  python ndms_prototype.py --store /path/to/store gc
  python ndms_prototype.py --store /path/to/store export dataset-name-<ts> -o /tmp/d.tar
  python ndms_prototype.py --store /path/to/store import /tmp/d.tar --pin NAME
"""

import argparse, os, hashlib, json, shutil, tarfile, time, sys
from pathlib import Path

def sha256_hex(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1024*1024), b""):
            h.update(b)
    return h.hexdigest()

def ensure_dirs(root):
    Path(root).mkdir(parents=True, exist_ok=True)
    for p in ("store","trees","pins"):
        Path(root, p).mkdir(exist_ok=True)

def add_dataset(store_root, input_dir, name):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    tmp = Path(store_root, "tmp_add_" + str(int(time.time()*1000)))
    tmp.mkdir()
    tree_dir = tmp / "tree"
    tree_dir.mkdir()
    # copy files into tree by content store placement (physical store links)
    for src in Path(input_dir).rglob("*"):
        if src.is_file():
            rel = src.relative_to(input_dir)
            sha = sha256_hex(src)
            store_fname = f"{sha}-{src.name}"
            stored = store_root / "store" / store_fname
            if not stored.exists():
                stored.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, stored)
            dest = tree_dir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            # create symlink that points to physical store file (no cross-device hardlink)
            target = os.path.relpath(stored, dest.parent)
            os.symlink(target, dest)
    # compute tree id: hash of sorted listing and target names
    entries = []
    for p in sorted([p for p in tree_dir.rglob("*") if p.is_file() or p.is_symlink()]):
        entries.append(f"{p.relative_to(tree_dir)}->{os.readlink(p)}")
    tree_blob = "\n".join(entries).encode()
    treeid = hashlib.sha256(tree_blob).hexdigest()[:16]
    tree_name = f"{treeid}-{name}"
    tree_store_path = store_root / "trees" / tree_name
    if tree_store_path.exists():
        shutil.rmtree(tmp)
        return str("/trees/" + tree_name)
    shutil.move(str(tree_dir), str(tree_store_path))
    # save metadata
    meta = {"id": treeid, "name": name, "entries": entries, "created": int(time.time())}
    with open(store_root / "trees" / (tree_name + ".json"), "w") as f:
        json.dump(meta, f)
    shutil.rmtree(tmp, ignore_errors=True)
    return "/trees/" + tree_name

def pin_tree(store_root, tree_ref, pin_name):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    # tree_ref can be the tree path or ID
    if tree_ref.startswith("/trees/"):
        tree = Path(store_root, tree_ref.lstrip("/"))
    else:
        # try to find by prefix match
        candidates = list(Path(store_root,"trees").glob(f"{tree_ref}-*"))
        if not candidates:
            raise SystemExit("tree not found")
        tree = candidates[0]
    pin_path = Path(store_root,"pins",pin_name)
    if pin_path.exists():
        raise SystemExit("pin already exists")
    os.symlink(os.path.relpath(tree, pin_path.parent), pin_path)
    print(f"pinned {pin_name} -> {tree.name}")
    return

def unpin(store_root, pin_name):
    p = Path(store_root,"pins",pin_name)
    if not p.exists():
        print("pin not found")
        return
    p.unlink()
    print("unpinned", pin_name)

def list_roots(store_root):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    for p in sorted((store_root/"pins").iterdir()):
        if p.is_symlink():
            tgt = os.readlink(p)
            print(f"{p.name} -> {tgt}")

def collect_gc(store_root, dry=False):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    # build set of referenced store files from pinned trees
    keep_store_files = set()
    def add_tree_refs(tree_path):
        # walk tree_path and resolve symlink targets relative to each symlink parent
        for s in (tree_path).rglob("*"):
            if s.is_symlink():
                target = os.readlink(s)
                # resolve to absolute path anchored at tree parent
                abs_target = (s.parent / target).resolve()
                # only consider files under store_root/store
                try:
                    abs_target.relative_to(store_root/"store")
                    keep_store_files.add(str(abs_target))
                except Exception:
                    pass
    # collect pinned trees
    pins_dir = store_root/"pins"
    for p in pins_dir.iterdir():
        if p.is_symlink():
            tree_rel = os.readlink(p)
            tree_path = (p.parent / tree_rel).resolve()
            add_tree_refs(tree_path)
    # Now scan store dir and delete any file not in keep_store_files
    store_dir = store_root/"store"
    deleted = []
    for f in store_dir.iterdir():
        if not f.is_file():
            continue
        if str(f) not in keep_store_files:
            deleted.append(f)
            if not dry:
                f.unlink()
    print(f"GC: kept {len(keep_store_files)} store files, deleted {len(deleted)}")
    for d in deleted:
        print("  deleted", d.name)

def export_tree(store_root, tree_ref, outpath):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    if tree_ref.startswith("/trees/"):
        tree = Path(store_root, tree_ref.lstrip("/"))
    else:
        candidates = list(Path(store_root,"trees").glob(f"{tree_ref}-*"))
        if not candidates:
            raise SystemExit("tree not found")
        tree = candidates[0]
    to_export = []
    for s in tree.rglob("*"):
        if s.is_symlink():
            target = os.path.realpath(s)
            if Path(target).exists():
                to_export.append(Path(target))
    with tarfile.open(outpath, "w:gz") as t:
        # include tree dir structure (as names) and store files
        t.add(tree, arcname=f"tree/{tree.name}")
        for f in to_export:
            t.add(f, arcname=f"store/{f.name}")
    print("exported", outpath)

def import_tar(store_root, tarpath, pin_name=None):
    store_root = Path(store_root)
    ensure_dirs(store_root)
    with tarfile.open(tarpath, "r:gz") as t:
        for member in t.getmembers():
            if member.name.startswith("store/"):
                # extract store file to store dir
                target_name = os.path.basename(member.name)
                dest = store_root/"store"/target_name
                if not dest.exists():
                    t.extract(member, path=store_root)
                    # when tarfile extracts it will create tree/store/<name>; move it up
                    possible = store_root/member.name
                    if possible.exists():
                        possible.rename(dest)
            elif member.name.startswith("tree/"):
                # extract tree dir (may contain symlinks)
                t.extract(member, path=store_root)
                # we already place the tree under store_root/tree/<name>
    print("imported", tarpath)
    # optional: create pin to the imported tree if pin_name provided
    if pin_name:
        # find any tree we just imported (pick first)
        for tr in (store_root/"trees").iterdir():
            if tr.is_dir() and tr.name.startswith(tuple([str(int(time.time()))])): # best-effort - not deterministic
                try:
                    pin_tree(store_root, "/trees/"+tr.name, pin_name)
                    print("pinned imported tree as", pin_name)
                except Exception as e:
                    print("pin failed:", e)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--store", required=True, help="store root directory")
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("add")
    p.add_argument("input_dir")
    p.add_argument("name")

    p = sub.add_parser("pin")
    p.add_argument("tree_ref")
    p.add_argument("pin_name")

    p = sub.add_parser("unpin")
    p.add_argument("pin_name")

    sub.add_parser("ls-roots")
    sub.add_parser("gc")

    p = sub.add_parser("export")
    p.add_argument("tree_ref")
    p.add_argument("-o","--out", required=True)

    p = sub.add_parser("import")
    p.add_argument("tarball")
    p.add_argument("--pin", required=False)

    args = ap.parse_args()

    store = args.store

    if args.cmd == "add":
        tree = add_dataset(store, args.input_dir, args.name)
        print("tree created:", tree)
    elif args.cmd == "pin":
        pin_tree(store, args.tree_ref, args.pin_name)
    elif args.cmd == "unpin":
        unpin(store, args.pin_name)
    elif args.cmd == "ls-roots":
        list_roots(store)
    elif args.cmd == "gc":
        collect_gc(store)
    elif args.cmd == "export":
        export_tree(store, args.tree_ref, args.out)
    elif args.cmd == "import":
        import_tar(store, args.tarball, pin_name=args.pin)
    else:
        ap.print_help()

if __name__ == "__main__":
    main()

