# ASPRO-DIAG-ROM — port de la metodología AS2K (2026-10-21)

**Vertiente independiente en el repositorio ASPRO-emu, NO en AS2K.** Se utilizará la base existente de ASPRO-DIAG `asprodiag` y las fuentes/contratos de AS2K Probe Tools **en solo lectura**. No reescribir CPU M68HC11, motor bootstrap, driver MAME, BDS, monitor ni generadores si su contrato es portable. No crear ASPRO-STABLE ni OS2K-Pro desde esta vertiente.

## Misión
Adaptar en el mínimo número de incrementos coherentes el flujo completo de diagnóstico del AS2K al AlphaSmart Pro:
- entrada por Special Bootstrap D0 y verificación de ejecución independiente de ROM externa;
- monitor HC11 en RAM interna y overlays reutilizables, sin reiniciar entre overlays;
- bus externo y SRAM: discriminación de D0..D7, A0..An, RAM, 4 bancos Pro (128 KiB);
- ROM Pro 2.1.2: prueba **solo lectura**, mapa, firmas/versiones y camino de selección Pro; **sin ZPSD/Chip Z**;
- pruebas críticas, LCD Pro 40x4 en ronda final y arranque normal;
- registros BDS 8 B, orden de confianza, STOP con primera falla útil y códigos finales;
- políticas de preservación y restauración de SRAM, sin simulación eléctrica inventada;
- pruebas **solo ASPRO-DIAG**; hardware real, Commander y Stable quedan fuera sin autorización.

## Fuentes canónicas
- Pro: `SamDelorean/ASPRO-emu@26fe52709ac22e9210e4772e0c09f02e2526ec6b`, `docs/AP07_FUNCTIONAL_PASS_20261020.md`, `docs/AP07_PRO_LCD_PORT_CONTRACT.md`, `docs/ROM_HARDWARE_MAP.md`, `src/mame/skeleton/alphasma.cpp`.
- AS2K: `SamDelorean/AS2K-probe-tools@e3b3a3b41e541cf70c823c2a2c6d135ab48e2616`; `docs/FUNCTIONAL_PROTOCOL.md`, `docs/BDS_PROTOCOL_V0_1.md`, `docs/DIAGNOSTIC_SEQUENCE_POLICY.md`, `docs/I0_2_MONITOR_OVERLAY_RAM_FEASIBILITY.md`, `docs/LAYER2_MINIMUM_RAM_GATE.md` y su `catalogue/probe_catalogue.json`.
- Emulador/procedimiento bootstrap donante: `SamDelorean/AS2K-DictROM-Takeover` y el propio AP-07 Pro, no los binarios de prueba de AS2K sin calificación.
- ROM privada Pro `alphasmartpro212.rom`: 32768 B, SHA-256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`, **nunca incorporar bytes privados a Git**.
- Carpeta Drive `ASPRO_DIAG_PRIVATE/ASPRO_DIAG_ROM`: https://drive.google.com/drive/folders/1Xpq-N-0KsK_0QHIssT7IksWVkz5CxpXO

**Fuente de autoridad y estado actual:** [PORT_MATRIX_AND_REVERSE_AUDIT.md](PORT_MATRIX_AND_REVERSE_AUDIT.md) y [HANDOFF.md](HANDOFF.md). El archivo Excel rector ASPRO-DIAG-ROM se guarda en la carpeta privada, no comparte el rector AS2K.

**Estado:** `PORT_MAPPING_STATIC_IN_PROGRESS`, sin nuevo binario de diagnóstico Pro, sin ROM Pro regrabada y sin pruebas de overlays declaradas PASS.
