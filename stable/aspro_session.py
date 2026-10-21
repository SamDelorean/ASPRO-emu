#!/usr/bin/env python3
"""ASPRO stable application session, isolated from AS2K and diagnostic runs."""
import hashlib
import os
import sys
import zipfile
import subprocess
import tempfile
from pathlib import Path
import gi
gi.require_version("Gtk","3.0")
from gi.repository import Gtk

HOME=Path.home()
CONFIG=Path(os.environ.get("ASPRO_CONFIG_DIR",HOME/".config/aspro"))
DATA=HOME/".local/share/aspro"
RUNTIME=Path(os.environ.get("XDG_RUNTIME_DIR",tempfile.gettempdir()))/("aspro-"+str(os.getuid()))
CORE=Path("/usr/local/libexec/aspro/aspro-bin")
PRO_ROM_SHA1="c3c6a421c9ced92db97431d04b4a3f09a39de716"
LCD_ROM_SHA1="0196e871584ee5d370856e7307c0f9d1466e3e51"

def expected(path,length,sha1):
    if not path.is_file() or path.stat().st_size!=length:
        raise ValueError("Falta ROM original válida: "+str(path))
    digest=hashlib.sha1(path.read_bytes()).hexdigest()
    if digest!=sha1:
        raise ValueError("SHA-1 inesperado para ROM original: "+str(path))
    return path

def source_file(name):
    local=CONFIG/name
    if local.is_file():return local
    private=HOME/".local/share/alphasmart/private/aspro/roms"/name
    if private.is_file():return private
    return local

def ensure_archive(archive,member,source):
    archive.parent.mkdir(parents=True,exist_ok=True)
    if archive.exists():
        with zipfile.ZipFile(archive) as z:
            if z.namelist()==[member] and z.read(member)==source.read_bytes():
                return
    staged=archive.with_suffix(".zip.tmp")
    with zipfile.ZipFile(staged,"w",compression=zipfile.ZIP_STORED) as z:
        z.write(source,arcname=member)
    staged.chmod(0o600)
    os.replace(staged,archive)

def run():
    os.umask(0o077)
    for p in (CONFIG,DATA,RUNTIME,CONFIG/"roms",CONFIG/"cfg",
              DATA/"nvram",DATA/"states",DATA/"output"):
        p.mkdir(parents=True,exist_ok=True)
    os.chmod(RUNTIME,0o700)
    fw=expected(source_file("firmware.bin"),32768,PRO_ROM_SHA1)
    lcd=expected(source_file("ks0066_f05.bin"),4096,LCD_ROM_SHA1)
    ensure_archive(CONFIG/"roms/asmapro.zip","alphasmartpro212.rom",fw)
    ensure_archive(CONFIG/"roms/ks0066.zip","ks0066_f05.bin",lcd)
    if not CORE.is_file():raise RuntimeError("ASPRO stable core missing")
    for name in ("control.queue","events.queue","lcd.bin"):
        (RUNTIME/name).write_bytes(b"")
    env=os.environ.copy()
    env.update({
        "ASPRO_UI_CONTROL_FILE":str(RUNTIME/"control.queue"),
        "ASPRO_UI_EVENT_FILE":str(RUNTIME/"events.queue"),
        "ASPRO_UI_FRAME_FILE":str(RUNTIME/"lcd.bin"),
        "ASPRO_CONFIG_DIR":str(CONFIG),
        "SDL_VIDEODRIVER":"dummy",
    })
    payload=CONFIG/"payload0_pro.bin"
    if payload.is_file() and 1<=payload.stat().st_size<=192 and os.environ.get("ASPRO_BOOT_AT_START")=="1":
        env["ASPRO_BOOTSTRAP_FILE"]=str(payload)
    cmd=[str(CORE),"asmapro","-rompath",str(CONFIG/"roms"),
         "-cfg_directory",str(CONFIG/"cfg"),
         "-nvram_directory",str(DATA/"nvram"),
         "-snapshot_directory",str(DATA/"output"),
         "-state_directory",str(DATA/"states"),
         "-skip_gameinfo","-sound","none","-video","none"]
    logfile=(DATA/"aspro-stable-core.log").open("ab",buffering=0)
    core=subprocess.Popen(cmd,env=env,stdout=logfile,stderr=subprocess.STDOUT)
    try:
        os.environ.update({k:v for k,v in env.items() if k.startswith("ASPRO_")})
        # Import GTK frontend ONLY after its control/event/frame environment exists.
        from aspro_ui import ProApplication
        code=ProApplication().run(sys.argv[:1])
        return code
    finally:
        if core.poll() is None:
            core.terminate()
            try:core.wait(timeout=8)
            except subprocess.TimeoutExpired:
                core.kill();core.wait()
        logfile.close()

if __name__=="__main__":
    try:raise SystemExit(run())
    except (OSError,ValueError,RuntimeError,zipfile.BadZipFile) as error:
        print("ASPRO Stable: "+str(error),file=sys.stderr)
        dialog=Gtk.MessageDialog(message_type=Gtk.MessageType.ERROR,
                                 buttons=Gtk.ButtonsType.OK,
                                 text="ASPRO — error de configuración")
        dialog.format_secondary_text(str(error))
        dialog.run();dialog.destroy()
        raise SystemExit(2)
