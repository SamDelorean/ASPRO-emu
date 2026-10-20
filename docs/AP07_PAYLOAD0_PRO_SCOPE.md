# AP-07 — Payload-0-Pro, first RAM probe and follow-on LCD proof

Scope fixed: replicate the AS2K special bootstrap *workflow* for the D0P,
not its AS2K-specific LCD/DictROM register map. Do not develop DIAG-ROM or
OS2K-Pro in AP-07. Never edit the donor AS2K or construct ASPRO-STABLE.

## Frozen AS2K donor evidence (READ ONLY)

Repository: SamDelorean/AS2K-DictROM-Takeover.
Files: src/payload0.asm; docs/PAYLOAD0.md;
firmware/g0_payload0/g0_payload0.ino.
Canonical original: 127 bytes; SHA256
54582354a972848c642b2c87893ae2cc693483eae3d161693edf8f10d26f634a.
AS2K visual test: BOOT OK at LCD, PC=$008D, SP=$00C3, after
disposable HC11 RAM injection. This is **not** proof of real SCI in ASPRO.

## Portability boundary

Reuse reset MODA=MODB=0, native HC11 synchronization, echo, variable-length
transfer, HPRIO MDA and RAM execution technique subject to MC68HC11D0P
datasheet. Never transfer AS2K PORTA PA6 bank visibility, LCDCFG $2000,
CTRL $4000, PORTD LCD nibble wiring, or DICTROM assumptions to Pro
without independent Pro driver / hardware evidence.

## First independent binary: RAM probe

Source: tools/ap07_payload0_pro.py, generated payload length **11**.
0040: SEI
0041: LDS #$00FF
0044: LDAA #$A5
0046: STAA $00F0
0049: BRA $0049

Acceptance after actual bootstrap download: at the halt loop PC=$0049,
RAM[$00F0]=$A5, SP=$00FF. This fixture **only** establishes code execution
and must not be confused with an LCD proof. Program bytes occupy $0040..$004A.
$00F0 remains outside this 11-byte download. This RAM probe is a deliberately
bounded precursor to a Pro-specific **visual** Payload-0-Pro, not a new gate
blocking unrelated work.

## One coherent implementation campaign

1. Execute existing 15 static AP-07 checks once; build the 11-byte RAM probe.
2. Implement D0P special reset and SCI RX/TX/echo/idle and RAM transfer in
   independently exported ASPRO-DIAG MAME; the prior direct RAM diagnostic
   loader may provide a *post-SCI* comparison only.
3. Prove 1, 192 accepted; 0 and 193 rejected by the DIAG workflow.
   Synchronization byte $FF does not count as payload.
4. Run RAM probe to witness A5 and actual HC11 PC/SP; implement
   verified Pro-specific LCD control and a <=192-byte Payload-0-Pro
   showing BOOT OK, if the resulting mapping and code size permit it.
   If the LCD mapping or size blocks that display, record this exact
   distinction and retain verified RAM-execution evidence.
5. Regress normal Pro firmware startup and AP-06 PC Send without
   rebuilding earlier proven implementations. Archive logs, hashes,
   runtime observations and result states in private Drive.

Present status: RAM probe source prepared only. No static test, MAME build,
actual SCI, RAM execution or LCD proof has been executed in this increment.
Commander requires a separately authorized intervention (<=3 calls,
T640 -j3, no polling). Report no dynamic PASS until evidence exists.

Future projects DIAG-ROM-Pro and OS2K-Pro are explicitly **OUT OF SCOPE**.
