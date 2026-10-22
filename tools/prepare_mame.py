#!/usr/bin/env python3
"""Export only pinned tracked MAME source into ASPRO-owned build storage."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
COMMIT = 'c4e48388ca620472643110db2941ce70aa5f3c07'
DRIVER_SHA256 = 'bb2cd7f14366c7dc58a7af6e2961b5f70e670cc54a23770d3ff0b5e1ff776cf6'
LCD_SHA256 = 'd4fda79297278886de911253a7c2f112ab3004d6fb448cc509619cb0d011bd6d'
MARKER = '.aspro-source.json'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_tree(tree: Path):
    tree = tree.resolve()
    if not (ROOT/'build').resolve().is_relative_to(ROOT):
        raise ValueError('ASPRO build directory escapes project')
    if not tree.is_relative_to((ROOT/'build').resolve()) or tree == (ROOT/'build').resolve():
        raise ValueError('build tree must be a child of this ASPRO checkout/build')
    info = json.loads((tree/MARKER).read_text())
    if info != {'source_commit': COMMIT, 'destination': str(tree)}:
        raise ValueError('ASPRO source ownership/commit marker mismatch')
    for name, expected in [('src/mame/skeleton/alphasma.cpp', DRIVER_SHA256),
                           ('src/devices/video/hd44780.cpp', LCD_SHA256)]:
        path = tree/name
        if not path.resolve().is_relative_to(tree) or digest(path) != expected:
            raise ValueError('pinned MAME source identity mismatch: '+name)
    if not (tree/'makefile').is_file():
        raise ValueError('complete MAME source tree/makefile missing')
    # Output/cache paths must never resolve into a reference tree.
    for path in tree.rglob('*'):
        if path.is_symlink() and not path.resolve().is_relative_to(tree):
            raise ValueError('build tree contains an escaping symlink')
    return info

def prepare(source: Path, destination: Path):
    raise ValueError('BLOCKED_RETIRED: no duplicate MAME export; continue incrementally in build/send-mame')
    source = source.resolve(strict=True)
    destination = destination.resolve()
    owned = (ROOT/'build').resolve()
    if not owned.is_relative_to(ROOT):
        raise ValueError('ASPRO build directory escapes project')
    if (not destination.is_relative_to(owned) or destination == owned
            or destination.is_relative_to(source) or source.is_relative_to(destination)):
        raise ValueError('source/destination overlap or destination outside ASPRO/build')
    if destination.exists():
        return validate_tree(destination)  # reuse only our verified tree
    resolved = subprocess.check_output(['git','-C',str(source),'rev-parse',COMMIT+'^{commit}'],text=True).strip()
    if resolved != COMMIT:
        raise ValueError('pinned source commit unavailable in reference Git objects')
    destination.parent.mkdir(parents=True,exist_ok=True)
    # Stream git archive to tar: no source worktree writes, no objects/caches,
    # no private/untracked input copied, no second Git database.
    proc = subprocess.Popen(['git','-C',str(source),'archive',COMMIT],stdout=subprocess.PIPE)
    destination.mkdir(mode=0o700)
    try:
        with tarfile.open(fileobj=proc.stdout,mode='r|') as archive:
            for member in archive:
                # The pinned MAME tree needs regular source files/directories;
                # refusing links prevents output aliases into AS2K.
                if not (member.isfile() or member.isdir()):
                    raise ValueError('source archive contains unsupported link/special member')
                if not (destination/member.name).resolve().is_relative_to(destination):
                    raise ValueError('source archive escapes destination')
                archive.extract(member,destination)
        if proc.wait() != 0:
            raise ValueError('git archive failed')
        (destination/MARKER).write_text(json.dumps({'source_commit':COMMIT,'destination':str(destination)},indent=2)+'\n')
        return validate_tree(destination)
    except BaseException:
        proc.kill();proc.wait()
        # Keep incomplete destination for diagnosis; never recursively delete
        # pre-existing/user files. It has no valid marker and cannot be built.
        (destination/MARKER).unlink(missing_ok=True)
        raise
    finally:
        proc.stdout.close()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path)
    p.add_argument('--dest',type=Path,default=ROOT/'build/mame')
    p.add_argument('--check',action='store_true')
    a=p.parse_args()
    if not a.check and not a.source: p.error('--source is required for preparation')
    try:
        result=validate_tree(a.dest) if a.check else prepare(a.source,a.dest)
    except (OSError,ValueError,subprocess.CalledProcessError) as exc:
        p.exit(2,'BLOCKED_MAME_SOURCE: '+str(exc)+'\n')
    print(json.dumps(result,sort_keys=True))
if __name__=='__main__': main()
