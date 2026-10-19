#!/usr/bin/env python3
"""Auditoría de ROM HC11 sin revelar ni exportar bytes propietarios."""
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import sys
import zlib

EXPECTED_SHA1 = "c3c6a421c9ced92db97431d04b4a3f09a39de716"
EXPECTED_SHA256 = "286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e"
VECTOR_START = 0xFFD6

def audit_rom(path: pathlib.Path) -> dict:
    data = path.read_bytes()
    if len(data) != 0x8000:
        raise ValueError(f"ROM debe medir 32768 bytes; recibidos {len(data)}")
    vectors = {f"{a:04X}": f"{int.from_bytes(data[a-0x8000:a-0x8000+2], 'big'):04X}"
               for a in range(VECTOR_START, 0x10000, 2)}
    reset = int.from_bytes(data[-2:], "big")
    off = reset - 0x8000
    opcode = data[off:off+3] if 0 <= off <= len(data)-3 else b""
    result = {
        "bytes": len(data),
        "sha1": hashlib.sha1(data).hexdigest(),
        "sha256": hashlib.sha256(data).hexdigest(),
        "crc32": f"{zlib.crc32(data)&0xffffffff:08x}",
        "expected_212": hashlib.sha1(data).hexdigest() == EXPECTED_SHA1
             and hashlib.sha256(data).hexdigest() == EXPECTED_SHA256,
        "rom_window": "8000-FFFF",
        "vectors": vectors,
        "reset": f"{reset:04X}",
        "reset_lds_00ff": opcode == bytes([0x8E, 0x00, 0xFF]),
        "original_rom_unchanged": True,
    }
    if not (0x8000 <= reset <= 0xFFFF):
        raise ValueError("vector RESET fuera de ventana ROM")
    return result

def audit_hex(path: pathlib.Path) -> dict:
    used = {}
    upper = 0
    lines = 0
    eof = False
    for raw in path.read_text(encoding="ascii").splitlines():
        line = raw.strip()
        if not line:
            continue
        if eof:
            raise ValueError("registros tras EOF")
        if not line.startswith(":"):
            raise ValueError(f"Intel HEX: registro no inicia ':' en línea {lines+1}")
        try:
            r = bytes.fromhex(line[1:])
        except ValueError as exc:
            raise ValueError(f"HEX inválido en línea {lines+1}") from exc
        lines += 1
        if len(r) < 5 or len(r) != 5 + r[0] or sum(r) & 0xff:
            raise ValueError(f"longitud/checksum HEX inválidos en línea {lines}")
        count = r[0]
        address = (r[1] << 8) | r[2]
        kind = r[3]
        payload = r[4:4+count]
        if kind == 0x00:
            for i, b in enumerate(payload):
                addr = upper + address + i
                if addr in used and used[addr] != b:
                    raise ValueError(f"solapamiento contradictorio en {addr:X}")
                used[addr] = b
        elif kind == 0x01:
            if count != 0:
                raise ValueError("EOF con datos")
            eof = True
        elif kind == 0x02:
            if count != 2:
                raise ValueError("registro segmento inválido")
            upper = int.from_bytes(payload, "big") << 4
        elif kind == 0x04:
            if count != 2:
                raise ValueError("registro lineal inválido")
            upper = int.from_bytes(payload, "big") << 16
        elif kind in (0x03, 0x05):
            pass
        else:
            raise ValueError(f"tipo de registro HEX no soportado: {kind}")
    if not used or not eof:
        raise ValueError("HEX vacío o sin EOF")
    return {"file_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "hex_records": lines, "address_min": f"{min(used):08X}",
            "address_max": f"{max(used):08X}", "unique_bytes": len(used),
            "pro_rom_substitute": False}

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom", type=pathlib.Path)
    p.add_argument("--hex", dest="hex_file", type=pathlib.Path)
    p.add_argument("--json", action="store_true")
    p.add_argument("--require-212", action="store_true", help="fail on identity/reset mismatch")
    args = p.parse_args(argv)
    if not args.rom and not args.hex_file:
        p.error("especifique --rom y/o --hex")
    try:
        report = {"rom": audit_rom(args.rom)} if args.rom else {}
        if args.require_212 and (not args.rom or not report["rom"]["expected_212"]
                or report["rom"]["reset"] != "C000" or not report["rom"]["reset_lds_00ff"]):
            raise ValueError("ROM identity/reset is not verified Pro 2.1.2")
        if args.hex_file:
            report["hex"] = audit_hex(args.hex_file)
    except (ValueError, OSError, UnicodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
