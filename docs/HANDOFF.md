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

## ESTADO VIGENTE 20-oct-2026 — AP-04 cerrado (F1–F8 + NVRAM visual)

**Prevalece sobre estados estáticos pendientes de AP-01/AP-02.** ASPRO-DIAG funciona usando el motor MAME-DIAG existente, sin compilación nueva. AP-03: arranque Pro 2.1.2, LCD, editor y pulsación A **PASS visual**. AP-04: **F1–F8 PASS visual, escritura de a..h en ocho archivos diferenciados y recuperación idéntica después de reiniciar dos sesiones reales de MAME**. Cada captura write coincide exactamente con su verify por SHA-256. NVRAM de 131072 bytes en `private/ap04`; su hash cambia entre sesiones (no afirmar identidad binaria), pero el contenido mostrado se recupera. No se modificó AS2K.

La primera campaña corta capturó `Opening File N....` y no se promovió a PASS; la segunda usó tiempo de apertura suficiente, capturas previas a cada escritura y dos procesos independientes con NVRAM privada compartida. En el segundo intento `AP04_STATIC_SYNTAX_PASS`, exit 0 en ambos, 8/8 screenshots por fase; un lanzamiento Commander para cada intento (2/3 máximo de la intervención). Ningún sondeo por Commander.

**Evidencia consolidada:** [AP04_FILES_NVRAM_FUNCTIONAL_EVIDENCE.md](AP04_FILES_NVRAM_FUNCTIONAL_EVIDENCE.md). [Informe privado Drive](https://drive.google.com/file/d/1ELvKLvj9O8TQPlb5I0G_efdQwUJbnj8b/view) y [carpeta de 24 capturas](https://drive.google.com/drive/folders/1q52Cx-DFixfmGrPJ9DIRGma4Q79yGHX1).

**Alcance:** PASS de estas rutas emuladas, no certificación de toda la ROM, electrónica o hardware de batería. No repetir F1–F8 ni SRAM sin falla nueva. **Próxima decisión corresponde exclusivamente al usuario:** ASPRO-DIAG separado versus integración con AS2K; no implementar ASPRO-STABLE ni tocar AS2K antes de decidir.

## AP-05 — auditoría de periféricos terminada (2026-10-20)

La revisión del usuario detectó que AP-04 cerró solamente arranque/editor/F1–F8/NVRAM; **no cerró periféricos externos del AlphaSmart Pro**. [Documento canónico AP-05](AP05_PERIPHERAL_HARDWARE_AUDIT.md), con manuales, inventario de 17 hojas y fotos reales, ROM 2.1.2 y driver MAME fijado. **Pro stock: PC teclado AT/PS2 y Mac/IIGS ADB confirmados; ROM contiene mensajes de modo conectado y Send, pero el driver ASPRO-DIAG aún no implementa endpoints host ADB/PS2.** No hay IR/USB/impresora directa documentados para Pro; IR opcional es de AS2K/AS3K. Batería CR2032, fuente DC, NiCad y estado LOW presentes, con modelado lógico limitado. PD0/PD1 son sólo candidatos de conexión (no continuidad medida); no dar por libre ningún pin.

**Próxima etapa**: localizar estáticamente las rutinas de interfaz PC/Mac en la **ROM exacta 2.1.2**, adaptar en ASPRO exclusivamente endpoints emulados y hacer una sola campaña de Send y modo teclado hacia host; reutilizar AS2K como referencia únicamente. No repetir tests AP-02/03/04 ni adelantar decisión ASPRO-STABLE/integración. **Cero llamadas Commander en esta auditoría; sin PASS dinámico de puertos.**

## AP-06 — PC Send físico → TXT, implementación estática (2026-10-20)

**Objetivo solicitado:** mismo comportamiento que AS2K emulador estable: conectarse a PC, pulsar `Send`, reconstruir texto por el **protocolo de teclado real**, guardar `send.txt` UTF‑8. Se recuperó fuente donante `SamDelorean/AS2K-Emulator` release `d66d8614314eb8bad20fdb4dc1e1aa21e148307d`. Cinco rutinas de PC Set‑2/paridad/modificadores/UTF8 se trasplantaron con **comparación textual exacta 5/5** al renombrar clase/log; tablas de scancodes copiadas sin alteración. Adaptación sólo Pro: `aspro_send_state`, puerto `PC_CONNECTED`, PA0/PA2 candidato, PD0/PD1 para datos y clock, tecla `Send=COL.7/0x01`, `send.txt` privado. Sin extraer texto de RAM.

**Productos:** `src/mame/skeleton/alphasma.cpp`, `tools/prepare_send_mame.py`, `tools/build_send_diag.sh`, `tools/ap06_pc_send_observe.lua`, `tools/ap06_send_campaign.py`, `tools/ap06_run_once.sh`. Documento de continuidad [AP06_PC_SEND_TXT.md](AP06_PC_SEND_TXT.md). Compilación debe ejecutarse **exclusivamente** en `ASPRO-emu/build/send-mame`, exportando en solo lectura el MAME ya disponible en T. Binario adoptado AP-04 no contiene este nuevo callback; una compilación propia está justificada. `AS2K` sin alteración.

**Clasificación honesta:** `STATIC_CODE_REUSE_PASS / COMPILE_PENDING / SEND_TXT_DYNAMIC_PENDING`. No afirmar que el Pro comparte señal PA0/PA2, ni que emitió tramas Set 2, hasta la primera prueba real ASPRO-DIAG. La campaña escribe `abc`, conecta PC, usa `Send` Pro y acepta éxito sólo si existe `send.txt` **literalmente idéntico a abc** generado por el decodificador físico. De lo contrario, ajustar únicamente la interfaz Pro con evidencia. No hay permiso Commander nuevo consumido en este incremento. No crear estable ni modificar AS2K.

## AP-06 — contrato de sesión PC y ejecución T640 (2026-10-20)

**Regla del usuario, prioritaria:** `PC CONNECT` abre exactamente una captura; cero o múltiples `Send` incorporan bytes exclusivamente a esa captura; `PC DISCONNECT` cierra y finaliza el TXT. No abrir la captura al recibir la primera trama y no finalizar por cada Send. En `src/mame/skeleton/alphasma.cpp`, `aspro_send_state::sync_pc_session` gestiona las transiciones de `PC_CONNECTED`, invocado desde accesos PA/PD, y delimita `send_sink_begin/end`. El cierre de `machine_stop` es sólo protección ante salida abrupta. Prueba dirigida: `abc` escrito en Pro → conexión PC → Send dos veces → desconexión → **único `send.txt` con `abcabc`**; requiere marcadores físicos y de sesión antes de declarar PASS.

**Intervención Commander autorizada (presupuesto 3/3 usado):** primera llamada lanzó PID 18444, sintaxis PASS y terminó con `exit=3`, por exportación de MAME con `AP06_PREP_BLOCKED: unsupported archive member`; ni compilación ni ROM ejecutada. Segunda llamada leyó sólo el build.log y confirmó ese motivo. Se corrigió `tools/prepare_send_mame.py` para aceptar enlaces internos del archivo Git, rechazando destinos fuera del árbol ASPRO. Tercera llamada lanzó PID 18788 con recuperación del proyecto, preservación de la extracción incompleta antigua mediante renombrado (no borrado) y nueva ejecución agrupada; **PID en segundo plano, resultado todavía pendiente de Drive**. No atribuir ningún fallo de comunicación al Pro hasta recibir el log de compilación/ejecución. Los logs de launcher se publican en `googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox/ASPRO_AP06_send_session_{,repair_}20261020.launch.log`, y los reportes `ASPRO_AP06_send-*.report.json`/TXT privado sólo cuando el trabajo alcance esas etapas. No gastar más Commander sin autorización nueva. AS2K permanece sólo referencia, sin escritura.

## AP-06 — continuación incremental (20-oct-2026, sesión más reciente)

El error de compilación previo está localizado en `aspro_send_state::machine_stop() override`: MAME 0.289 `driver_device` no ofrece `machine_stop` virtual. Corregido eliminando declaración y función (mantener `sync_pc_session` como único delimitador de captura). Implementado `prepare_send_mame.py --refresh-driver` que sólo actualiza el driver dentro de `ASPRO-emu/build/send-mame` tras verificar que coincide con su SHA anterior, **preservando todos los objetos compilados y dejando AS2K intacto**. Corregido además argumento CLI `--refresh-driver` sin `--reference`.

**Ejecuciones/errores reales:**
- Primera intervención T640 PID `26283`: sólo sintaxis, `exit=2` por guardia `--reference is required to prepare`; corregido en `67109237a8d8c09f3528bc40fd400fb4a21160f6`.
- Segunda PID `26474`: validación sintáctica y actualización aislada del driver **PASS**; la compilación MAME avanzó, pero GCC 15 sufrió `internal compiler error: Segmentation fault` al compilar `src/frontend/mame/luaengine.o` (`/usr/include/c++/15/tuple:93`), no un error confirmado del Pro. Registro en Drive `ASPRO_AP06_incremental_fix_20261020.launch.log`.
- Tercera llamada PID `27235`: relanzado el **mismo** make incremental ASPRO con **JOBS=1** para reducir presión de memoria; proceso todavía en segundo plano al registrar este estado. Entregará `ASPRO_AP06_single_job_20261020.launch.log` al outbox Drive cuando termine; si el binario compila, `ap06_run_once.sh` ejecutará directamente dos Send de `abc` en **una** conexión, esperando **un** `send.txt` con `abcabc`. **No adjudicar PASS ni FAIL del protocolo hasta disponer de `ASPRO_AP06_send-*.report.json` y de evidencia textual auténtica.**

**Presupuesto actual Commander: 3/3 llamadas consumidas para esta continuación.** No realizar otras llamadas Commander sin autorización posterior. Documentos y código sólo en ASPRO; AS2K sin modificaciones. No tocar núcleo HC11/LCD/NVRAM ni repetir AP-03/AP-04.

## AP-06 — 20-oct-2026: directriz T640 -j3 y continuación protegida

**Indicación nueva y autorizada del usuario:** la T640 utiliza **`make -j3` normalmente**. Los defaults de `tools/build_send_diag.sh` y `tools/ap06_run_once.sh` ahora son `JOBS=3`; no volver a imponer `-j1`/-j2 por costumbre. Se conserva opción de jobs explícito sólo ante un problema real y justificado. Últimos commits de scripts `fb0fb3d95fba70bfbcc25b2b321f4bef371da195` y `8a92aedabec452b86e732fc97b35926ad38d0384`.

**Estado real comprobado T640:** PID `27235` del lanzamiento incremental `-j1` seguía activo, con log iniciado y todavía sin `AP06_ONE_JOB_EXIT=` ni reportes `private/ap06/*/report.json`. No disparar otra compilación concurrente. Con una única llamada Commander adicional, PID `28028`, se inició un trabajo local autónomo que aguarda la terminación de PID `27235` (sin polling de Commander); primero revisa el log terminal y un posible `report.latest.json`: si existe informe o éxito, **NO recompila ni repite pruebas**; si `-j1` terminó sin informe y en error, hace `git fetch/ff-only` de ASPRO y continúa **make -j3** sobre los objetos existentes, seguido de la campaña `abcabc`. Bloquea cualquier estado anterior ambiguo. Escribe un único log final en `googledrive:AS2K_TEMP/COMMANDER_PIPELINE/outbox/ASPRO_AP06_j3_continuation_20261020.launch.log`.

**No hay PASS funcional todavía.** No se modificó AS2K y no se repiten AP-02/03/04. No iniciar otro trabajo mientras estos PID estén activos. Leer Drive para recuperar el resultado cuando termine, sin gastar llamadas Commander en sondeo.

## AP-06 — 20-oct-2026: último resultado real; discriminación de PORT_TOGGLE

**Contratación vigente de usuario:** conectar PC abre exactamente una captura; uno o más Send acumulan en el mismo TXT; desconectar PC debe cerrar la captura. AS2K read-only, ASPRO-DIAG exclusivo. T640 `-j3` canónico.

- Primera ejecución AP-06 de dos Send completada **sin compilar nuevamente**: [send-06m53x5f](https://drive.google.com/file/d/1Kx5pDDaAm8YITgTIpgkO29gJ0TM3lX4p/view), binario `19a4a0a433caefdc00fbb7521e1bd03eaa77e05d33b81d1b5d9949bb8b198834`, `exit 0`, **TXT literal `abcabc` 6/6 bytes, SHA256 `bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c`**. Log `error.log` creció a 9,836,515 bytes y ya no superó `RLIMIT_FSIZE` ampliado a 16 MiB. **No PASS de sesión completa**: `PC_DETACHED` de Lua pero `session_end_seen=false`, `session_close_count=0`.
- Segunda ejecución con `PORT_CHANGED_MEMBER` específico Pro: [send-atxmons8](https://drive.google.com/file/d/1yzujO4DOhxqB05CAJpSIx74ki3qR3niP/view), de nuevo 6 bytes correctos, sin cierre. El callback de cambio no se disparó en la inyección Lua o no apreció estado LOW; no atribuir fallo al decodificador.
- Tercera ejecución con temporizador 10ms de conexión, callback y `attached:set_value(0)`: [send-xh7rj267](https://drive.google.com/file/d/1h9jwgG582P-x4BdBjwTmnCWE4u7G6iN2/view), binario `acc86a7e1de29ec23fdea2794cc38f89f1d9b97f25b90b59b0f4d8e0fa1abe8a`; `exit 0`, `abcabc` verificado, **pero el marcador `ASPRO_AP06_PC_PORT_READBACK_1` después de solicitar desconexión confirmó que MAME continuaba leyendo PC_CONNECTED=1**. El control `PORT_TOGGLE` seguía enclavado. Ni callback ni temporizador podían cerrar si el puerto seguía HIGH. [Observaciones](https://drive.google.com/file/d/1MqZ-FHgD9XidY8G9Y4dXUAXjbJsILrnW/view).
- **Corrección estática siguiente, SIN ejecución real aún:** commit `d5c68bd7a4b1fca74d236d883ddf481de60dfdaa`, elimina `PORT_TOGGLE` y `KEYCODE_PAUSE` de `PC_CONNECTED`, haciendo el puerto un **estado externo HIGH/LOW explícito** controlable desde Lua/futura interfaz. Conserva el callback y el temporizador de 10ms; no altera la decodificación física ni el TXT. En MAME, Pause ya **no es un interruptor virtual** en esta variante DIAG, deberá implementarse una acción de conexión/desconexión explícita en un frontend cuando exista.
- **Estado conservador:** `SEND_DATA_ABCABC_DYNAMIC_PASS` por pruebas auténticas; `PC_DISCONNECT_CLOSE_PENDING_RETEST`, **`FULL_SEND_SESSION_PASS` NO declarado**. Sólo resta ejecutar ASPRO-DIAG desde el nuevo driver compilado incrementalmente `-j3` y verificar `PC_PORT_READBACK_0`, `session_end_seen=true`, `session_close_count=1`, `TXT abcabc` y `exit_code=0`. No repetir AP-02, AP-03, AP-04. Los 3/3 Commander consumidos en esta intervención; **no gastar más sin autorización nueva**.

## AP-06 — nuevo hallazgo: PC cambia sólo después de pulsar tecla también en AS2K

El usuario aporta un defecto reproductible del AS2K estable: al escoger Conectar/Desconectar PC por menú o combinación de teclas, la transición de modo firmware no ocurre hasta otra pulsación. Lectura estática del driver donante AS2K revela ausencia de `MC68HC11_IRQ_LINE` en la rama `ui_process_command(PC ON/OFF)`, mientras las rutas KEY sí generan IRQ. Hipótesis: falta aviso/wakeup al firmware; **no equivale** a fallo propio Pro de `PORT_TOGGLE` enclavado. Se introdujo sólo en ASPRO el aviso `MC68HC11_IRQ_LINE ASSERT_LINE` por borde real de host en `sync_pc_session` (commit `b638d5f26b285e61a3e38c9c8aa53f9917388feb`), sin fabricar tecla. **STATIC_ONLY / DYNAMIC_PENDING**; comprobar PC ON/OFF sin pulsar teclas, cierre y retorno editor, sin falso PASS. [Detalles AP06](AP06_PC_SEND_TXT.md). **NO MODIFICAR AS2K sin autorización específica**, pero conservar la incidencia en su seguimiento al futuro. 

## ESTADO MÁS RECIENTE — AP-06 SEND PC→TXT CERRADO (2026-10-20)

**Reemplaza los anteriores `PENDING` de AP-06:** `SEND_TXT_DYNAMIC_PASS` y `PC_ATTACH_DETACH_AND_EDITOR_RETURN_VISUAL_PASS` en ASPRO-DIAG, **no** en AS2K. La corrida `ASPRO_AP06_send-aw15n_0s` compiló el ajuste C++ incremental con `-j3`, binario SHA256 `ad6646b38c0c6353622d992e0263828c806161ec234b11d31a82a7ba4e7ed8ea`, compilación y test `exit=0`. Tras escribir `abc`, conectar PC, dos Send y desconectar, produjo un solo `send.txt` de 6 bytes `abcabc` SHA256 `bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c`. Lecturas `PC_CONNECTED: 1→0`, `session_open_count=1`, `session_close_count=1`, marcas de inicio y cierre, `functional_pass=true`. LCD corroborado: editor `abc` → mensaje firmware `Attached to PC` → editor `abc` **sin pulsación adicional**. [Informe](https://drive.google.com/file/d/1Z6DWa_bKTZ3pqF3UeozzTRDsobwJ9VCa/view), [TXT real](https://drive.google.com/file/d/1avEsthOVI9ByCmvWzM4fO7FKsLs-9prL/view), [launcher](https://drive.google.com/file/d/1RUOdSYQdsMCl4RxdAV40P2gQ22cz7iAm/view), [documentación integral AP06](AP06_PC_SEND_TXT.md).

**Continuidad:** NO reabrir ni recompilar AP06 innecesariamente, ni alterar AS2K para atribuirle este PASS. El defecto de AS2K estable, señalado por el usuario —menú/atajo PC ON/OFF requieren teclear para que el firmware cambie—, está confirmado como **ausencia de IRQ en sus comandos UI** en la revisión estática, pero **sigue pendiente de corrección y prueba en AS2K**. Mantener AS2K lectura solamente hasta autorización expresa para su propio flujo. El usuario decide la estrategia de integración; sin ASPRO-STABLE creado. Intervención AP06 final usó sólo **1 llamada Commander** (PID 37195); evidencias recuperadas por Drive.

## AP-07 — 20-oct-2026: bootstrap del MC68HC11D0P, fuentes primarias y contrato

**Nueva directriz expresa del usuario:** continuar el Pro tras AP-06; obtener su capacidad bootstrap **del datasheet del procesador de esa variante**, no copiar hipótesis AS2K. Se recuperaron los planes ASPRO, inspeccionaron el driver ASPRO Pro y el parche CPU de bootstrap D0 de AS2K **sólo lectura**, y verificaron los documentos primarios Motorola/Freescale/NXP: [Technical Data MC68HC11D3](https://www.nxp.com/docs/en/data-sheet/MC68HC11D3.pdf) (4.1.4, tabla 4-2), [D0 apéndice A](https://www.nxp.com/docs/en/data-sheet/MC68HC711D3.pdf), [DIP40/paquete D0 y pines](https://static.datasheets.com/doc/25302592-motorola-mc68hc11d0cfn3r2-ds.pdf), [AN1060 rev1.1](https://www.nxp.jp/docs/en/application-note/AN1060.pdf) (familia D3).

**Contrato real:** Pro `MC68HC11D0P` DIP40 XTAL 8MHz y E 2MHz; señales bootstrap RESET pin13, PD0/RxD pin15, PD1/TxD pin16, MODB/VSTBY pin36, MODA/LIR pin37. Reset `MODB=0/MODA=0`, HPRIO `RBOOT=1 SMOD=1 MDA=0`, boot ROM interna especial 192B `$BF40–$BFFF`, recepción SCI encabezada por `$FF`, 0–192 bytes en RAM `$0040–$00FF`, eco, final por 192 bytes o idle ≥4 caracteres, PC de ejecución `$0040`. **El D0 no tiene ROM de usuario interna**; difiere del D3, aunque comparte boot ROM; no usar el salto a ROM interna D3 ante `$00`, no copiar ZPSD o DictROM de AS2K. Política de payload activo DIAG: 1–192 bytes; 0 bytes es caso reconocido por fabricante pero inseguro para ejecutar si RAM no está precargada.

**Brecha de MAME encontrada en código exacto:** `SamDelorean/mame-as3k@c4e48388ca620472643110db2941ce70aa5f3c07` D0 tiene `SCDR` `nopw` y receptor SCI no funcional. El parche `scripts/patch-mc68hc11-bootstrap.py` del AS2K implementa **únicamente un estado diagnóstico posttransferencia**: HPRIO y cargar RAM/PC directamente; se puede reutilizar bajo licencia BSD-3 para esa parte del D0, **NO declarar SCI real ni éxito de boot ROM con sólo llamar `diag_bootstrap_load`**.

**Artefactos creados realmente en GitHub ASPRO, sin llamadas Commander, sin alterar AS2K:** [contrato completo](AP07_MC68HC11D0P_BOOTSTRAP.md), [validador de payload privado](../tools/ap07_d0_bootstrap_contract.py) (`$0040–$00FF`, 1–192, SHA sin bytes), [15 pruebas estáticas preparadas](../tools/ap07_static_selftest.py), y actualización de [plan maestro](MASTER_PLAN.md). **Estado legítimo `AP07_DATASHEET_CONTRACT_READY / VALIDATOR_SOURCE_IMPLEMENTED / STATIC_TESTS_NOT_EXECUTED / CPU_SCI_INTEGRATION_PENDING / DYNAMIC_PENDING`**. No se ha cambiado el driver de Pro ni compilado/probado bootstrap. **AP-06 SEND TXT PASS previo sigue cerrado**, no repetir AP-02 a AP-06.

**Siguiente avance sin microgates:** adaptar CPU D0 acotadamente en la COPIA ASPRO y diseñar el receptor/eco SCI de bootstrap + selección opt-in por RESET en driver Pro (default firmware Pro intacto), usando fuentes fijadas, para una sola campaña dirigida ASPRO-DIAG con payload sintético, límites 1/192/193, PC y RAM verificables y regresión de arranque ordinario; `-j3` T640. Comandar sólo bajo autorización de intervención, sin polling; los informes irán a Drive. No cambiar destino final integración/ASPRO-STABLE sin decisión del usuario.


## AP-07 — Integración de bootstrap equivalente al método AS2K (20-oct-2026)

**Directriz del usuario (no fraccionar):** implementar el mecanismo probado del
AS2K con las restricciones propias del MC68HC11D0P, y probar Payload-0
específico. DIAG-ROM-Pro y OS2K-Pro son desarrollos futuros expresamente
fuera de AP-07. No crear stable ni modificar AS2K.

**Producto fuente real en ASPRO:**
- `src/payload0_pro.asm`: candidato visual `BOOT OK`, usa PA7/PACTL,
  registros de Pro y RAM desde $0040; no copia MMIO LCD AS2K.
- `tools/ap07_assemble_payload0.py`: ensamblador reutilizado del proyecto
  Payload-0 donante, adaptado a límites RAM/pila Pro.
- `tools/ap07_patch_d0_cpu.py`: adaptación acotada del parche CPU
  D0 de AS2K (HPRIO, MDA, ejecución RAM post-transferencia).
  Verifica blobs pinneados y **sólo parchea** ASPRO/build/send-mame,
  preservando originales para reversión.
- Driver `alphasma.cpp`: `BOOTSTRAP_MODE` opt-in; modo normal por
  defecto; carga privada `payload0_pro.bin` 1..192 bytes desde el
  directorio snapshot y llama `diag_bootstrap_load` sólo en modo especial.
- `build_send_diag.sh`: aplica el parche CPU a la copia independiente
  antes del make incremental `-j3`.
- `ap07_static_campaign.py`, `ap07_observe.lua`, `ap07_campaign.py`,
  `ap07_run_once.sh`: preparación, regresión con ROM normal y
  prueba dirigida de RAM/LCD en un único job, con resultados privados Drive.

**Validación efectivamente efectuada fuera de T:** verificación independiente
del ensamblado fuente y 12 comprobaciones de estructura y conexión:
121 bytes, $0040..$00B8, hold PC=$008B, mensaje=$00B1,
SHA256=`25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`.
No se han ejecutado `ap07_static_campaign.py`, `make` ni MAME
en T; tampoco se ha ejecutado el binario. Commander utilizado: 0 llamadas.

**Clasificación estricta:** `AP07_STATIC_SOURCE_INTEGRATED /
BUILD_PENDING / POST_SCI_DIAG_DYNAMIC_PENDING /
AUTHENTIC_SCI_NOT_IMPLEMENTED / LCD_VISUAL_PENDING`.
Este incremento copia deliberadamente la **semántica AS2K de carga
post-SCI**, NO reproduce todavía el bootstrap ROM real, la sincronización
eléctrica ni eco SCI; no adjudicar `AUTHENTIC_SCI_PASS`.
Una prueba RAM/post-transferencia no cierra todavía el contrato SCI original.
La campaña está preparada, pero la intervención remota exige
autorización explícita (máximo 3 llamadas, sin polling).
Conservar toda evidencia en Drive y sin publicar ROMs privadas.


## AP-07 — incremento de robustecimiento y aceptación instrumentada (20-oct-2026)

**Se mantiene exactamente el alcance autorizado:** bootstrap diagnóstico de AS2K
adaptado al D0P y Payload-0-Pro. DIAG-ROM-Pro/OS2K-Pro son posteriores.
Sin Commander ni pruebas MAME en esta intervención.

Correcciones publicadas:
- `alphasma.cpp`: observación pasiva de los flancos PA7 de LCD0 en
  bootstrap optativo. Captura el nibble PD[5:2], reconstruye bytes
  de comando/dato según el RS del Pro, y registra `ASPRO_AP07_LCD0_BYTE`.
  No modifica la señal que llega al LCD y fuera de bootstrap preserva
  el callback original `alphasmart_state::port_a_w`.
- `ap07_campaign.py`: exige evidencia simultánea PC=$008B
  en el bucle y secuencia de comandos LCD0 28,01,06,0C seguida de
  `BOOT OK` obtenida *de flancos de bus*, además de screenshot.
  Esta prueba comprueba tráfico del bus, **no sustituye inspección
  visual de la imagen del LCD**.
- Regresión de arranque ROM Pro: se toman instantáneas antes/después de
  inyectar `A` en el editor, se registran pulsaciones y se compara
  SHA-256. Cambio de imagen es correlación, no certificación óptica.
- `ap07_patch_d0_cpu.py`: en nuevas aplicaciones fija hashes de
  los dos CPU parcheados y exige su identidad en posteriores compilaciones
  incrementales. Mantiene copia de los originales en ASPRO.
- `ap07_run_once.sh`: una única campaña con `-j3`; EXIT trap
  publica logs y estado incluso si falla compilación/ensamblado,
  y destruye únicamente staging temporal de ROM privada.
  No gasta Commander en sondeo.

**Clasificación tras revisión de código:** `AP07_STATIC_SOURCE_READY /
CPU_PATCH_NOT_COMPILED / DIAG_POST_SCI_RUNTIME_PENDING /
LCD0_BUS_OBSERVATION_PENDING / VISUAL_PENDING / SCI_AUTHENTIC_NOT_IMPLEMENTED`.
Este incremento NO confirma un PASS de MAME, SCI ni LCD.
La intervención remota continúa requiriendo autorización específica.


## AP-07 — continuación integral sin Commander (20-oct-2026)

- Corregido `tools/ap07_campaign.py` para que el estado general distinga
  `POST_SCI_DIAG_LCD_BUS_PASS_VISUAL_REVIEW_PENDING` de
  `DYNAMIC_UNVERIFIED`; ambos conservan
  `authentic_sci_pass=false` y `visual_review_pass=false` hasta
  evidencia válida. No confundir salida del proceso con aceptación de
  transporte SCI ni revisión visual.
- Preparado `tools/ap07_dcjob_integral.job.sh`: *único* job compatible
  con `dcjob launch` y `DCJOB_RESULT_DIR`, sin exploración ni polling,
  con verificación de repo/branch limpio y actualización sólo fast-forward
  del checkout ASPRO. Conserva evidencias de fallos en el directorio
  de resultados del launcher. No añade jobs a inbox automáticamente.
  `ASPRO_ROOT` y `ASPRO_MAME_REFERENCE` son configurables; las rutas
  por defecto deben quedar verificadas antes de un despacho autorizado.
- Comprobación estática independiente sobre los blobs exactos de
  `SamDelorean/mame-as3k@c4e48388...`: 13/13 verificaciones
  satisfactorias (9 anclajes CPU únicos, 2 identidades Git,
  2 restricciones de parche). Esto NO sustituye Python static campaign,
  ni compilación, ni prueba MAME.
- Cola compartida `COMMANDER_PIPELINE/inbox` observada vacía al revisar
  esta continuidad; se deja vacía. El usuario dijo «Siguiente»,
  que continúa el incremento pero no equivale a autorización Commander
  según las reglas universales recuperadas. **0 llamadas Commander.**
- Estado: `AP07_SOURCE_READY / DCJOB_WRAPPER_PREPARED /
  CPU_COMPILE_PENDING / POST_SCI_RUNTIME_PENDING /
  AUTHENTIC_SCI_NOT_IMPLEMENTED / VISUAL_PENDING`.


## AP-07 — ejecución integral y fallo de compilación resuelto en fuentes (20-oct-2026)

**Evidencia auténtica de T640** (únicamente ASPRO-DIAG, 3 llamadas
Commander consumidas, no más dentro de la misma intervención):
1. `000_aspro_ap07_sci_integral_20261020`: FAIL/2, 34 s;
   `ap07_patch_d0_cpu.py` rechazó sin identificar el bootstrap ya
   incorporado en la copia MAME de AS2K.
2. `000_aspro_ap07_sci_REUSE_20261020`: FAIL/1, 22 s;
   el reconocimiento comparaba cadenas internas ajenas a la ABI.
3. `000_aspro_ap07_sci_D0_REUSE_FIX2_20261020`: FAIL/2, 35 s.
   **Alcanzó compilación GCC 15.2** del driver ASPRO y del CPU MC68HC11;
   los cinco errores GCC fueron accesos desde
   `mc68hc11d0_device::diag_bootstrap_begin()` a miembros privados de
   `mc68hc11_cpu_device`:
   `m_irq_state`, `m_irq_asserted`, `m_wait_state`,
   `m_stop_state` y `m_ccr`.
   Drive: `COMMANDER_PIPELINE/outbox/ASPRO_AP07_build.log` e informe
   `000_aspro_ap07_sci_D0_REUSE_FIX2_20261020_20261021T040007Z.summary.txt`.

**Estática realmente ejecutada en T:** datasheet 15/15 PASS;
ensamblado de Payload-0-Pro 18/18 PASS, **121 bytes**,
`SHA256=25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`,
origen `$0040`, fin exclusivo `$00B9`, hold `$008B`.
No declarar LCD, RX serial o MAME funcionalmente aprobados.

**Corrección de código publicada después del tercer intento**:
- `tools/ap07_patch_d0_cpu.py`: espera SCI movida a
  `mc68hc11_cpu_device::diagnostic_bootstrap_wait_for_serial()`
  (clase base, acceso legítimo a sus campos privados). D0 llama a este
  método. Incluye migración verificable desde copias anteriores
  de `.ap07-cpu-original` validada contra `source_blobs` de
  `.ap07-cpu-marker.json`, de modo que las siguientes compilaciones
  no reutilicen el parche SCI anterior fallido.
- El camino reutiliza el bootstrap y loader existentes del MAME
  exportado por AP06 (`source_head=a4b99b1a700a1d70b93a798fe7833e4cae28c137`).
  No clona otro árbol ni reescribe el MAME o AS2K donante.
- **Código corregido NO recompilado aún** (tres llamadas Commander
  agotadas). `AP07_STATIC_PASS / CXX_PREVIOUS_PRIVATE_ACCESS_FAIL /
  SOURCE_FIX_COMMITTED / DYNAMIC_PENDING / SILICON_BOOT_ROM_UNVERIFIED`.

El flujo es un único job `ap07_run_once.sh`, sin gates de
preproducción, sin pruebas en ASPRO-STABLE, sin DIAG-ROM-Pro/OS2K-Pro.


## AP-07 — último incremento de código (2026-10-20, posterior a FAIL GCC)

El usuario exige que el bootstrap se haga funcionar y que se reutilice AS2K sin pasos fragmentados.

**Productos en rama `codex/ap02-aspro-diag-20261019`:**
- `tools/ap07_patch_d0_cpu.py`: conserva el cargador D0/HPRIO de AS2K,
  mueve el acceso a campos privados a método de clase base
  `diagnostic_bootstrap_wait_for_serial` y aporta receptor 8N1 con
  sincronización FF, longitud 1..192, idle >=40 bits y **emisor
  TXD por bits start/8 datos/stop** con eco individual por carácter.
  La actualización de la copia MAME ya marcada se realiza a partir
  de originales hash-verificados en `.ap07-cpu-original`.
- `src/mame/skeleton/alphasma.cpp`: host de prueba emite un byte RX
  UART (10 bits), espera y decodifica de vuelta 10 bits TXD de eco,
  verifica start/datos/stop, repite byte por byte y finalmente deja
  RX inactivo antes del salto a RAM. No ejecuta directamente
  `diag_bootstrap_load` desde el driver.
- `tools/ap07_campaign.py`: corregidos escapes reales de expresiones
  regulares de índice RX/eco (`\\d` antes erróneo) y valor esperado
  del eco de FF (`b"\\xff"` antes erróneo).
- `tools/ap07_sci_cpp_smoke.py`: crea, compila y ejecuta el
  código exacto DONOR_SCI + BASE_WAIT bajo un stub que respeta
  el acceso `private` de la clase base. Cinco pruebas: RX+TXD+idle,
  sincronización inválida, STOP inválido, 192 bytes y
  desbordamiento de 193 bytes.
- Los dos ejecutores integrales corren el smoke C++ antes de
  invocar el `make` caro y respaldan su log a Drive.
- `tools/ap07_static_campaign.py`: exige observación TXD real
  en la lógica del modelo y recepción por el host.

**Validación local independiente:** se compiló con
`g++ -std=c++20 -Wall -Wextra -Werror -pedantic -O0` un
programa de prueba aislado que implementa la misma lógica
RX/TXD y manejo de espera de la clase base; **5/5 PASS**.
IMPORTANTE: este programa local fue transcrito de los cambios
publicados y NO es un ensamblado MAME ni una ejecución de
`ap07_sci_cpp_smoke.py` contra el archivo Git de T;
para esa prueba exacta sigue pendiente el job.

**Evidencia anterior T:** 15/15 contrato y 18/18 ensamblado
Payload-0 (121 bytes), pero MAME falló por los accesos
`private` ya corregidos. No hay aún nuevo compilado
`ASPRO-DIAG`, ni RX/TXD MAME, ni LCD con BOOT OK.
`AP07_SCI_BEHAVIORAL_SOURCE_READY / CXX_LOCAL_MODEL_5_OF_5_PASS /
MAME_COMPILE_PENDING / DYNAMIC_PENDING / SILICON_BOOT_ROM_NOT_EMULATED`.

**Recursos:** última intervención autorizada consumió 3/3
llamadas Commander. No se ha hecho nueva llamada ni lanzado
nuevo job, esperando nueva autorización específica para la
siguiente intervención según la política universal. No tocar
donantes, no reabrir AP06 ni crear versión estable.
