#!/usr/bin/env python3
"""Pruebas estáticas internas, no arrancan emulador ni requieren Commander."""
from __future__ import annotations
import pathlib
import tempfile
import zipfile
from rom_audit import audit_rom, audit_hex

def rec(n, addr, kind, payload):
    raw = bytes([n, addr>>8, addr&0xff, kind]) + payload
    return ":" + (raw + bytes([(-sum(raw)) & 0xff])).hex().upper()

def main():
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        rom = bytearray(b"\x01"*0x8000)
        rom[0x4000:0x4003] = b"\x8e\x00\xff"
        rom[-2:] = b"\xc0\x00"
        p = d/"synthetic.rom"
        p.write_bytes(rom)
        a = audit_rom(p)
        assert a["reset"] == "C000"
        assert a["reset_lds_00ff"]
        assert not a["expected_212"]
        assert p.read_bytes() == bytes(rom)
        h = d/"synthetic.hex"
        h.write_text(rec(3, 0, 0, b"\x8e\x00\xff")+"\n"+rec(0,0,1,b"")+"\n",encoding="ascii")
        b = audit_hex(h)
        assert b["unique_bytes"] == 3 and b["address_min"] == "00000000"
        bad = d/"bad.hex"
        bad.write_text(rec(3,0,0,b"\x8e\x00\xff")[:-2]+"00\n"+rec(0,0,1,b"")+"\n")
        try:
            audit_hex(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("HEX checksum corrupto aceptado")
    print("STATIC_SELFTEST_PASS: ROM, RESET, invariancia, Intel HEX y rechazo checksum")

if __name__ == "__main__":
    main()
