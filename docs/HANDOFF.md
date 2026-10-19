# Handoff — 2026-10-19 / AP-01

**Estado:** paquete estático de ASPRO-DIAG preparado, pendiente de compilación y prueba auténtica.

Hallazgo clave: el MAME existente ya incluye la emulación Pro en el **mismo** driver AS2K `src/mame/skeleton/alphasma.cpp`. ROM privada SHA1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`, RESET `$C000`, SP inicial `$00FF`. LCD KS0066 F05 de 4096 bytes recuperado en Drive, SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`.

**Entregado:** mapa de hardware, procedencia, directiva máxima, auditor de ROM y HEX, scripts de subtarget y runner aislado (ROM principal + ROM de caracteres), sondas acotadas RESET y matriz de teclado, autocontrol estático. Ver `docs/AP01_STATIC_EVIDENCE.md`.

**No hecho:** ninguna llamada Commander, ninguna compilación, ninguna ejecución MAME, ningún PASS funcional, ningún despliegue Vontar, ningún binario público.

**Siguiente paso único:** preparar un solo job autorizado T640 que ejecute `tools/rom_audit.py`, `tools/build_diag.sh`, `tools/run_diag.py` contra ROM privada Pro **y KS0066 F05** disponibles en T, almacenando resumen/logs en Drive, sin volver a reconstruir MAME completo ni realizar exploración de infraestructura. Analizar falla real, si ocurre, dentro de la misma intervención autorizada.

**Reglas:** ASPRO-DIAG único emulador de pruebas, max 3 Commander/intervención expresamente aprobada, sin polling, STATIC_FIRST, anti-gate, no inventar prueba dinámica.

## Verificaciones estáticas ejecutadas fuera de T (sin Commander)
- `bash -n tools/build_diag.sh`: PASS. Copia byte por byte comprobada por SHA de blob Git `75136d82d02837452b7b851ac164b8a32872b172`.
- `py_compile tools/rom_audit.py`: PASS; blob `d8e29e105e4aa2bfce4f3fea056f2fc7b9f55b22`.
- `tools/static_selftest.py`: PASS sobre fixtures sintéticos, checksum HEX negativo, invariancia de ROM; blob `ace313b46bd2afa0110879282d6b1426f8dd8db5`.
- `tools/rom_audit.py --rom ... --hex ...`: PASS de identidad ROM v2.1.2 y RESET, HEX 8192 bytes, rango 0–1FFF; archivos privados leídos localmente sin publicarlos.
- `py_compile tools/run_diag.py`: PASS; blob Git verificado `debef0a86e068916cf19f5f8e3ad421139b1b0d7`.
- LCD KS0066 F05: 4096 bytes; SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`, CRC32 `af9e7bd6` verificadas contra la fuente MAME.
- **NO** se ha compilado `asprodiag`; NO se ha ejecutado MAME, ni pruebas de LCD/teclado. Ninguna afirmación de PASS funcional.
