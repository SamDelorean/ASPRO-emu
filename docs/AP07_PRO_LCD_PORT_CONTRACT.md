# AP-07 — verified Pro LCD porting contract (source audit, NOT runtime PASS)

Reference: ASPRO-emu/src/mame/skeleton/alphasma.cpp on
codex/ap02-aspro-diag-20261019 at blob
8e1ebd31348fcb9c65c6aedf533a8d3231c52a81.
Source below documents **current MAME wiring**, not experimentally verified
electrical continuity in the physical AlphaSmart Pro.

## Explicit incompatibilities with original AS2K Payload-0

AS2K writes LCDCFG $2000 and CTRL $4000; these do **not** control Pro LCD
in the current driver. Do not copy AS2K PA6 selector/DictROM logic.
Pro uses the HC11 internal PORTA and PORTD callbacks; selected MAME
memory-mapped keyboard register $8000 is not AS2K's $2000 LCDCFG.
Pro has two KS0066 F05 devices configured with 2x40 size.

### Driver-derived port bit contract

- PORTD write sets `m_port_d`, and LCD data nibble derives from
  `(m_port_d << 2) & 0xF0`. Thus CPU PD5..PD2 drive LCD D7..D4.
- PA7 (bit $80) rising edge pulses controller 0;
  PA5 (bit $20) rising edge pulses controller 1.
- Write to keyboard high-matrix register at $8000 sets `m_matrix[1]`.
  Bit 1 ($02): LCD RS (0 instruction, 1 data).
  Bit 2 ($04): LCD read when 1 / write when 0.
  A write-mode LCD pulse requires $04 clear.
- Trigger order: write $8000 selection; write PORTD nibble; write PORTA
  baseline with PA7/PA5 low; then *rising* PA7 or PA5 edge.
  Keep PA3/PA4 and other board signals unchanged unless justified.
- `port_a_w` also changes SRAM bank according to PA3/PA5.
  PA5 is shared with bank selection, so issuing controller-1 pulses can
  alter bank selection. First minimal visual attempt should pulse PA7
  only (controller 0), then examine visible LCD evidence.
- `alphasmart_mem` maps $0000..$7fff as external rambank,
  $8000..$ffff as ROM, with $8000 read/write keyboard overlap and
  $c000 low matrix write. HC11 internal registers and internal RAM
  require correctly modeled CPU memory arbitration in bootstrap mode.
  **Do not** assume the existing driver map on its own proves true
  boot ROM/internal RAM priority or special mode mapping.

### Consequences

1. Port AS2K's HC11 RAM-only initialization shape and nibble algorithm,
   not its external control addresses.
2. MDA=1 can expose external bus; confirm internal RAM priority for
   $0040..$00ff and effects of $8000 writes in special mode.
3. Preserve the Pro's ordinary ROM boot with bootstrap off.
4. Pro visual Payload-0 must fit within 192-byte download and not
   overwrite its stack or serial reception state.
5. The existing 11-byte RAM probe is a pre-SCI fixture, **not**
   a complete visual Payload-0, and its source must be executed before
   any PASS claim.
6. SCI and D0 boot ROM transition are not implemented by this document.

## Acceptance evidence

In ASPRO-DIAG only, demonstrate authentic SCI sync/echo and byte-by-byte
transfer to RAM, PC=$0040 execution, LCD controller-0 BOOT OK,
then separate ordinary Pro boot regression and AP-06 Send preservation.
Label post-transfer memory injection separately from actual SCI.
DIAG-ROM-Pro and OS2K-Pro remain excluded.
