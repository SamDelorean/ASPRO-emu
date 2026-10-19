#!/usr/bin/env python3
"""Adopt an existing MAME-DIAG engine into ASPRO, without executing any ROM."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tempfile
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
EXPECTED_SHA1='c3c6a421c9ced92db97431d04b4a3f09a39de716'

def sha256(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def adopt(source):
    if source.is_symlink() or not source.is_file() or not os.access(source,os.X_OK):
        raise ValueError('reference DIAG executable missing/aliased')
    result=subprocess.run([str(source),'-listxml','asmapro','-noreadconfig'],
                          capture_output=True,text=True,timeout=30,check=False)
    if result.returncode:
        raise ValueError('asmapro is not listed by existing DIAG engine')
    root=ET.fromstring(result.stdout)
    machine=root.find("./machine[@name='asmapro']")
    if machine is None or not any(x.get('name')=='alphasmartpro212.rom' and
       x.get('sha1','').lower()==EXPECTED_SHA1 for x in machine.findall('.//rom')):
        raise ValueError('reference engine lacks Pro 2.1.2 ROM definition')
    target=(ROOT/'build/prebuilt').resolve()
    if not target.is_relative_to(ROOT) or (ROOT/'build').is_symlink():
        raise ValueError('unsafe ASPRO destination')
    target.mkdir(parents=True,exist_ok=True,mode=0o700)
    dest=target/'asprodiag'
    if dest.is_symlink(): raise ValueError('target executable may not be a symlink')
    source_sha=sha256(source)
    with tempfile.NamedTemporaryFile(dir=target,prefix='.asprodiag-',delete=False) as fp:
        staged=Path(fp.name)
    try:
        shutil.copy2(source,staged)  # full independent copy, never hardlink
        if sha256(staged)!=source_sha: raise ValueError('copy hash mismatch')
        with staged.open('rb') as fp:
            if fp.read(4)!=b'\x7fELF': raise ValueError('non-ELF donor executable')
        staged.chmod(staged.stat().st_mode | 0o500)
        os.replace(staged,dest)
    finally:
        staged.unlink(missing_ok=True)
    manifest={'mode':'adopted_prebuilt_as2kdiag','binary_sha256':source_sha,
              'donor_sha256':source_sha,'machine':'asmapro',
              'rom_sha1':EXPECTED_SHA1,'probe':'listxml_asmapro',
              'functional_pass':False}
    (target/'.aspro-binary.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return {'status':'ENGINE_ADOPTED_FUNCTIONAL_UNVERIFIED',
            'sha256':source_sha,'destination':str(dest)}

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--reference-bin',type=Path,required=True)
    a=p.parse_args()
    try: print(json.dumps(adopt(a.reference_bin),indent=2))
    except (OSError,ValueError,ET.ParseError,subprocess.TimeoutExpired) as e:
        p.exit(3,'ADOPTION_UNAVAILABLE: '+str(e)+'\n')
