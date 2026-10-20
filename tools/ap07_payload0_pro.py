#!/usr/bin/env python3
"""AP-07 preliminary RAM execution probe for MC68HC11D0P, not LCD Payload-0.

Independent of AS2K's 127-byte LCD-specific image. This deliberately tests
post-transfer execution before integrating authentic SCI and Pro LCD mappings.
No proprietary firmware; no ROM bytes and no MAME execution.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from ap07_d0_bootstrap_contract import validate_payload

# HC11 machine code at $0040:
# 0040 0F         SEI
# 0041 8E 00 FF   LDS #$00FF
# 0044 86 A5      LDAA #$A5
# 0046 B7 00 F0   STAA $00F0
# 0049 20 FE      BRA $0049
# Test witness $00F0 lies beyond this 11-byte program; SP decreases from $00FF.
PAYLOAD = bytes.fromhex("0F 8E 00 FF 86 A5 B7 00 F0 20 FE")
ENTRY_PC = 0x0040
HOLD_PC = 0x0049
EXPECTED_RAM_ADDRESS = 0x00F0
EXPECTED_RAM_VALUE = 0xA5

def manifest() -> dict:
    info = validate_payload(PAYLOAD)
    info["artifact"] = "AP07_PAYLOAD0_PRO_RAM_PROBE"
    info["expected_pc_hold"] = "0x0049"
    info["expected_sp"] = "0x00FF"
    info["expected_ram_write"] = {"address": "0x00F0", "value": "0xA5"}
    info["lcd_result"] = "NOT_IMPLEMENTED"
    info["authentic_sci_result"] = "NOT_EXECUTED"
    return info

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error("refuse to overwrite output")
    if args.manifest and (args.manifest.exists() or args.manifest.is_symlink()):
        parser.error("refuse to overwrite manifest")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(PAYLOAD)
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(manifest(), indent=2, sort_keys=True) + "\n")

if __name__ == "__main__":
    main()
