#!/usr/bin/env python3
"""AP-06 real Pro PC Send to UTF-8 text, reusing proven AS2K physical Set-2 decoder.
No SRAM-derived text, no ROM interception, no fabricated Send success.
Only ASPRO-DIAG asmapro on isolated ASPRO-owned MAME build tree.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import tempfile
import zipfile

from rom_audit import audit_rom
from run_diag import ROOT, command, sha

KS0066_F05_SHA1 = "0196e871584ee5d370856e7307c0f9d1466e3e51"
OBSERVE = ROOT/"tools/ap06_pc_send_observe.lua"

def validate(rom:Path,lcd:Path,binary:Path):
    d=audit_rom(rom)
    if not d["expected_212"] or d["reset"]!="C000":
        raise ValueError("Pro 2.1.2 ROM mismatch")
    if len(lcd.read_bytes())!=4096 or hashlib.sha1(lcd.read_bytes()).hexdigest()!=KS0066_F05_SHA1:
        raise ValueError("KS0066 F05 ROM mismatch")
    exe=binary.resolve(strict=True)
    owned=(ROOT/"build/send-mame").resolve()
    if exe!=owned/"asprodiag" or exe.is_symlink():
        raise ValueError("not standalone ASPRO-DIAG SEND engine")
    manifest=json.loads((owned/".aspro-binary.json").read_text())
    if (manifest.get("feature")!="PC_SEND_PHYSICAL_SET2_TO_UTF8_TXT"
            or manifest.get("binary_sha256")!=sha(exe)
            or manifest.get("variant")!="ASPRO-DIAG"
            or manifest.get("functional_pass") is not False):
        raise ValueError("AP06 binary provenance mismatch")
    if not OBSERVE.is_file():
        raise ValueError("AP06 observer unavailable")
    return d,exe

def perform(rom:Path,lcd:Path,binary:Path):
    d,exe=validate(rom,lcd,binary)
    outroot=(ROOT/"private/ap06").resolve()
    if not outroot.is_relative_to(ROOT) or (ROOT/"private").is_symlink():
        raise ValueError("ASPRO-only output location required")
    outroot.mkdir(parents=True,exist_ok=True,mode=0o700)
    out=Path(tempfile.mkdtemp(prefix="send-",dir=outroot))
    for directory in ["nvram","cfg","state","input","snap","diff","home"]:
        (out/directory).mkdir(mode=0o700)
    # Reuse existing AP-03 debugger script to observe real ROM progress.
    from run_diag import debugger_script
    (out/"aspro_reset.cmd").write_text(debugger_script())
    report={"variant":"ASPRO-DIAG","rom_sha256":d["sha256"],
            "binary_sha256":sha(exe),"run_dir":str(out),
            "status":"EXECUTION_PENDING","functional_pass":False,
            "protocol":"REAL_PORTD_PS2_FRAMES_SET2_AS2K_DONOR",
            "expected_text":"abc","actual_txt_bytes":None,
            "screenshots":{},"rom_staging_clean":"PENDING"}
    proc=None
    try:
        with tempfile.TemporaryDirectory(prefix="roms-",dir=out) as t:
            staged=Path(t)
            for p,arc,mem in ((rom,"asmapro.zip","alphasmartpro212.rom"),
                              (lcd,"ks0066.zip","ks0066_f05.bin")):
                with zipfile.ZipFile(staged/arc,"w",zipfile.ZIP_STORED) as z:
                    z.write(p,arcname=mem)
            with zipfile.ZipFile(staged/"asmapro.zip") as z:
                if hashlib.sha256(z.read("alphasmartpro212.rom")).hexdigest()!=d["sha256"]:
                    raise ValueError("staged ROM mismatch")
            cmd=command(exe,out,staged,36,"none",[])
            cmd[cmd.index("-autoboot_script")+1]=str(OBSERVE)
            env=dict(os.environ,ASPRO_CAPTURE="1")
            def limit():
                resource.setrlimit(resource.RLIMIT_FSIZE,(1024*1024,1024*1024))
            with (out/"stdout.log").open("wb") as stdout,(out/"stderr.log").open("wb") as stderr:
                proc=subprocess.Popen(cmd,cwd=out,env=env,stdout=stdout,stderr=stderr,
                    start_new_session=True,preexec_fn=limit)
                try:
                    report["exit_code"]=proc.wait(timeout=240)
                except subprocess.TimeoutExpired:
                    report["status"]="TIMEOUT"
                    report["exit_code"]=None
        obs=(out/"observations.log").read_text() if (out/"observations.log").exists() else ""
        err=(out/"error.log").read_text(errors="replace") if (out/"error.log").exists() else ""
        for tag in ["LUA_ATTACHED","KEY_a_DOWN","KEY_b_DOWN","KEY_c_DOWN",
                    "PC_ATTACHED","KEY_send_DOWN","SEND_KEY_RELEASED",
                    "PC_DETACHED","OBSERVATION_COMPLETE","OBSERVATION_FAILED"]:
            report[tag]="ASPRO_AP06_"+tag+"\n" in obs
        for image in ["ready","typed_abc","host_attached","after_send","after_disconnect"]:
            f=out/"snap"/(image+".png")
            if f.is_file() and f.read_bytes()[:8]==b"\x89PNG\r\n\x1a\n":
                report["screenshots"][image]={"sha256":sha(f),"bytes":f.stat().st_size}
        txt=out/"snap/send.txt"
        if txt.is_file():
            raw=txt.read_bytes()
            report["actual_txt_bytes"]=len(raw)
            report["actual_txt_sha256"]=sha(txt)
            report["actual_txt_preview"]=raw[:256].decode("utf-8",errors="replace")
            report["text_is_exact"]=raw==b"abc"
        else:
            report["actual_txt_bytes"]=0
            report["text_is_exact"]=False
        report["physical_decoder_seen"]="ASPRO_PC_TXT_OPEN" in err
        report["physical_decoder_finished"]="ASPRO_PC_TXT_FINISHED" in err
        report["status"]=(
            "SEND_TXT_DYNAMIC_PASS"
            if report.get("exit_code")==0 and report["OBSERVATION_COMPLETE"]
            and not report["OBSERVATION_FAILED"] and report["PC_ATTACHED"]
            and report["KEY_send_DOWN"] and report["text_is_exact"]
            and report["physical_decoder_seen"]
            else "SEND_TXT_DYNAMIC_UNVERIFIED")
        report["functional_pass"]=report["status"]=="SEND_TXT_DYNAMIC_PASS"
    except (OSError,ValueError,subprocess.SubprocessError) as exc:
        report["status"]="SEND_EXECUTION_FAILED"
        report["error_type"]=type(exc).__name__
    finally:
        if proc:
            try: os.killpg(proc.pid,signal.SIGKILL)
            except ProcessLookupError: pass
            proc.wait()
        report["rom_staging_clean"]="COMPLETE" if not list(out.glob("roms-*")) else "FAILED"
        (out/"report.json").write_text(json.dumps(report,indent=2)+"\n")
    return report

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--rom",required=True,type=Path)
    p.add_argument("--lcd-rom",required=True,type=Path)
    p.add_argument("--bin",type=Path,default=ROOT/"build/send-mame/asprodiag")
    a=p.parse_args()
    os.umask(0o077)
    try: result=perform(a.rom,a.lcd_rom,a.bin)
    except (OSError,ValueError) as exc: p.exit(2,"BLOCKED_AP06: "+str(exc)+"\n")
    print(json.dumps(result,indent=2))
    return 0 if result["functional_pass"] else 4

if __name__=="__main__":
    raise SystemExit(main())
