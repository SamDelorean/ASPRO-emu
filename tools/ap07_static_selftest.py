#!/usr/bin/env python3
"""AP-07 static, hardware-specific bootstrap contract checks. No emulators run."""
from __future__ import annotations
import hashlib
from pathlib import Path

from ap07_d0_bootstrap_contract import (
    BOOT_ROM_END, BOOT_ROM_START, BOOT_TRANSFER_IDLE_CHARACTERS,
    BootstrapContractError, CLOCK_HZ, D0_INTERNAL_RAM_END,
    D0_INTERNAL_RAM_START, E_CLOCK_HZ,
    HPRIO_BOOTSTRAP_RBOOT_SMOD_MDA, MAX_DOWNLOAD_BYTES,
    MODA_BOOTSTRAP, MODB_BOOTSTRAP,
    SCI_RXD, SCI_TXD, SCI_SYNCHRONIZATION_BYTE,
    memory_bounds, validate_payload,
)

ROOT = Path(__file__).resolve().parents[1]
driver = (ROOT / "src/mame/skeleton/alphasma.cpp").read_text()
mame_ref = "SamDelorean/mame-as3k@c4e48388ca620472643110db2941ce70aa5f3c07"

checks = []
def check(label: str, condition: bool) -> None:
    assert condition, "AP07 FAIL: " + label
    checks.append(label)
    print("PASS:", label)

def rejects(payload: bytes) -> bool:
    try:
        validate_payload(payload)
    except BootstrapContractError:
        return True
    return False

check("D0P exact MCU at original Pro driver", "// MCU: MC68HC11D0P" in driver)
check("8MHz crystal -> 2MHz E clock", CLOCK_HZ==8_000_000 and E_CLOCK_HZ==2_000_000)
check("bootstrap selects MODB=0 MODA=0 and HPRIO $C0",
      MODB_BOOTSTRAP==0 and MODA_BOOTSTRAP==0 and HPRIO_BOOTSTRAP_RBOOT_SMOD_MDA==0xC0)
check("D0 bootstrap ROM is separate $BF40-$BFFF", (BOOT_ROM_START,BOOT_ROM_END)==(0xBF40,0xBFFF))
check("internal RAM is precisely $0040-$00FF (192 bytes)",
      (D0_INTERNAL_RAM_START,D0_INTERNAL_RAM_END,MAX_DOWNLOAD_BYTES)==(0x40,0xFF,192))
check("special-mode serial RxD/TxD are PD0/PD1",
      (SCI_RXD,SCI_TXD,SCI_SYNCHRONIZATION_BYTE)==("PD0","PD1",0xFF))
check("variable length ends after >=4 character times",
      BOOT_TRANSFER_IDLE_CHARACTERS==4)
check("1-byte payload addresses exactly $0040",memory_bounds(1)==(0x40,0x40))
check("192-byte payload ends exactly at $00FF",memory_bounds(192)==(0x40,0xFF))
check("193-byte payload rejected before any RAM write",rejects(bytes(193)))
check("0-byte special jump to uninitialized RAM refused by DIAG workflow",rejects(b""))
check("manifest hashes the raw bytes without embedding them",
      validate_payload(bytes((0x86,0x5A,0x20,0xFE)))["sha256"]
      == hashlib.sha256(bytes((0x86,0x5A,0x20,0xFE))).hexdigest()
      and validate_payload(b"\x01")["firmware_binary_included"] is False)
check("do not assert a functional bootstrap from static tests",
      all(validate_payload(b"\x01")[key] is False
          for key in ("bootloader_executed","sci_protocol_verified","payload_executed")))
check("default AlphaSmart Pro ROM boot still present",
      'ROM_START( asmapro )' in driver
      and 'ROM_LOAD( "alphasmartpro212.rom"' in driver)
check("ASPRO-DIAG remains independent of AS2K and includes functional PC Send",
      "class aspro_send_state" in driver
      and "ASPRO_PC_HOST_EDGE_WAKE_IRQ" in driver
      and 'send_sink_codepoint(' in driver)
print(f"AP07_D0P_DATASHEET_STATIC_PASS: {len(checks)}/{len(checks)} checks")
print("SOURCE_REFERENCE:",mame_ref)
print("IMPORTANT: no real SCI/boot ROM transfer was performed.")
