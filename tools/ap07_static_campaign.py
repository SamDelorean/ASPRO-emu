#!/usr/bin/env python3
"""AP-07: one-shot static assembly and integration contract regression."""
from __future__ import annotations
import hashlib
from pathlib import Path
from ap07_assemble_payload0 import assemble_text, build
from ap07_d0_bootstrap_contract import validate_payload, BootstrapContractError
from ap07_payload0_pro import PAYLOAD as RAM_PROBE

ROOT=Path(__file__).resolve().parents[1]
assembly=ROOT/"src/payload0_pro.asm"
out=ROOT/"private/ap07/payload0"

def check(label, flag):
    if not flag:
        raise AssertionError("AP07 STATIC FAIL: "+label)
    print("PASS:",label)

def main():
    source=assembly.read_text()
    origin, data, syms, listing, end=assemble_text(source)
    built=build(assembly,out)
    check("actual Pro assembly source parsed and assembled",built[1]==data)
    check("entry=0040 and image fits D0 RAM",origin==0x40 and 1<=len(data)<=192 and end==0x40+len(data))
    check("stack clear of loaded image",end<=0xD0 and "LDS #$00E0" in source)
    check("BAUD transport pins PD0/PD1 preserved in DDRD",b"BOOT OK\x00" in data and "LDAA #$3C" in source)
    check("D0 PA7 output explicitly enabled", "BSET PACTL,#$80" in source and "PACTL       EQU $0026" in source)
    check("original AS2K LCD registers absent", "EQU $2000" not in source and "EQU $4000" not in source)
    check("HPRIO permits external LCD IO after transfer","BSET HPRIO,#$20" in source)
    check("source has bounded wait loop",syms["PAYLOAD0_HOLD"]>=0x40 and syms["PAYLOAD0_HOLD"]<end)
    check("payload manifest does not misreport runtime success",not validate_payload(data)["payload_executed"])
    check("RAM probe separately valid",validate_payload(RAM_PROBE)["size"]==11)
    for n in (0,193):
        try:validate_payload(bytes(n))
        except BootstrapContractError:pass
        else:raise AssertionError("invalid length accepted "+str(n))
    check("0/193 rejected by DIAG",True)
    check("1/192 allowed",validate_payload(bytes(1))["size"]==1 and validate_payload(bytes(192))["size"]==192)
    drv=(ROOT/"src/mame/skeleton/alphasma.cpp").read_text()
    check("ROM Pro boot default unchanged",'ROM_LOAD( "alphasmartpro212.rom"' in drv)
    check("PC Send integration still exists","ASPRO_PC_HOST_EDGE_WAKE_IRQ" in drv and "send_sink_codepoint(" in drv)
    check("boot is opt-in with bounded private payload","PORT_START(\"BOOTSTRAP_MODE\")" in drv and "diag_bootstrap_begin" in drv and "diag_bootstrap_rx_bit(rxd)" in drv
          and "file_size > 192" in drv)
    patch=(ROOT/"tools/ap07_patch_d0_cpu.py").read_text()
    check("CPU patch remains confined to ASPRO tree", 'build/send-mame' in patch and "expected_h=" in patch and "expected_c=" in patch)
    check("CPU D0 receiver decodes 8N1 and requires FF/4-char idle",
          "diag_bootstrap_rx_bit(bool rxd)" in patch and "m_diag_sci_idle >= 40" in patch
          and "value != 0xff" in patch and "m_diag_sci_ram[m_diag_sci_count++]" in patch)
    check("SCI RX and echo are checked byte-for-byte by the campaign",
          'sci_rx_exact' in (ROOT/"tools/ap07_campaign.py").read_text()
          and 'sci_echo_exact' in (ROOT/"tools/ap07_campaign.py").read_text())
    print("AP07_ASSEMBLY_STATIC_PASS",len(data),"bytes",hashlib.sha256(data).hexdigest(),"hold",hex(syms["PAYLOAD0_HOLD"]))
    print("DYNAMIC STATUS: NOT EXECUTED; modeled RX/echo uses actual 8N1 bits; silicon boot ROM not executed")

if __name__=="__main__":
    main()
