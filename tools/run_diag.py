#!/usr/bin/env python3
"""Run only real ASPRO-DIAG; private inputs, bounded observation, no inferred PASS."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
import zipfile
from rom_audit import audit_rom
from prepare_mame import validate_tree, COMMIT

ROOT = Path(__file__).resolve().parents[1]
KS0066_F05_SHA1 = '0196e871584ee5d370856e7307c0f9d1466e3e51'
LOG_LIMIT = 1024*1024

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda:f.read(1024*1024),b''): h.update(part)
    return h.hexdigest()

def validate_inputs(rom, lcd_rom, binary):
    audit=audit_rom(rom)
    if not audit['expected_212'] or audit['reset']!='C000' or not audit['reset_lds_00ff']:
        raise ValueError('unverified AlphaSmart Pro 2.1.2 identity/reset')
    lcd=lcd_rom.read_bytes()
    if len(lcd)!=4096 or hashlib.sha1(lcd).hexdigest()!=KS0066_F05_SHA1:
        raise ValueError('unverified KS0066 F05 identity')
    binary=binary.resolve(strict=True)
    if binary.name!='asprodiag' or not binary.is_file() or not os.access(binary,os.X_OK):
        raise ValueError('only an executable named asprodiag is allowed')
    info=json.loads((binary.parent/'.aspro-binary.json').read_text())
    with binary.open('rb') as f:
        native=f.read(4)==b'\x7fELF'
    if not native or info.get('binary_sha256')!=sha(binary):
        raise ValueError('binary hash/ELF mismatch')
    if info.get('mode')=='adopted_prebuilt_as2kdiag':
        if (binary.parent!=(ROOT/'build/prebuilt').resolve()
            or info.get('machine')!='asmapro'
            or info.get('rom_sha1')!='c3c6a421c9ced92db97431d04b4a3f09a39de716'
            or info.get('probe')!='listxml_asmapro'
            or info.get('donor_sha256')!=info.get('binary_sha256')):
            raise ValueError('unverified adopted DIAG binary')
    else:
        validate_tree(binary.parent)
        if info.get('source_commit')!=COMMIT or info.get('subtarget')!='asprodiag':
            raise ValueError('binary build provenance mismatch; run tools/build_diag.sh')
    return audit,binary

def debugger_script():
    # Register/MMIO locations are valid only with the pinned HC11 reset INIT=0.
    # Later relocated-register traffic is not claimed to be observed here.
    lines=['temp%d = 0'%n for n in range(8)]
    specs=[('bp C000','temp0','RESET_ENTRY','pc,sp','PC=%04X SP=%04X'),
           ('bp C003','temp1','AFTER_LDS','pc,sp','PC=%04X SP=%04X'),
           ('wpset FFFE,2,r','temp2','VECTOR_READ','wpaddr','ADDR=%04X'),
           ('wpset 8000,1,r','temp3','KB_READ','pc','PC=%04X'),
           ('wpset 8000,1,w','temp4','KB_HIGH_W','pc','PC=%04X'),
           ('wpset C000,1,w','temp5','KB_LOW_W','pc','PC=%04X'),
           ('wpset 0000,1,w','temp6','PORTA_W','pc,((wpdata>>3)&1)|((wpdata>>4)&2)','PC=%04X BANK=%X'),
           ('wpset 0008,1,w','temp7','LCD_PORTD_W','pc','PC=%04X')]
    for prefix,counter,tag,values,fmt in specs:
        # Hex literals: c=12 samples max per probe; RESET only once.
        limit='1' if counter in ('temp0','temp1') else 'c'
        lines.append(f'{prefix},{counter}<{limit},{{ {counter}++ ; logerror "ASPRO_{tag} {fmt}\\n",{values} ; g }}')
    lines.append('g')
    return '\n'.join(lines)+'\n'

def video_mode(requested):
    if requested=='none': return 'none',[]
    if os.environ.get('DISPLAY'): return 'soft',[]
    if shutil.which('xvfb-run') and shutil.which('xauth'): return 'soft',['xvfb-run','-a']
    if requested=='soft': raise ValueError('capture requires DISPLAY or xvfb-run + xauth')
    return 'none',[]

def command(binary,out,rom_dir,seconds,video,prefix):
    return prefix+[str(binary),'asmapro','-noreadconfig',
        '-rompath',str(rom_dir),'-nvram_directory',str(out/'nvram'),
        '-cfg_directory',str(out/'cfg'),'-state_directory',str(out/'state'),
        '-input_directory',str(out/'input'),'-snapshot_directory',str(out/'snap'),
        '-diff_directory',str(out/'diff'),'-homepath',str(out/'home'),
        '-debug','-debugger','none','-debugscript',str(out/'aspro_reset.cmd'),
        '-autoboot_delay','0','-autoboot_script',str(ROOT/'tools/ap02_observe.lua'),
        '-log','-video',video,'-window','-sound','none','-nothrottle',
        '-skip_gameinfo','-seconds_to_run',str(seconds)]

def collect_evidence(out):
    error=(out/'error.log').read_text(errors='replace') if (out/'error.log').exists() else ''
    obs=(out/'observations.log').read_text(errors='replace') if (out/'observations.log').exists() else ''
    tags=['RESET_ENTRY','AFTER_LDS','VECTOR_READ','KB_READ','KB_HIGH_W','KB_LOW_W','PORTA_W','LCD_PORTD_W']
    evidence={tag:('OBSERVED' if 'ASPRO_'+tag+' ' in error else 'UNVERIFIED') for tag in tags}
    evidence['lcd_bus_write']='UNVERIFIED'  # PORTD activity alone is not KS0066 write proof
    evidence['keyboard_injection']='OBSERVED' if 'ASPRO_KEY_DOWN_A\n' in obs and 'ASPRO_KEY_UP_A\n' in obs else 'UNVERIFIED'
    evidence['frame_change_after_key']='OBSERVED_CORRELATION_ONLY' if 'ASPRO_LCD_CHANGED_AFTER_KEY\n' in obs else 'UNVERIFIED'
    evidence['observation_complete']='OBSERVED' if 'ASPRO_OBSERVATION_COMPLETE\n' in obs else 'UNVERIFIED'
    evidence['lcd_nonuniform']='OBSERVED' if 'ASPRO_LCD_NONUNIFORM\n' in obs else 'UNVERIFIED'
    # MAME error logs/debugger parse failures remain private; report no source data.
    evidence['debugger_errors']='DETECTED' if any(s in error.lower() for s in ['error in command','unknown command','syntax error']) else 'NOT_DETECTED_UNVERIFIED'
    shots={}
    for name in ['before','after']:
        p=out/'snap'/(name+'.png')
        if p.is_file() and p.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n':
            shots[name]={'sha256':sha(p),'bytes':p.stat().st_size}
    evidence['screenshots']=shots or 'PENDING'
    return evidence

def run_session(rom,lcd_rom,binary,out_root,seconds=8,capture='auto'):
    audit,binary=validate_inputs(rom,lcd_rom,binary)
    video,prefix=video_mode(capture)
    out_root=out_root.resolve()
    # Outputs must stay private and must not overlap AS2K or public Git paths.
    private=(ROOT/'private').resolve()
    if not private.is_relative_to(ROOT) or not out_root.is_relative_to(private):
        raise ValueError('output must be inside this ASPRO checkout/private')
    out_root.mkdir(parents=True,exist_ok=True,mode=0o700)
    os.chmod(out_root,0o700)
    out=Path(tempfile.mkdtemp(prefix='diag-',dir=out_root))
    for name in ['nvram','cfg','state','input','snap','diff','home']:
        (out/name).mkdir(mode=0o700)
    (out/'aspro_reset.cmd').write_text(debugger_script())
    report={'variant':'ASPRO-DIAG','system':'asmapro','status':'EXECUTION_PENDING',
            'functional_pass':False,'rom_sha256':audit['sha256'],'lcd_sha1':KS0066_F05_SHA1,
            'binary_sha256':sha(binary),'video':video,'seconds_requested':seconds,
            'run_dir':str(out),'functional_keyboard':'UNVERIFIED','lcd_text':'UNVERIFIED',
            'note':'Process exit, MMIO activity, snapshot change and injected key are not functional PASS.'}
    def limit_logs(): resource.setrlimit(resource.RLIMIT_FSIZE,(LOG_LIMIT,LOG_LIMIT))
    process=None
    try:
        # TemporaryDirectory covers *all* setup failures as well as subprocess exits.
        with tempfile.TemporaryDirectory(prefix='roms-',dir=out) as staging:
            rom_dir=Path(staging)
            for path,name,member in [(rom,'asmapro.zip','alphasmartpro212.rom'),
                                     (lcd_rom,'ks0066.zip','ks0066_f05.bin')]:
                with zipfile.ZipFile(rom_dir/name,'w',zipfile.ZIP_STORED) as z:
                    z.write(path,arcname=member)
            # Check the staged bytes too, preventing a mutable-input race.
            with zipfile.ZipFile(rom_dir/'asmapro.zip') as z:
                if hashlib.sha256(z.read('alphasmartpro212.rom')).hexdigest()!=audit['sha256']:
                    raise ValueError('ROM changed during staging')
            with zipfile.ZipFile(rom_dir/'ks0066.zip') as z:
                if hashlib.sha1(z.read('ks0066_f05.bin')).hexdigest()!=KS0066_F05_SHA1:
                    raise ValueError('LCD ROM changed during staging')
            env=os.environ.copy();env['ASPRO_CAPTURE']='0' if capture=='none' else '1'
            with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
                process=subprocess.Popen(command(binary,out,rom_dir,seconds,video,prefix),cwd=out,
                    env=env,stdout=stdout,stderr=stderr,start_new_session=True,preexec_fn=limit_logs)
                try:
                    report['exit_code']=process.wait(timeout=max(45,seconds*8))
                    report['status']='PROCESS_EXIT_0_FUNCTIONAL_UNVERIFIED' if process.returncode==0 else 'PROCESS_FAILED'
                except subprocess.TimeoutExpired:
                    report['status']='PROCESS_TIMEOUT';report['exit_code']=None
    except (OSError,ValueError) as exc:
        report['status']='PREPARATION_OR_LAUNCH_FAILED'
        report['error_type']=type(exc).__name__  # do not log private data/path details
    finally:
        if process:
            # Terminate only our session, including a surviving Xvfb child.
            try: os.killpg(process.pid,signal.SIGKILL)
            except ProcessLookupError: pass
            process.wait()
        report['evidence']=collect_evidence(out)
        report['input_cleanup']='COMPLETE' if not list(out.glob('roms-*')) else 'FAILED'
        if report['status']=='PROCESS_EXIT_0_FUNCTIONAL_UNVERIFIED' and (
            report['evidence']['observation_complete']!='OBSERVED' or
            report['evidence']['AFTER_LDS']!='OBSERVED' or
            report['evidence']['debugger_errors']=='DETECTED'):
            report['status']='INSTRUMENTATION_INCOMPLETE'
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom',type=Path,required=True);p.add_argument('--lcd-rom',type=Path,required=True)
    p.add_argument('--bin',dest='binary',type=Path,required=True)
    p.add_argument('--out',type=Path,default=ROOT/'private/diag')
    p.add_argument('--seconds',type=int,default=8)
    p.add_argument('--capture',choices=['auto','none','soft'],default='auto')
    a=p.parse_args(argv)
    if not 6<=a.seconds<=30: p.error('--seconds must be 6..30 (50 Hz observation ends at frame 240)')
    os.umask(0o077)
    try: report=run_session(a.rom,a.lcd_rom,a.binary,a.out,a.seconds,a.capture)
    except (OSError,ValueError) as exc:
        p.exit(2,'BLOCKED_INPUT_OR_CAPTURE: '+str(exc)+'\n')
    print(json.dumps(report,indent=2))
    return 0 if report['status']=='PROCESS_EXIT_0_FUNCTIONAL_UNVERIFIED' else 4
if __name__=='__main__': raise SystemExit(main())
