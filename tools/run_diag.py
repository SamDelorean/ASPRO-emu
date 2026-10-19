#!/usr/bin/env python3
"""Lanza SOLO asprodiag; aislamiento privado, breakpoint RESET, informe verificable."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import pathlib
import subprocess
import sys
import zipfile
from rom_audit import audit_rom, EXPECTED_SHA1

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom", type=pathlib.Path, required=True)
    p.add_argument("--bin", dest="binary", type=pathlib.Path, required=True)
    p.add_argument("--out", type=pathlib.Path, default=pathlib.Path.home()/".local/state/aspro-diag")
    p.add_argument("--seconds", type=int, default=8)
    args = p.parse_args(argv)
    if not 1 <= args.seconds <= 30:
        p.error("--seconds debe estar entre 1 y 30")
    try:
        audit = audit_rom(args.rom)
    except (OSError, ValueError) as exc:
        print(f"BLOCKED: ROM inválida: {exc}", file=sys.stderr)
        return 2
    if audit["sha1"] != EXPECTED_SHA1:
        print("BLOCKED: ROM distinta de AlphaSmart Pro v2.1.2 calificada", file=sys.stderr)
        return 2
    binary = args.binary.resolve()
    if binary.name != "asprodiag" or not binary.is_file():
        print("BLOCKED: solo se permite binario asprodiag existente", file=sys.stderr)
        return 3
    if not binary.stat().st_mode & 0o111:
        print("BLOCKED: asprodiag no ejecutable", file=sys.stderr)
        return 3
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = (args.out / stamp).resolve()
    if out.exists():
        print("BLOCKED: directorio de ejecución duplicado", file=sys.stderr);return 3
    out.mkdir(parents=True)
    rom_dir = out / "roms"
    rom_dir.mkdir()
    zpath = rom_dir / "asmapro.zip"
    # MAME requiere el nombre exacto alphasmartpro212.rom dentro del romset asmapro.
    # Copia temporal privada, no subir ZIP a repositorio ni outbox compartido.
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_STORED) as z:
        z.write(args.rom, arcname="alphasmartpro212.rom")
    for name in ("nvram", "cfg", "state", "input", "snap"):
        (out/name).mkdir()
    debugscript = out / "aspro_reset.cmd"
    # Breakpoint del vector RESET real; acción no cambia comportamiento del firmware.
    debugscript.write_text(
        'bp C000,1,{ logerror "ASPRO_RESET_C000" ; g }\n'
        'g\n', encoding="utf-8"
    )
    cmd = [
        str(binary), "asmapro", "-rompath", str(rom_dir),
        "-nvram_directory", str(out/"nvram"),
        "-cfg_directory", str(out/"cfg"),
        "-state_directory", str(out/"state"),
        "-input_directory", str(out/"input"),
        "-snapshot_directory", str(out/"snap"),
        "-debug", "-debugger", "none", "-debugscript", str(debugscript),
        "-log", "-video", "none", "-sound", "none",
        "-throttle", "0", "-seconds_to_run", str(args.seconds)
    ]
    report = {
        "variant": "ASPRO-DIAG", "system": "asmapro",
        "rom_sha256": audit["sha256"], "bin_sha256": sha(binary),
        "run_dir": str(out), "seconds_requested": args.seconds,
        "status": "EXECUTION_PENDING", "functional_pass": False,
        "note": "exit=0 o breakpoint aislado no prueban LCD/teclado"
    }
    # Aislar pwd: error.log se genera dentro del directorio diagnóstico.
    try:
        with (out/"stdout.log").open("w", encoding="utf-8") as stdout, \
                (out/"stderr.log").open("w", encoding="utf-8") as stderr:
            completed = subprocess.run(cmd, cwd=out, stdout=stdout, stderr=stderr,
                                       timeout=max(45, args.seconds*8), check=False)
            report["exit_code"] = completed.returncode
            report["status"] = "PROCESS_EXIT_0_FUNCTIONAL_UNVERIFIED" if completed.returncode == 0 else "PROCESS_FAILED"
    except subprocess.TimeoutExpired:
        report["status"] = "PROCESS_TIMEOUT";report["exit_code"] = None
    finally:
        # No filtrar archivos propietarios ni contenido de ROM en reportes.
        (out/"report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
        zpath.unlink(missing_ok=True)
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PROCESS_EXIT_0_FUNCTIONAL_UNVERIFIED" else 4

if __name__ == "__main__":
    raise SystemExit(main())
