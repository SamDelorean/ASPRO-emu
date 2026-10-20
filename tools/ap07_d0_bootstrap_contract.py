#!/usr/bin/env python3
"""AP-07: bounded MC68HC11D0P bootstrap payload contract, not an SCI emulator.

Sources: Motorola/Freescale MC68HC11D3 Technical Data, section 4.1.4 and
Appendix A (D0); Freescale AN1060 rev 1.1, D3 bootstrap variant.
Payload validation does not execute firmware, fabricate SCI echo, or imply
that the bootloader has received the synchronization character.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MCU = "MC68HC11D0P"
CLOCK_HZ = 8_000_000
E_CLOCK_HZ = CLOCK_HZ // 4
D0_INTERNAL_RAM_START = 0x0040
D0_INTERNAL_RAM_END = 0x00FF
MAX_DOWNLOAD_BYTES = D0_INTERNAL_RAM_END - D0_INTERNAL_RAM_START + 1
BOOT_ROM_START = 0xBF40
BOOT_ROM_END = 0xBFFF
SCI_SYNCHRONIZATION_BYTE = 0xFF
HPRIO_BOOTSTRAP_RBOOT_SMOD_MDA = 0xC0
MODB_BOOTSTRAP = 0
MODA_BOOTSTRAP = 0
SCI_RXD = "PD0"
SCI_TXD = "PD1"
BOOT_TRANSFER_IDLE_CHARACTERS = 4

class BootstrapContractError(ValueError):
    """Input violates a strictly bounded AP-07 bootstrap precondition."""


def memory_bounds(size: int) -> tuple[int, int]:
    """One or more downloaded program bytes inside internal D0 RAM only.

    While AN1060 describes a 0-byte special case, AP-07 intentionally
    excludes jumping into uninitialized RAM without a downloaded program.
    This is an emulator safety policy, not a claim that hardware rejects 0.
    """
    if not isinstance(size, int) or isinstance(size, bool):
        raise BootstrapContractError("payload length must be an integer")
    if not 1 <= size <= MAX_DOWNLOAD_BYTES:
        raise BootstrapContractError(
            f"D0 bootstrap accepts 1..{MAX_DOWNLOAD_BYTES} program bytes "
            "for this bounded DIAG workflow"
        )
    return D0_INTERNAL_RAM_START, D0_INTERNAL_RAM_START + size - 1


def validate_payload(payload: bytes) -> dict:
    if not isinstance(payload, bytes):
        raise BootstrapContractError("program must be raw bytes")
    first, last = memory_bounds(len(payload))
    return {
        "variant": "ASPRO-DIAG",
        "increment": "AP-07",
        "device": MCU,
        "mode": "SPECIAL_BOOTSTRAP",
        "boot_mode_pins": {"MODB": MODB_BOOTSTRAP, "MODA": MODA_BOOTSTRAP},
        "boot_hprio_reset_expectation": "0xC0",
        "sci_sync_first_byte": "0xFF",
        "sci_rx_pin": SCI_RXD,
        "sci_tx_pin": SCI_TXD,
        "internal_ram_start": f"0x{first:04X}",
        "internal_ram_last_written": f"0x{last:04X}",
        "destination_after_boot_rom": "0x0040",
        "size": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "termination_idle_character_times": BOOT_TRANSFER_IDLE_CHARACTERS,
        "rom_user_internal_D0_bytes": 0,
        "boot_rom_window": ["0xBF40", "0xBFFF"],
        "process_status": "PAYLOAD_STATIC_CONTRACT_ONLY",
        "bootloader_executed": False,
        "sci_protocol_verified": False,
        "payload_executed": False,
        "firmware_binary_included": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--payload", type=Path, required=True,
                        help="local private HC11 code bytes; must fit $0040-$00FF")
    parser.add_argument("--manifest", type=Path,
                        help="optional local manifest JSON; no payload bytes stored")
    args = parser.parse_args()
    source = args.payload.resolve(strict=True)
    if not source.is_file() or source.is_symlink():
        parser.error("payload must be an existing nonsymlink regular file")
    payload = source.read_bytes()
    try:
        result = validate_payload(payload)
    except BootstrapContractError as err:
        parser.error(str(err))
    output = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.manifest:
        target = args.manifest.absolute()
        if target.exists() or target.is_symlink():
            parser.error("manifest destination already exists; refuse overwrite")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(output, encoding="utf-8")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
