#!/usr/bin/env python3
"""AP-06: read-only export of existing MAME into isolated ASPRO Send build.
Reuses only existing verified T640 MAME sources, not AS2K work outputs.
Never modifies the donor checkout.
"""
from __future__ import annotations
import argparse,hashlib,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OWN=(ROOT/"build").resolve()
NAME="send-mame"
MARKER=".aspro-send-source.json"
UPSTREAM="c4e48388ca620472643110db2941ce70aa5f3c07"
DONOR="AS2K-Emulator d66d8614314eb8bad20fdb4dc1e1aa21e148307d"

def digest(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for part in iter(lambda:f.read(1024*1024),b""):h.update(part)
    return h.hexdigest()

def check(target,driver):
    target=target.resolve()
    if target!=OWN/NAME or target.is_symlink() or (ROOT/"build").is_symlink():
        raise ValueError("destination must be ASPRO/build/send-mame without symlinks")
    marker=json.loads((target/MARKER).read_text())
    if (marker.get("destination")!=str(target)
        or marker.get("driver_sha256")!=digest(driver)
        or marker.get("driver_sha256")!=digest(target/"src/mame/skeleton/alphasma.cpp")
        or marker.get("feature")!="AP06_PC_SEND"):
        raise ValueError("AP06 driver marker mismatch")
    if not (target/"makefile").is_file():
        raise ValueError("missing MAME makefile")
    return marker

def refresh_driver():
    """Recompile only changed ASPRO driver in existing isolated MAME worktree.

    Refuses modifications to donor MAME and verifies the previously pinned copy
    before replacing it. All existing build objects/caches remain available.
    """
    target=OWN/NAME
    driver=ROOT/"src/mame/skeleton/alphasma.cpp"
    original=target/"src/mame/skeleton/alphasma.cpp"
    if (target.is_symlink() or (ROOT/"build").is_symlink()
            or not target.resolve()==OWN/NAME or original.is_symlink()
            or driver.is_symlink()):
        raise ValueError("APRO-only nonsymlink source/build directories required")
    marker=json.loads((target/MARKER).read_text())
    if (marker.get("feature")!="AP06_PC_SEND"
            or marker.get("destination")!=str(target)
            or not (target/"makefile").is_file()
            or digest(original)!=marker.get("driver_sha256")):
        raise ValueError("previous ASPRO source marker mismatch or changed worktree")
    if digest(driver)!=marker["driver_sha256"]:
        original.write_bytes(driver.read_bytes())
        marker["driver_sha256"]=digest(driver)
        (target/MARKER).write_text(json.dumps(marker,indent=2)+"\n")
    return check(target,driver)

def run(ref):
    if (ROOT/"build").is_symlink():
        raise ValueError("ASPRO/build cannot be symlink")
    target=OWN/NAME
    driver=ROOT/"src/mame/skeleton/alphasma.cpp"
    if not driver.is_file() or driver.is_symlink():
        raise ValueError("ASPRO Send driver missing")
    if (target/MARKER).exists():
        return check(target,driver)
    if target.exists():
        raise ValueError("unmarked existing ASPRO Send source tree; do not overwrite")
    ref=ref.resolve(strict=True)
    if not (ref/"makefile").is_file():
        raise ValueError("MAME reference makefile missing")
    sha=subprocess.check_output(
        ["git","-C",str(ref),"rev-parse","HEAD"],text=True).strip()
    if len(sha)!=40:
        raise ValueError("could not establish canonical MAME source HEAD")
    # Ensure source tree already knows AlphaSmart Pro and was prepared as MAME.
    original=(ref/"src/mame/skeleton/alphasma.cpp")
    text=original.read_text()
    if "asmapro" not in text or "MC68HC11D0" not in text:
        raise ValueError("reference driver lacks Pro / HC11")
    # Read-only archive of the *existing* T checkout HEAD. AS2K stays intact.
    OWN.mkdir(parents=True,exist_ok=True,mode=0o700)
    target.mkdir(mode=0o700)
    p=subprocess.Popen(["git","-C",str(ref),"archive",sha],stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=p.stdout,mode="r|") as archive:
            for member in archive:
                if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                    raise ValueError("unsupported archive member: "+member.name)
                dest=(target/member.name).resolve()
                if not dest.is_relative_to(target):
                    raise ValueError("archive escapes ASPRO build: "+member.name)
                # MAME Git includes links. Preserve only internal links, never
                # pointers into AS2K nor anywhere outside the ASPRO-owned copy.
                if member.issym():
                    resolved=(dest.parent/member.linkname).resolve()
                    if not resolved.is_relative_to(target):
                        raise ValueError("escaping source symlink: "+member.name)
                if member.islnk():
                    resolved=(target/member.linkname).resolve()
                    if not resolved.is_relative_to(target):
                        raise ValueError("escaping source hardlink: "+member.name)
                archive.extract(member,target)
        if p.wait()!=0:
            raise ValueError("reference Git archive failed")
        target_driver=target/"src/mame/skeleton/alphasma.cpp"
        if target_driver.is_symlink():
            raise ValueError("driver symlink forbidden")
        target_driver.write_bytes(driver.read_bytes())
        doc={"feature":"AP06_PC_SEND","destination":str(target),
             "source_head":sha,"source_driver_sha256":digest(original),
             "driver_sha256":digest(driver),"donor":DONOR,
             "canonical_upstream":UPSTREAM,"functional_pass":False}
        (target/MARKER).write_text(json.dumps(doc,indent=2)+"\n")
        return check(target,driver)
    finally:
        if p.poll() is None:
            p.kill();p.wait()
        p.stdout.close()

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference",type=Path)
    parser.add_argument("--check",action="store_true")
    parser.add_argument("--refresh-driver",action="store_true")
    x=parser.parse_args()
    if not x.check and not x.reference:
        parser.error("--reference is required to prepare")
    try:
        result=(refresh_driver() if x.refresh_driver else
                check(OWN/NAME,ROOT/"src/mame/skeleton/alphasma.cpp")
                if x.check else run(x.reference))
    except (OSError,ValueError,subprocess.SubprocessError,tarfile.TarError) as e:
        parser.exit(3,"AP06_PREP_BLOCKED: "+str(e)+"\n")
    print(json.dumps(result,indent=2))
