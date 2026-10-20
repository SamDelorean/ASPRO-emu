# AP-07 — Payload-0-Pro preliminary static layout audit (2026-10-20)

Source under review: `src/payload0_pro.asm` on `codex/ap02-aspro-diag-20261019`, product commit `ba8064134e0d95f5297b27f05d9abbd0dcee337e`.

A bounded two-pass instruction-size and relative-branch calculation was run locally on a transcription of this source. **This is a layout calculation, not an actual assembler invocation over the checked-out Git blob**, nor MAME execution.

Results from the local calculation:
- ORG=$0040, size=118 bytes, end exclusive=$00B6; within the 192-byte limit and below the stack initial value.
- `PAYLOAD0_HOLD=$0088`, `LCD_BYTE=$008A`, `LCD_NIBBLE=$0097`, `DELAY_LONG=$00A7`, `MESSAGE=$00AE`.
- Relative BRA/BNE/BEQ/BSR target displacements all in [-128,+127].
- Initial SP=$00E0, 42 bytes above payload end-exclusive; actual maximum stack depth **not measured**.
- **Unresolved hazard:** LCD routine accesses the high-matrix register via external $8000 in *special bootstrap* mode. The actual HC11 D0 memory map and MDA behavior must be demonstrated in ASPRO-DIAG. Current MAME driver alone does not certify this path.
- **Unresolved hazard:** LCD controller register strobes and busy delays have not been exercised with this RAM program.

Required next in-product checks:
1. Assemble actual repository source with the existing AS2K assembler (read-only donor, import tool independently) or canonical HC11 assembler; compare encoded output and labels to above calculation.
2. Prove actual CPU internal RAM priority and stack safety after D0 special-mode reset/SCI path is integrated.
3. Distinguish post-SCI direct injection from authentic boot ROM SCI RX/echo/idle.
4. Show BOOT OK using LCD0 and confirm stock Pro firmware startup regression.
5. Store exact binary SHA, listing, log, screenshots and result classification in private Drive.

No Commander call, no MAME build, no SCI or LCD execution was performed here.
Do not claim `STATIC_ASSEMBLY_PASS` or `DYNAMIC_PASS` from this layout audit.
Future DIAG-ROM-Pro and OS2K-Pro are out of scope.
