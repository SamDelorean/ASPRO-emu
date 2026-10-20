#!/usr/bin/env python3
"""AP-04: real ASPRO-DIAG two-session F1-F8 / backed SRAM campaign.
Never launches MAME generic or the AS2K donor. All outputs stay ASPRO-private.
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

from run_diag import ROOT, command, debugger_script, validate_inputs, sha

SECONDS = 116
OBSERVER = ROOT / "tools/ap04_files_observe.lua"

def hash_tree(where):
    records = []
    for f in sorted(p for p in where.rglob("*") if p.is_file()):
        records.append({"relative": str(f.relative_to(where)),
                        "bytes": f.stat().st_size, "sha256": sha(f)})
    return records

def one_phase(binary, stage, base, shared_nvram, phase):
    run = base / phase
    run.mkdir(mode=0o700)
    for name in ["cfg", "state", "input", "snap", "diff", "home"]:
        (run/name).mkdir(mode=0o700)
    (run/"aspro_reset.cmd").write_text(debugger_script())
    cmd = command(binary, run, stage, SECONDS, "none", [])
    cmd[cmd.index("-nvram_directory")+1] = str(shared_nvram)
    cmd[cmd.index("-autoboot_script")+1] = str(OBSERVER)
    env = dict(os.environ, ASPRO_CAPTURE="1", ASPRO_AP04_PHASE=phase)
    def limit():
        resource.setrlimit(resource.RLIMIT_FSIZE, (1024*1024,1024*1024))
    status = {"phase": phase, "exit_code": None, "complete": False}
    proc = None
    try:
        with (run/"stdout.log").open("wb") as stdout, (run/"stderr.log").open("wb") as stderr:
            proc = subprocess.Popen(cmd, cwd=run, env=env, stdout=stdout, stderr=stderr,
                                    start_new_session=True, preexec_fn=limit)
            try:
                status["exit_code"] = proc.wait(timeout=440)
            except subprocess.TimeoutExpired:
                status["reason"] = "PROCESS_TIMEOUT"
    finally:
        if proc:
            try: os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            proc.wait()
    obs = (run/"observations.log")
    event_text = obs.read_text() if obs.is_file() else ""
    prefix = "ASPRO_AP04_" + phase + "_"
    status["complete"] = prefix+"OBSERVATION_COMPLETE\n" in event_text
    status["events"] = [
        {"name": k, "observed": (prefix+k+"\n" in event_text)}
        for k in ["LUA_ATTACHED", "KEY_F1_DOWN", "KEY_F8_UP", "SNAPSHOT_F1",
                  "SNAPSHOT_F8", "OBSERVATION_COMPLETE", "OBSERVATION_FAILED"]
    ]
    status["screenshots"] = {}
    for i in range(1,9):
        p = run/"snap"/f"f{i}.png"
        if p.is_file() and p.read_bytes()[:8]==b"\x89PNG\r\n\x1a\n":
            status["screenshots"][f"f{i}"]={"sha256":sha(p), "bytes":p.stat().st_size}
    status["screen_count"] = len(status["screenshots"])
    status["result"] = ("CAPTURED_PENDING_VISUAL_REVIEW"
                        if status["complete"] and status["screen_count"]==8
                        and status["exit_code"]==0 else "UNVERIFIED")
    return status

def campaign(rom, lcd, binary):
    audit, binary = validate_inputs(rom, lcd, binary)
    if not OBSERVER.is_file():
        raise ValueError("AP04 Lua observer missing")
    base = (ROOT/"private/ap04").resolve()
    if not base.is_relative_to(ROOT) or (ROOT/"private").is_symlink():
        raise ValueError("output path outside independent ASPRO workspace")
    base.mkdir(parents=True,exist_ok=True,mode=0o700)
    work = Path(tempfile.mkdtemp(prefix="campaign-",dir=base))
    shared_nvram=work/"nvram"
    shared_nvram.mkdir(mode=0o700)
    report={"variant":"ASPRO-DIAG", "system":"asmapro",
            "status":"PENDING", "functional_pass":False,
            "rom_sha256":audit["sha256"], "binary_sha256":sha(binary),
            "run_dir":str(work), "phases":[], "nvram_after_write":[],
            "nvram_after_reboot":[], "inputs_cleanup":"PENDING",
            "interpretation":"Visual evidence required; screenshot hash difference alone is not file/persistence PASS"}
    try:
        with tempfile.TemporaryDirectory(prefix="roms-",dir=work) as tmp:
            stage=Path(tmp)
            for file,name,member in [(rom,"asmapro.zip","alphasmartpro212.rom"),
                                     (lcd,"ks0066.zip","ks0066_f05.bin")]:
                with zipfile.ZipFile(stage/name,"w",zipfile.ZIP_STORED) as z:
                    z.write(file,arcname=member)
            with zipfile.ZipFile(stage/"asmapro.zip") as z:
                if hashlib.sha256(z.read("alphasmartpro212.rom")).hexdigest()!=audit["sha256"]:
                    raise ValueError("ROM stage identity mismatch")
            for phase in ("write","verify"):
                p=one_phase(binary,stage,work,shared_nvram,phase)
                report["phases"].append(p)
                if phase=="write":
                    report["nvram_after_write"]=hash_tree(shared_nvram)
                    if not report["nvram_after_write"]:
                        report["status"]="NO_PERSISTED_NVRAM_AFTER_FIRST_EXIT"
                        break
                if p["result"]!="CAPTURED_PENDING_VISUAL_REVIEW":
                    report["status"]="PHASE_INCOMPLETE"
                    break
            else:
                report["nvram_after_reboot"]=hash_tree(shared_nvram)
                report["status"]="TWO_SESSIONS_CAPTURED_PENDING_VISUAL_QUALIFICATION"
    except (OSError,ValueError,subprocess.SubprocessError) as e:
        report["status"]="EXECUTION_FAILED"
        report["error_type"]=type(e).__name__
    finally:
        report["inputs_cleanup"]="COMPLETE" if not list(work.glob("roms-*")) else "FAILED"
        (work/"report.json").write_text(json.dumps(report,indent=2)+"\n")
    return report

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom",type=Path,required=True)
    p.add_argument("--lcd-rom",type=Path,required=True)
    p.add_argument("--bin",dest="binary",type=Path,
                   default=ROOT/"build/prebuilt/asprodiag")
    a=p.parse_args()
    os.umask(0o077)
    try:
        result=campaign(a.rom,a.lcd_rom,a.binary)
    except (OSError,ValueError) as exc:
        p.exit(2,"BLOCKED_INPUT: "+str(exc)+"\n")
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result["status"]=="TWO_SESSIONS_CAPTURED_PENDING_VISUAL_QUALIFICATION" else 4)
