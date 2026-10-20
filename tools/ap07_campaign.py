#!/usr/bin/env python3
"""AP-07: ASPRO-DIAG only, POST-SCI injection vs stock boot, never authentic SCI."""
from __future__ import annotations
import argparse,hashlib,json,os,resource,signal,subprocess,tempfile,zipfile
from pathlib import Path
from rom_audit import audit_rom
from run_diag import ROOT,command,sha,video_mode,KS0066_F05_SHA1

def launch(exe,rom,lcd,payload,hold,mode):
    outroot=ROOT/"private/ap07"
    outroot.mkdir(parents=True,exist_ok=True)
    out=Path(tempfile.mkdtemp(prefix="campaign-"+mode+"-",dir=outroot))
    for name in ("nvram","cfg","state","input","snap","diff","home"):
        (out/name).mkdir(mode=0o700)
    (out/"aspro_reset.cmd").write_text("g\n")
    observer=ROOT/"tools/ap07_observe.lua"
    lua=(out/"observe.lua")
    lua.write_text(observer.read_text().replace("AP07_EXPECTED_HOLD",str(hold))
                   .replace("AP07_BOOT_MODE",str(1 if mode=="bootstrap" else 0)))
    if mode=="bootstrap":
        (out/"snap/payload0_pro.bin").write_bytes(payload)
    rep={"mode":mode,"run_dir":str(out),"status":"PENDING",
         "authentic_sci":False,"functional_pass":False,"payload_sha256":hashlib.sha256(payload).hexdigest()}
    proc=None
    try:
        with tempfile.TemporaryDirectory(prefix="roms-",dir=out) as temp:
            staged=Path(temp)
            for p,zname,member in ((rom,"asmapro.zip","alphasmartpro212.rom"),
                                   (lcd,"ks0066.zip","ks0066_f05.bin")):
                with zipfile.ZipFile(staged/zname,"w",zipfile.ZIP_STORED) as z:
                    z.write(p,arcname=member)
            video,prefix=video_mode("auto")
            cmd=command(exe,out,staged,8 if mode=="bootstrap" else 15,video,prefix)
            cmd[cmd.index("-autoboot_script")+1]=str(lua)
            with (out/"stdout.log").open("wb") as stdout,(out/"stderr.log").open("wb") as stderr:
                def limit():resource.setrlimit(resource.RLIMIT_FSIZE,(16*1024*1024,16*1024*1024))
                proc=subprocess.Popen(cmd,cwd=out,stdout=stdout,stderr=stderr,start_new_session=True,preexec_fn=limit)
                try:rep["exit_code"]=proc.wait(timeout=140)
                except subprocess.TimeoutExpired:rep["exit_code"]=None;rep["status"]="TIMEOUT"
    finally:
        if proc:
            try:os.killpg(proc.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            proc.wait()
        obs=(out/"observations.log").read_text(errors="replace") if (out/"observations.log").exists() else ""
        err=(out/"error.log").read_text(errors="replace") if (out/"error.log").exists() else ""
        rep["cpu_hold_observed"]="AP07_PC_HOLD\n" in obs
        rep["observer_complete"]="AP07_OBSERVATION_COMPLETE\n" in obs
        rep["normal_key_a_down"]="AP07_NORMAL_KEY_A_DOWN\n" in obs
        rep["normal_key_a_up"]="AP07_NORMAL_KEY_A_UP\n" in obs
        rep["post_sci_injection_seen"]="ASPRO_AP07_POST_SCI_BOOTSTRAP_INJECTION" in err
        shot=out/"snap/bootstrap.png"
        rep["snapshot_sha256"]=sha(shot) if shot.exists() else None
        rep["status"]=("POST_SCI_CPU_HOLD_OBSERVED_VISUAL_UNVERIFIED"
            if mode=="bootstrap" and rep.get("exit_code")==0 and rep["cpu_hold_observed"]
            and rep["post_sci_injection_seen"] else
            "NORMAL_BOOT_PROCESS_OBSERVED_VISUAL_UNVERIFIED"
            if mode=="normal" and rep.get("exit_code")==0 and rep["observer_complete"]
            and rep["normal_key_a_down"] and rep["normal_key_a_up"]
            else "AP07_RUNTIME_UNVERIFIED")
        (out/"report.json").write_text(json.dumps(rep,indent=2)+"\n")
    return rep

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom",type=Path,required=True)
    p.add_argument("--lcd-rom",type=Path,required=True)
    p.add_argument("--bin",type=Path,default=ROOT/"build/send-mame/asprodiag")
    p.add_argument("--payload",type=Path,default=ROOT/"private/ap07/payload0/payload0.bin")
    p.add_argument("--hold",required=True,type=lambda v:int(v,16))
    a=p.parse_args()
    os.umask(0o077)
    rom_audit=audit_rom(a.rom)
    if not rom_audit["expected_212"] or rom_audit["reset"]!="C000":p.error("wrong Pro ROM")
    if len(a.lcd_rom.read_bytes())!=4096 or hashlib.sha1(a.lcd_rom.read_bytes()).hexdigest()!=KS0066_F05_SHA1:p.error("wrong LCD ROM")
    exe=a.bin.resolve(strict=True)
    tree=(ROOT/"build/send-mame").resolve()
    if exe!=tree/"asprodiag" or exe.is_symlink():p.error("not independent ASPRO-DIAG binary")
    marker=json.loads((tree/".ap07-cpu-marker.json").read_text())
    binary=json.loads((tree/".aspro-binary.json").read_text())
    if marker.get("feature")!="AP07_POST_SCI_D0P" or marker.get("authentic_sci") is not False:
        p.error("D0 CPU patch provenance mismatch")
    if binary.get("binary_sha256")!=sha(exe) or binary.get("variant")!="ASPRO-DIAG":
        p.error("independent binary SHA mismatch")
    payload=a.payload.read_bytes()
    from ap07_d0_bootstrap_contract import validate_payload
    validate_payload(payload)
    results=[launch(exe,a.rom,a.lcd_rom,payload,a.hold,mode) for mode in ("bootstrap","normal")]
    combined={"increment":"AP07","status":"DYNAMIC_UNVERIFIED","authentic_sci_pass":False,
              "bootstrap":results[0],"normal":results[1]}
    (ROOT/"private/ap07/report.latest.json").write_text(json.dumps(combined,indent=2)+"\n")
    print(json.dumps(combined,indent=2))
    return 0 if (results[0]["cpu_hold_observed"] and results[1]["observer_complete"] and
                 results[0]["post_sci_injection_seen"] and
                 results[1]["normal_key_a_down"] and results[1]["normal_key_a_up"]) else 4

if __name__=="__main__":
    raise SystemExit(main())
