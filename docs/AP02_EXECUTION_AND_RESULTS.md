# AP-02 — implementación y ejecución dirigida de ASPRO-DIAG

Fecha: 2026-10-19. Destino exclusivo: `SamDelorean/ASPRO-emu`.
Base de producto inspeccionada: `7ff52d3813202cbc32d3945b5d3a2310d94a9434`.
Rama: `codex/ap02-aspro-diag-20261019`.

| Área | Resultado de esta sesión |
|---|---|
| Implementación/preparación AP-02 | STATIC_PASS |
| Compilación nativa ASPRO-DIAG | COMPILE_PENDING |
| RESET/HC11 real, pantalla y respuesta de teclado | DYNAMIC_PENDING |
| Commander / ejecución T640 | 0 llamadas; no autorizadas en esta sesión |
| PASS funcional Pro | NO declarado |

AP-02 funcional permanece abierto. Esta entrega completa la preparación viable
en Cloud; no sustituye la intervención auténtica con ROM privada.

## Entorno y aislamiento comprobados

- Checkout de trabajo: `/workspace/ASPRO-emu`, independiente y con acceso Git.
- Referencia AS2K en sólo lectura: `/workspace/AS2K-Emulator`, HEAD
  `9cc0bd98aeb21e2ea77de878a8833a1047c88169`, rama
  `codex/stable-dictrom-payload-port-20261014`, limpia antes/después.
- No se ejecutó `make`, tests, generación ni escritura en AS2K.
- Cloud: Python 3.12.14, GNU Make 4.4.1, g++ 14.2.0, rclone 1.60.1-DEV.
- No hay árbol completo MAME ASPRO ni binario `asprodiag` preparado aquí.
  `pkg-config --exists sdl2 SDL2_ttf fontconfig` devuelve 1; `rclone listremotes`
  no devuelve remotes configurados. No se instalaron toolchains ni se trasladó
  firmware privado a Cloud. El compilador disponible por sí solo no habilita
  la compilación completa ni autoriza acceso a los insumos privados de T.

## Fuente reutilizada e identidad

Fuente fijada: `SamDelorean/mame-as3k@c4e48388ca620472643110db2941ce70aa5f3c07`.
Se leyeron directamente sus fuentes públicas y contratos, sin importar firmware:

| Archivo | SHA-256 de referencia |
|---|---|
| `src/mame/skeleton/alphasma.cpp` | `bb2cd7f14366c7dc58a7af6e2961b5f70e670cc54a23770d3ff0b5e1ff776cf6` |
| `src/devices/video/hd44780.cpp` | `d4fda79297278886de911253a7c2f112ab3004d6fb448cc509619cb0d011bd6d` |

`prepare_mame.py` exporta sólo el árbol Git de ese commit, usando una referencia
local existente suministrada explícitamente. No copia objetos de compilación,
ROMs, archivos no versionados ni una segunda base Git. No modifica el worktree de
referencia. El destino es exclusivamente `ASPRO-emu/build/mame`; se verifican
solapamientos, enlaces que escapan, marcador de propiedad y hashes del driver/LCD.
Un árbol propio ya válido se reutiliza; un destino incompleto o desconocido falla
sin borrarlo. Esto requiere espacio para una copia de fuentes, no para otra
instalación AS2K ni un clon de sus cachés.

`build_diag.sh` conserva TARGET=mame, SUBTARGET=asprodiag,
SOURCES=src/mame/skeleton/alphasma.cpp, REGENIE=1, TOOLS=0 y USE_QTDEBUG=0.
Usa sólo su árbol/objetos privados y deshabilita ccache compartido. No parchea
CPU/LCD/teclado/RAM. El único binario de pruebas es `asprodiag`, ejecutado siempre
como `asmapro`. Aunque el único archivo fuente registra también AS2K, ese sistema
no se ejecuta. La salida debe ser ELF y recibe manifiesto privado de compilación,
commit fuente, commit producto y hash del binario; el runner verifica ese vínculo.

## Contratos reales del instrumento

Revisados en el mismo commit de MAME:

- `src/emu/debug/debugcmd.cpp`, `docs/source/debugger/{general,breakpoint,watchpoint}.rst`:
  `bp dirección,condición,{acción}`, `wpset dirección,longitud,r|w,condición,{acción}`,
  `rp condición,{acción}` y `logerror formato,...` con `-log` hacia `error.log`.
  AP-02 no necesita `rp`: sus sondas finitas usan bp/wp y vuelven con `g`.
- `src/osd/modules/debugger/none.cpp`: el proveedor `-debugger none` existe y
  continúa la CPU; no se infiere esa opción de un nombre inventado.
- `src/emu/emuopts.h`: debugscript, autoboot_script/delay, homepath y directorios
  de artefactos son opciones reales. `-noreadconfig` evita configuraciones ajenas.
- `src/frontend/mame/luaengine.cpp` y `luaengine_input.cpp`:
  `emu.register_frame_done`, `screen:pixels()`, `screen:snapshot(filename)`,
  `ioport_field.mask`, `set_value` y `clear_value` son interfaces existentes.

Las sondas no cambian registros CPU ni memoria de firmware. RESET $C000 se
observa antes de ejecutar; $C003 permite registrar SP tras LDS #$00FF. El vector
FFFE, lecturas/escrituras de matriz 8000/C000 y escrituras PORTA/PORTD tienen
máximo 12 muestras cada una. No hay traza por instrucción ni contenido de memoria
volcado. Las sondas de puertos bajos suponen INIT=0; una relocalización posterior
no se interpreta como ausencia de actividad del hardware.

**Límite explícito:** PORTD escrito es actividad del bus, no prueba de una escritura
aceptada por KS0066. La selección de banco calculada del dato PORTA no es prueba
completa de transición visible. `lcd_bus_write` queda UNVERIFIED. No se interpreta
la llegada a RESET como PASS de pantalla.

El observador Lua toma estado visual a frame 150, pulsa A a 180 y la libera a 190,
comparando a 240 (pantalla heredada de 50 Hz). Localiza COL.14/máscara 0x10 del
Pro original; no altera la matriz del driver ni crea otra implementación.
Frame distinto tras la tecla significa **correlación**, no carácter confirmado:
puede coincidir con un cursor o el arranque. Texto LCD y respuesta funcional de
teclado permanecen UNVERIFIED hasta inspección de evidencia auténtica.

Captura `auto`: usa `-video soft` con DISPLAY existente o xvfb-run+xauth ya
instalados. Sin ellos usa `-video none` y deja screenshots PENDING. `--capture soft`
bloquea si falta una ruta de captura válida. No se instala un servidor gráfico.
Las imágenes se guardan sólo en almacenamiento privado; se registran hashes PNG,
no contenido en Git. Lua/depurador todavía requieren validación en MAME real.

## Job autónomo y privacidad

`tools/ap02_run_once.sh` funciona desde cualquier CWD, resuelve su propio proyecto
y requiere referencia Git y nombre rclone explícitos. Orden agrupado:

1. herramientas existentes, remote configurado y dependencias SDL/fontconfig;
2. exportar/reutilizar fuentes aisladas y compilar sólo ASPRO-DIAG;
3. verificar con rclone las dos rutas privadas documentadas y descargar sólo
   esos archivos a un directorio temporal propio;
4. exigir identidad ROM Pro 2.1.2, RESET e identidad CGROM, incluida la copia ZIP;
5. ejecutar un único `asprodiag asmapro`, 8 segundos emulados, con timeout de pared;
6. finalizar/limpiar sólo su grupo de procesos y sus copias temporales;
7. conservar resumen, identidad fuente/binario, versiones, logs acotados,
   observaciones y snapshots/NVRAM privados en `ASPRO-emu/private/ap02/job-*`.

Las entradas son las rutas Drive ya documentadas en AP-01:
`ALPHASMART/Alphasmart Pro/asmapro/alphasmartpro212.rom` y
`ALPHASMART/private/roms/ks0066/ks0066_f05.bin`.
No se inspeccionaron credenciales ni se descargaron estas ROM en Cloud.

El log de construcción retenido es la cola de 1 MiB (pipefail conserva el error).
El proceso DIAG tiene límite por archivo de 1 MiB para logs/salidas y timeout
con eliminación de su sesión, incluyendo Xvfb propio. NVRAM/estados/capturas/logs
son privados y se excluyen de Git. El script no sube automáticamente ese directorio
a Drive: nunca copiarlo completo a un outbox, porque contiene artefactos privados.
Un resumen con exit=0 sigue siendo FUNCTIONAL_UNVERIFIED; instrumentación incompleta
no devuelve éxito del runner. No hay binario sintético ni emulador suplente.

## Verificación local ejecutada

Una comprobación agrupada sobre fixtures exclusivamente sintéticos:

```sh
bash -n tools/build_diag.sh tools/ap02_run_once.sh
python3 -m py_compile tools/*.py
python3 tools/static_selftest.py
git diff --check
```

PASS: controles AP-01 de ROM/RESET/invariancia/HEX y checksum negativo; seis casos
AP-02, incluyendo timeout, error al lanzar y salida 0 sin observaciones, limpieza
tras fallo parcial de ZIP, rechazo SHA/reset, propiedad/hashes de fuentes,
límites de enlaces simbólicos y contrato acotado del depurador/captura.
Los procesos se simulan **sólo dentro de esas pruebas unitarias de orquestación**;
no se crea ningún ejecutable falso ni se presenta esa simulación como ejecución
HC11. Shell/Python verificados; no hay luac disponible para validar Lua localmente.

## Primera intervención agrupada T640 — pendiente de autorización

En el checkout real de ASPRO de la rama publicada, ejecutar una sola vez:

```bash
bash tools/ap02_run_once.sh \
  --mame-source /home/spc/Projects/alphasmart/mame-as2k \
  --drive-remote googledrive: --jobs 2 --capture auto
```

La ruta T es la referencia **documentada**, no una ruta que se haya verificado
remotamente en esta sesión; el script comprueba existencia/commit antes de usarla
como origen Git de lectura. No compila allí. El remote también debe existir en T;
si no existe devuelve BLOCKED_DRIVE_REMOTE sin credenciales nuevas en chat.
No se creó job/cola global ni se invocó Commander. La autorización futura será
para esta intervención concreta, máximo tres llamadas y sin polling remoto.

Si falta una dependencia real, conservar el fallo exacto y corregir esa causa;
no ejecutar MAME genérico ni reconstruir un entorno alternativo. Si el DIAG corre,
inspeccionar primero RESET/SP, marcadores, capturas y respuesta a A para clasificar
la funcionalidad. No reabrir AP-01 ni declarar que compilar equivale a arrancar.

Comprobación adicional del camino bloqueante real: se invocó el job desde `/tmp`
con un nombre rclone deliberadamente no configurado. Devolvió exit 2 y
`BLOCKED_DRIVE_REMOTE`, antes de exportar fuentes, compilar o recuperar ROMs.
Esta prueba verifica localización por CWD y fallo seguro; no es ejecución DIAG.

## AP-02 fast path — reutilización de MAME-DIAG AS2K en la T (2026-10-19)

La infraestructura canónica de T640 incluye MAME 0.289, `as2kdiag`, rclone `googledrive:`, sudo y compilaciones ya ejecutadas. Las carencias de Codex Cloud no implican carencias de la T. No reabrir esos preflights sin error real.

Se añadió `tools/adopt_engine.py`, que **sólo consulta** `-listxml asmapro` en el ejecutable `as2kdiag` ya existente y exige la ROM Pro exacta por SHA-1. Si la máquina está incluida, realiza copia **independiente** del binario en `ASPRO-emu/build/prebuilt/asprodiag` y registra hashes/procedencia. Nunca ejecuta Pro usando `as2kdiag`, no escribe en AS2K y no declara PASS por copiar un ejecutable. Si `asmapro` falta, `tools/ap02_run_once.sh` cae automáticamente a la compilación ASPRO reducida de AP-02 en un directorio independiente.

No repetir pruebas HC11, LCD ni teclado ya cerradas en AS2K: la única prueba nueva consiste en el firmware y el mapa de plataforma Pro (RESET, teclado, LCD, SRAM). Esta optimización **no ha sido ejecutada ni validada en T**. Toda intervención Commander debe contar con autorización concreta y preservar su máximo de llamadas.
