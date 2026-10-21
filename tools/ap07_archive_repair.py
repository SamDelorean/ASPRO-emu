#!/usr/bin/env python3
"""AP07: one bounded incremental MAME archive-member corruption recovery.

Only repairs a linker-identified malformed ELF member in ASPRO's independent
build/send-mame. Never touches the AS2K donor or any unrelated tree.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / "build" / "send-mame"
ARCHIVES = PRIVATE / "build" / "linux_gcc" / "bin" / "x64" / "Release"
PATTERN = re.compile(r"(?P<archive>lib[a-z0-9_]+\.a)\((?P<member>[a-z0-9_]+)\.o\)")
CORRUPTION = ("bad reloc symbol index", "has a section extending past end of file")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tree", type=Path, required=True)
    p.add_argument("--link-log", type=Path, required=True)
    a = p.parse_args()
    tree = a.tree.absolute()
    if tree != PRIVATE.absolute() or tree.is_symlink() or PRIVATE.parent.is_symlink():
        p.error("only private independent ASPRO MAME may be repaired")
    log = a.link_log.absolute()
    if log != tree / ".ap07-first-link.log" or log.is_symlink():
        p.error("only the current AP07 MAME link error log is accepted")
    lines = log.read_text(errors="replace").splitlines()
    matches = []
    for line in lines:
        if not any(token in line for token in CORRUPTION):
            continue
        match = PATTERN.search(line)
        if match:
            matches.append((match.group("archive"), match.group("member")))
    if len(set(matches)) != 1:
        p.error("one unambiguous malformed archive member required: " + repr(matches))
    archive_name, member = matches[0]
    archive = ARCHIVES / archive_name
    if not archive.is_file() or archive.is_symlink():
        p.error("private MAME archive missing or symlinked: " + str(archive))
    # The source name is not guessed. Search only within the independently
    # exported MAME source subtree; require exactly one real C++ source.
    source_root = tree / "src"
    sources = [item for item in source_root.rglob(member + ".cpp")
               if item.is_file() and not item.is_symlink()]
    if len(sources) != 1 or not sources[0].resolve().is_relative_to(source_root):
        p.error("no unique private C++ source found for " + member + ": " +
                repr([str(x) for x in sources]))
    source = sources[0]
    # Archive name, member and source path are all obtained from actual
    # linker evidence and verified private tree membership.
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    sha = digest.hexdigest()
    backup_root = tree / ".ap07-corrupt-archives"
    if backup_root.is_symlink():
        p.error("unsafe archive-backup location")
    backup_root.mkdir(mode=0o700, exist_ok=True)
    original = backup_root / f"{archive_name}.{member}.{sha}.a"
    if original.exists() or original.is_symlink():
        p.error("same corrupt archive was already repaired; refuse retry loop")
    # Preserve the old archive unchanged. Rebuild precisely the affected
    # object by making its source newer than all prior MAME object outputs.
    os.replace(archive, original)
    source.touch()
    print(f"AP07_ARCHIVE_REPAIR source={source.relative_to(tree)}")
    print(f"AP07_ARCHIVE_REPAIR previous_archive={original.relative_to(tree)}")
    print(f"AP07_ARCHIVE_REPAIR sha256={sha}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
