#!/usr/bin/env python3
"""Reused bounded HC11 assembler for ASPRO Payload-0-Pro, sourced from AS2K."""

from __future__ import annotations
import argparse
import hashlib
import re
import zlib
from pathlib import Path

ONE = {
    "SEI": 0x0F, "TAB": 0x16, "TBA": 0x17, "LSRA": 0x44,
    "ASLA": 0x48, "RTS": 0x39, "DEX": 0x09, "DECA": 0x4A,
    "INX": 0x08,
}

def num(token, symbols):
    token = token.strip()
    if token.startswith("#"):
        token = token[1:].strip()
    if token in symbols:
        return symbols[token]
    if token.startswith("$"):
        return int(token[1:], 16)
    return int(token, 0)

def clean_lines(text):
    out = []
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].strip()
        if line:
            out.append(line)
    return out

def first_pass(text):
    symbols = {}
    for line in clean_lines(text):
        m = re.match(r"(?i)^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+(.+)$", line)
        if m:
            symbols[m.group(1)] = num(m.group(2), symbols)

    pc = None
    origin = None
    body = []

    for line in clean_lines(text):
        if re.match(r"(?i)^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+(.+)$", line):
            continue

        m = re.match(r"(?i)^ORG\s+(.+)$", line)
        if m:
            if pc is not None:
                raise ValueError("multiple ORG directives")
            pc = num(m.group(1), symbols)
            origin = pc
            continue

        if line.endswith(":"):
            if pc is None:
                raise ValueError("label before ORG")
            symbols[line[:-1]] = pc
            continue

        if pc is None:
            raise ValueError("instruction before ORG")

        parts = line.split(None, 1)
        op = parts[0].upper()
        operand = parts[1].strip() if len(parts) > 1 else ""

        if op in ONE:
            size = 1
        elif op == "LDAA":
            size = 2
        elif op in ("ANDA", "BRA", "BNE", "BEQ", "BSR"):
            size = 2
        elif op in ("LDS", "LDX"):
            size = 3
        elif op in ("BSET", "BCLR"):
            size = 3
        elif op == "STAA":
            a = num(operand, symbols)
            size = 2 if a <= 0xff else 3
        elif op == "FCB":
            size = len([x for x in operand.split(",") if x.strip()])
        else:
            raise ValueError("unsupported instruction: " + line)

        body.append((pc, line, size))
        pc += size

    if origin is None:
        raise ValueError("missing ORG")
    return origin, symbols, body, pc

def assemble_text(text):
    origin, symbols, body, end = first_pass(text)
    image = bytearray()
    listing = []

    for pc, line, size in body:
        parts = line.split(None, 1)
        op = parts[0].upper()
        operand = parts[1].strip() if len(parts) > 1 else ""

        if op in ONE:
            out = [ONE[op]]
        elif op == "LDAA":
            if operand.upper() == "0,X":
                out = [0xA6, 0x00]
            else:
                out = [0x86, num(operand, symbols) & 0xff]
        elif op == "ANDA":
            out = [0x84, num(operand, symbols) & 0xff]
        elif op == "LDS":
            v = num(operand, symbols)
            out = [0x8E, v >> 8, v & 0xff]
        elif op == "LDX":
            v = num(operand, symbols)
            out = [0xCE, v >> 8, v & 0xff]
        elif op in ("BSET", "BCLR"):
            a, mask = [x.strip() for x in operand.split(",", 1)]
            out = [
                0x14 if op == "BSET" else 0x15,
                num(a, symbols) & 0xff,
                num(mask, symbols) & 0xff,
            ]
        elif op == "STAA":
            a = num(operand, symbols)
            out = [0x97, a] if a <= 0xff else [0xB7, a >> 8, a & 0xff]
        elif op in ("BRA", "BNE", "BEQ", "BSR"):
            target = num(operand, symbols)
            rel = target - (pc + 2)
            if not -128 <= rel <= 127:
                raise ValueError("%s branch target out of range" % op)
            opc = {"BRA":0x20, "BNE":0x26, "BEQ":0x27, "BSR":0x8D}[op]
            out = [opc, rel & 0xff]
        elif op == "FCB":
            out = [num(x.strip(), symbols) & 0xff for x in operand.split(",")]
        else:
            raise AssertionError(op)

        if len(out) != size:
            raise AssertionError((line, size, out))
        image.extend(out)
        listing.append((pc, bytes(out), line))

    return origin, bytes(image), symbols, listing, end

def hashes(data):
    return {
        "crc32": "%08x" % (zlib.crc32(data) & 0xffffffff),
        "sha1": hashlib.sha1(data).hexdigest(),
        "sha256": hashlib.sha256(data).hexdigest(),
    }

def build(source, out_dir):
    origin, image, symbols, listing, end = assemble_text(source.read_text())

    if origin != 0x0040:
        raise SystemExit("Payload-0 origin must be $0040")
    if end > 0x00E0:
        raise SystemExit("Payload-0-Pro overlaps reserved stack at $00E0")
    if len(image) > 192:
        raise SystemExit("Payload-0 exceeds bootstrap download capacity")
    if symbols.get("PAYLOAD0_ENTRY") != 0x0040:
        raise SystemExit("PAYLOAD0_ENTRY must be $0040")

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "payload0.bin").write_bytes(image)
    (out_dir / "payload0.hex").write_text(image.hex().upper() + "\n")
    (out_dir / "payload0.lst").write_text(
        "\n".join("%04X  %-12s  %s" % (a, b.hex(" ").upper(), s)
                  for a, b, s in listing) + "\n"
    )

    h = hashes(image)
    (out_dir / "manifest.txt").write_text(
        "\n".join([
            "origin=$%04X" % origin,
            "end=$%04X" % end,
            "size=%d" % len(image),
            "hold_pc=$%04X" % symbols["PAYLOAD0_HOLD"],
            "message=$%04X" % symbols["MESSAGE"],
            "crc32=" + h["crc32"],
            "sha1=" + h["sha1"],
            "sha256=" + h["sha256"],
        ]) + "\n"
    )
    return origin, image, symbols, end

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", nargs="?", default="src/payload0_pro.asm")
    ap.add_argument("--out", default="private/ap07/payload0")
    args = ap.parse_args()
    origin, image, symbols, end = build(Path(args.source), Path(args.out))
    print("Payload-0-Pro: origin=$%04X end=$%04X size=%d hold=$%04X" %
          (origin, end, len(image), symbols["PAYLOAD0_HOLD"]))
    print(hashes(image))

if __name__ == "__main__":
    main()
