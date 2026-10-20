# Handoff — 2026-10-19 / AP-01

**Corrección 2026-10-19, prioritaria:** ASPRO es el **único entorno de trabajo**. AS2K se consulta solamente como **referencia de código**. El árbol y caché de compilación de AS2K no se alteran. Codex con cuenta ChatGPT falla con `gpt-5.5`; para reintento, seleccionar **Predeterminado** o un modelo efectivamente disponible en el cliente antes de enviar el prompt. Prompt corregido: [AP02_CODEX_PROMPT.md](AP02_CODEX_PROMPT.md).

**Directiva máxima actualizada:** primero ASPRO-DIAG independiente. La decisión de ampliar AS2K o mantener ASPRO separado se tomará solamente al finalizar la calificación funcional de DIAG. No modificar AS2K ni producir versión estable por adelantado.

**Idea preservada para fase futura:** [A17 y SRAM 256 KiB](ASPRO_HW_A17_EXPANSION_256K_CONCEPT.md) — decodificador + registro externo, SIN validación eléctrica, NO condiciona ASPRO-DIAG.

**Estado:** paquete estático de ASPRO-DIAG preparado, pendiente de compilación y prueba auténtica.

Hallazgo clave: el MAME existente ya incluye la emulación Pro en el **mismo** driver AS2K `src/mame/skeleton/alphasma.cpp`. ROM privada SHA1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`, RESET `$C000`, SP inicial `$00FF`. LCD KS0066 F05 de 4096 bytes recuperado en Drive, SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`.

**Entregado:** mapa de hardware, procedencia, directiva máxima, auditor de ROM y HEX, scripts de subtarget y runner aislado (ROM principal + ROM de caracteres), sondas acotadas RESET y matriz de teclado, autocontrol estático. Ver `docs/AP01_STATIC_EVIDENCE.md`.

**No hecho:** ninguna llamada Commander, ninguna compilación, ninguna ejecución MAME, ningún PASS funcional, ningún despliegue Vontar, ningún binario público.

**AP-02 / flujo Codex manual:** [prompt integral listo para copiar y pegar](AP02_CODEX_PROMPT.md). Implementar el incremento como una sola entrega, sin invocar Codex automáticamente. La intervención Commander para compilar y ejecutar ASPRO-DIAG continúa sujeta al presupuesto y a la preparación real; sin PASS dinámico hasta obtener evidencias.

**Siguiente paso único:** tras la corrección de entorno, preparar un solo job autorizado T640 que ejecute `tools/rom_audit.py`, `tools/build_diag.sh`, `tools/run_diag.py` contra ROM privada Pro **y KS0066 F05** disponibles en T, almacenando resumen/logs en Drive, sin volver a reconstruir MAME completo ni realizar exploración de infraestructura. Analizar falla real, si ocurre, dentro de la misma intervención autorizada.

**Reglas:** ASPRO-DIAG único emulador de pruebas, max 3 Commander/intervención expresamente aprobada, sin polling, STATIC_FIRST, anti-gate, no inventar prueba dinámica.

## Verificaciones estáticas ejecutadas fuera de T (sin Commander)
- `bash -n tools/build_diag.sh`: PASS. Copia byte por byte comprobada por SHA de blob Git `75136d82d02837452b7b851ac164b8a32872b172`.
- `py_compile tools/rom_audit.py`: PASS; blob `d8e29e105e4aa2bfce4f3fea056f2fc7b9f55b22`.
- `tools/static_selftest.py`: PASS sobre fixtures sintéticos, checksum HEX negativo, invariancia de ROM; blob `ace313b46bd2afa0110879282d6b1426f8dd8db5`.
- `tools/rom_audit.py --rom ... --hex ...`: PASS de identidad ROM v2.1.2 y RESET, HEX 8192 bytes, rango 0–1FFF; archivos privados leídos localmente sin publicarlos.
- `py_compile tools/run_diag.py`: PASS; blob Git verificado `debef0a86e068916cf19f5f8e3ad421139b1b0d7`.
- LCD KS0066 F05: 4096 bytes; SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`, CRC32 `af9e7bd6` verificadas contra la fuente MAME.
- **NO** se ha compilado `asprodiag`; NO se ha ejecutado MAME, ni pruebas de LCD/teclado. Ninguna afirmación de PASS funcional.

## AP-02 Cloud — 2026-10-19 (estado vigente)

Implementación estática integral entregada en `codex/ap02-aspro-diag-20261019`.
Base inspeccionada `7ff52d3813202cbc32d3945b5d3a2310d94a9434`.
**STATIC_PASS / COMPILE_PENDING / DYNAMIC_PENDING**; AP-02 funcional sigue abierto.

Receta y exportación de fuentes fijadas aisladas, job autónomo `tools/ap02_run_once.sh`,
runner con limpieza integral/timeout/límites, manifestación de identidad binaria,
sondas HC11 acotadas y observación de pantalla/tecla usando Lua existente.
La pantalla y la respuesta a teclado no se dan por probadas: las pruebas locales
son seis casos sintéticos AP-02 más el autocontrol AP-01, sintaxis shell/Python y
comprobación de diff, todos PASS. No se compiló ni ejecutó MAME en Cloud; no hay
remotes rclone configurados aquí, faltan árbol propio y dependencias gráficas.
No se transfirió ROM a Cloud ni se ejecutó Commander.

Único siguiente paso: intervención T640 expresamente autorizada con la invocación
agrupada y límites descritos en [AP02_EXECUTION_AND_RESULTS.md](AP02_EXECUTION_AND_RESULTS.md).
AS2K anfitrión quedó intacto en SHA `9cc0bd98aeb21e2ea77de878a8833a1047c88169`.
No hay PR, ASPRO-STABLE ni decisión de integración anticipada.

**SHA de producto AP-02:** `54bb6a96e3afdc45dd9f016b76f08e8f8ef100d0`.
Este añadido es sólo de handoff; el siguiente HEAD lo identifica sin cambiar el
código comprobado. No confundir el SHA del paquete estático con un binario
compilado o una prueba funcional. Destino publicado exclusivamente ASPRO-emu.

## AP-02 fast path — reutilización de MAME-DIAG AS2K en la T (2026-10-19)

La infraestructura canónica de T640 incluye MAME 0.289, `as2kdiag`, rclone `googledrive:`, sudo y compilaciones ya ejecutadas. Las carencias de Codex Cloud no implican carencias de la T. No reabrir esos preflights sin error real.

Se añadió `tools/adopt_engine.py`, que **sólo consulta** `-listxml asmapro` en el ejecutable `as2kdiag` ya existente y exige la ROM Pro exacta por SHA-1. Si la máquina está incluida, realiza copia **independiente** del binario en `ASPRO-emu/build/prebuilt/asprodiag` y registra hashes/procedencia. Nunca ejecuta Pro usando `as2kdiag`, no escribe en AS2K y no declara PASS por copiar un ejecutable. Si `asmapro` falta, `tools/ap02_run_once.sh` cae automáticamente a la compilación ASPRO reducida de AP-02 en un directorio independiente.

No repetir pruebas HC11, LCD ni teclado ya cerradas en AS2K: la única prueba nueva consiste en el firmware y el mapa de plataforma Pro (RESET, teclado, LCD, SRAM). Esta optimización **no ha sido ejecutada ni validada en T**. Toda intervención Commander debe contar con autorización concreta y preservar su máximo de llamadas.

## AP-02 — intento remoto 2026-10-19, sin ejecución

Se solicitó una única intervención dirigida a la T640 canónica mediante Commander, deviceId `dee0b4b6-578a-41a5-88de-73dbeb808983`. **El servidor remoto la rechazó antes de despachar**: `No Desktop Commander device is currently online`; T640, última conexión informada hace 6 h. Por tanto **NINGÚN comando llegó a ejecutarse en T**, no hubo checkout, compilación ni ensayo MAME; ningún resultado funcional. Se contabiliza conservadoramente **una llamada Commander rechazada** dentro de la intervención. No se hicieron ping, sondeo, reconexión, exploración ni nuevos intentos.

Rama ASPRO contiene el fast path `tools/adopt_engine.py` + `ap02_run_once.sh`: primero comprobar `-listxml asmapro` sobre DIAG existente y adoptar una copia independiente; si falla, compilar desde exportación aislada. Se publican **sólo reportes derivados** en el outbox Drive. Este código es nuevo, pendiente de ejecución real y por eso no puede marcarse PASS.

**Para retomar:** cuando se restaure el servicio Remote Desktop Commander de T640, ejecutar **una sola vez** la intervención agrupada preparada, con el dispositivo canónico, sin repetir inventarios ni chequeos cerrados. La máquina desconectada es la única causa observada del bloqueo en este intento; no atribuirlo a SDL, rclone, MAME ni a problemas de acceso Git.

## AP-03 — BASIC EDITOR VISUAL PASS (2026-10-20)

**Estado más reciente, prevalece sobre las clasificaciones anteriores de AP-02:** se descartó bloqueo de RAM, porque las capturas `Testing RAM...` se habían tomado sólo a los 3,0 y 4,8 segundos emulados. En la prueba extendida de ASPRO-DIAG (30 s), a los 8, 16, 24 y 27 s ya está visible el editor vacío; tras pulsar A a los 27,6 s aparece una `a` con cursor desplazado a los 29 s. Diferencia RGB de 31 píxeles, limitada a x0–10, y0–7; resto del LCD sin cambios. **PASS de arranque, LCD y escritura básica (inspección visual)**, no PASS de F1–F8/persistencia ni hardware real. No se recompiló ni modificó AS2K.

**Fuente de verdad del cierre:** [AP03_FUNCTIONAL_EVIDENCE.md](AP03_FUNCTIONAL_EVIDENCE.md), commit de producto `941e41b30be4b758c5d873b10e39fc90cf85d1de`; capturas privadas, trazas y JSON en Drive. El automatismo conservó `functional_pass:false` por diseño: no interpreta contenido LCD. No volver a investigar `Testing RAM...` ni repetir la tecla A sin evidencia contradictoria. Continuar sólo con verificación acotada de navegación de archivos/persistencia si se requiere cierre integral AP-03; la decisión final de integrar o separar ASPRO sigue reservada al usuario.
