# Handoff — 2026-10-19 / AP-01

**Estado:** paquete estático de ASPRO-DIAG preparado, pendiente de compilación y prueba auténtica.

Hallazgo clave: el MAME existente ya incluye la emulación Pro en el **mismo** driver AS2K `src/mame/skeleton/alphasma.cpp`. ROM privada SHA1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`, RESET `$C000`, SP inicial `$00FF`.

**Entregado:** mapa de hardware, procedencia, directiva máxima, auditor de ROM y HEX, scripts de subtarget y runner aislado, autocontrol estático.

**No hecho:** ninguna llamada Commander, ninguna compilación, ninguna ejecución MAME, ningún PASS funcional, ningún despliegue Vontar, ningún binario público.

**Siguiente paso único:** preparar un solo job autorizado T640 que ejecute `tools/rom_audit.py`, `tools/build_diag.sh`, `tools/run_diag.py` contra ROM privada disponible en T, almacenando resumen/logs en Drive, sin volver a reconstruir MAME completo ni realizar exploración de infraestructura. Analizar falla real, si ocurre, dentro de la misma intervención autorizada.

**Reglas:** ASPRO-DIAG único emulador de pruebas, max 3 Commander/intervención expresamente aprobada, sin polling, STATIC_FIRST, anti-gate, no inventar prueba dinámica.
