# Manifiesto canónico — ASPRO Stable v0.1.0

Fecha de corte: **21 de octubre de 2026**.
Repositorio: `SamDelorean/ASPRO-emu`.
Rama estable: `release/stable-v0.1.0-vontar-surf`.

## Paridad fuente realmente instalada

Los siguientes objetos Git **se verificaron en los dos equipos**
mediante `git hash-object` de los archivos instalados/staged y
comparación con el árbol de GitHub.

| Fuente | SHA de objeto Git |
| --- | --- |
| `stable/alphasma.cpp` | `fe589b3a5f9203eb42c309cf3dc83567028db8dc` |
| `stable/aspro_ui.py` | `572b6717e5e1e18ac224bf57829bfd4f8751690c` |
| `stable/aspro_session.py` | `873f6263708b58025526bb9d056773b7b3272d40` |
| `stable/proven_hc11/mc68hc11.cpp` | `f25752fc03165c9938a456ae9c0d6d9e9b5841f0` |
| `stable/proven_hc11/mc68hc11.h` | `fb08eb8386b9c06712c34d883f91199160132d4b` |

## Evidencias de producto instalado

| Host | Arquitectura | Estado | SHA-256 binario de producción |
| --- | --- | --- | --- |
| Vontar (Armbian) | aarch64 | BUILD/VALIDATE/INSTALL PASS, `EXIT=0` | `2c0282172b43cb1d4d33c92d32abe2505a77f99b65bbf36aeb6181e431eb12b1` |
| Surf (postmarketOS) | ARMv7 musl | BUILD/ROM-smoke PASS; instalación y coincidencia binaria PASS después de reparación de permisos | `aa4c96cc8b3c0b5ea61f96622ae354627a69482dc752b1296e6385de7c376223` |

El binario Surf NO se derivó del de Vontar ni de compilación cruzada
en T. Se produjo directamente en Surf, con el compilador y bibliotecas
ARMv7/musl y la adaptación original `bx` de 17-oct.

Los registros de Vontar documentaron exactamente **1 controlador
`asmapro`** y los de Surf `-listfull` también identificaron
`asmapro`. El constructor AS2K Stable se reutilizó como patrón,
sin copiar ni sobrescribir el producto instalado.

## Insumos privados (solo identidad, sin contenido)

- Firmware Pro 2.1.2: 32.768 bytes, SHA-1
  `c3c6a421c9ced92db97431d04b4a3f09a39de716`.
- CGROM KS0066 F05: 4.096 bytes, SHA-1
  `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- Payload bootstrap SCI: 121 bytes, SHA-256
  `25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`.

## Alcance de las pruebas y límites

- ASPRO-DIAG previo: pruebas funcionales de SCI/bucle de
  transmisión, teclado y LCD registradas en `docs/AP07_FUNCTIONAL_PASS_20261020.md`.
- Vontar producto Stable: compilación, validación y binario/GUI
  estáticos PASS; **no verificado con prueba interactiva posinstalación**.
- Surf producto Stable: compilación y arranque con ROM original
  sin interfaz gráfica PASS; fuente y ejecutable instalado coincidentes;
  **sin prueba interactiva posinstalación**.
- MAME advierte `ks0066_f05.bin ROM NEEDS REDUMP`; la advertencia
  no impidió la prueba de arranque, pero no debe ocultarse.
- No se afirma PASS de teclado, pantalla, PC o bootstrap **en la
  interfaz pública instalada** hasta ejecutar pruebas específicas.

## Integridad y privacidad

Esta rama no contiene ROMs, firmware, NVRAM ni payload binario.
El código fuente del procesador y el driver constituye adaptación
del proyecto MAME; conservar cabeceras y licencias originales.
No crear ni subir paquetes con contenido privado.

## AP08 — ASPRO Stable native Pro keyboard mapping (22 Oct 2026)

**Incremento de fuente (rama `main`), NO instalado, NO compilado.**
El manifiesto `v0.1.0` y los hashes SHA256 de los ejecutables previos
conservan su validez histórica; no corresponden aún al nuevo mapeo.

- Se modificó **solo** `aspro_send_state::ui_key_location()` del
  `stable/alphasma.cpp`. Las coordenadas columna/bit originales procedían
  de AS2K y no del AlphaSmart Pro; el lector de teclado Pro sí usa la matriz
  `INPUT_PORTS_START(alphasmart)` definida en este mismo archivo.
- Auditoría de 79 entradas anteriores: 75 coordenadas erróneas corregidas,
  3 coincidían (0, QUOTE, DOWN), y la entrada virtual FIND no tiene
  contacto Pro físico documentado y quedó sin asignación deliberadamente.
- Resultado estático: **78/78 coordenadas coincidentes** con el mapa Pro;
  26 letras, 10 dígitos y F1–F8 incluidos; sin contactos duplicados.
  Ejemplos: A=col14/0x10, Z=col14/0x80, F1=col13/0x01,
  SEND=col7/0x01.
- Comparación completa de la fuente previa `release/stable-v0.1.0-vontar-surf`
  con el nuevo `main`: **únicamente cambió esta función**.
  Permanecieron intactos HC11D0, señal IRQ, bancos RAM, LCD, bootstrap SCI,
  puertos PC y NVRAM; ningún archivo privado fue abierto.
- Fuente corregida Git blob `a0ebec7eced44e82f113615cff05acc6b7d28b40`.
  Prueba independiente `tools/test_pro_ui_matrix.py`: reproduce la
  comparación de todos los contactos contra el bloque de puertos Pro,
  ejecutable con `python3 tools/test_pro_ui_matrix.py`; no precisa MAME ni
  Commander. La comprobación equivalente de paridad se completó en análisis
  estático, pero **no se afirma ejecución de ese script en un host**.
- **Estado**: STATIC_MAP_MATCH_PASS / SOURCE_UPDATED / COMPILE_PENDING /
  INSTALLED_PENDING / RUNTIME_KEYBOARD_PENDING.
- Próximo incremento limitado: compilación nativa incremental de VONTAR
  reutilizando el constructor estable y prueba del editor con A/ABC123,
  sin alterar el binario AS2K ni reconstruir MAME completo. Surf se
  actualizará después de la prueba de la nueva implementación.

## ASPRO-DIAG-first — referencia de teclado conservada (22-oct-2026)

Decisión del usuario: **comenzar en DIAG, no compilar Stable todavía**.
Se cotejaron únicamente las fuentes públicas y las evidencias previas.
No se ejecutó Commander, no se descargaron ROM privadas y no se modificó,
recompiló ni sustituyó `asprodiag`.

- `src/mame/skeleton/alphasma.cpp` DIAG, Git blob
  `14796d807aa731035d572bc5c3ef1e00bf970887`, lee directamente
  `m_keyboard[i]->read()`; **no utiliza** la máscara virtual
  `m_ui_keyboard` ni la tabla `ui_key_location()` introducida por GTK Stable.
- El bloque `INPUT_PORTS_START(alphasmart)` coincide **80/80 entradas
  físicas** entre DIAG y Stable; no procede alterar la matriz Pro de DIAG.
- `tools/ap03_startup_observe.lua` inserta `A` mediante el contacto real
  `COL.14`, máscara `0x10`, `set_value(1)` / `clear_value()`.
  La evidencia AP-03 histórica ya estableció letra `a` visible en LCD.
- AP-04 validó F1–F8 y recuperación NVRAM tras reinicio real del MAME
  diagnóstico, con las restricciones documentadas en
  `docs/AP04_FILES_NVRAM_FUNCTIONAL_EVIDENCE.md`.
- Se extendió la prueba **existente**
  `tools/test_pro_ui_matrix.py` con el contrato de paridad DIAG/Stable
  y la inyección Pro física de AP-03, evitando crear otro script de
  diagnóstico o duplicar la instalación DIAG.
- La comparación equivalente de código y de los 80 contactos sí fue
  realizada como análisis estático. **El script Python actualizado no fue
  ejecutado en el equipo** y **no hay nueva prueba dinámica** de esta ronda.
- Diferencia causal confirmada: el mapa erróneo que explica la falta de
  texto existe **solo en la ruta GTK Stable** y fue corregido en fuente
  `main`. DIAG continúa como baseline inalterado.
- Rendimiento: AP-03 observó el editor listo al primer checkpoint
  de **8 segundos emulados**, no una medida de segundos reales. El
  retardo del usuario en Stable requiere una comprobación dirigida de
  tiempo real antes de atribuirlo al HC11 o a `Testing RAM...`.

**Estado:** DIAG_SOURCE_MATRIX_PARITY_PASS (80/80),
DIAG_PREVIOUS_KEYBOARD_AND_NVRAM_FUNCTIONAL_PASS (AP-03/AP-04),
DIAG_NEW_RUNTIME_NOT_RUN, STABLE_BUILD_NOT_STARTED.

## AP-08 — tiempo real de arranque en ASPRO-DIAG (22-oct-2026)

**Corrida nueva, real, en T640 y sin recompilar**. Se usó el binario
diagnóstico existente, verificado con su manifiesto SHA256, el firmware Pro
y la CGROM privada (identidades verificadas y staging eliminado después).

- Primer ciclo, NVRAM temporal nueva: 12 s emulados completados en
  **0.555 s reales**; frame 400 (~8 s emulados) en ~0.403 s;
  pulsación A DOWN/UP y diferencia LCD de 24 píxeles en x0–10,y2–7.
- Segundo ciclo, NVRAM recuperada: 12 s emulados en **0.504 s reales**;
  frame 400 en ~0.403 s; pulsación A DOWN/UP y diferencia LCD de 24
  píxeles en x6–16,y2–7.
- Ambos `exit=0`, `OBSERVATION_COMPLETE`, imagen NVRAM de 131072 B
  y `ASPRO_AP08_BOUNDED_DIAG_TIMING_PASS`. Se ejecutó con
  `-nothrottle`, sin GTK y con `-video none`, de modo que **no** se
  extrapola esta velocidad a VONTAR/Surf ni a la ventana pública.
- Prueba e informe:
  [AP-08 DIAG cold/warm](../docs/AP08_DIAG_COLD_WARM_TIMING_20261022.md).
  Resultado privado en
  `~/Projects/alphasmart/ASPRO-emu/private/ap08_timing/diag_timing_lz6rk5lr/report.json`.
- **Commander:** dos llamadas T640, sin modificar DIAG, ASPRO Stable,
  AS2K, Surf ni VONTAR. La prueba visual original del carácter A continúa
  sustentada por AP-03, no por un clasificador OCR de AP-08.

**Interpretación:** el núcleo de DIAG responde rápidamente; la lentitud
notificada en Stable aún requiere validación de su propia ruta GTK/ARM.

## AP-09 — corrección sintáctica del mapa Pro y optimización GTK LCD (22-oct-2026)

**Alcance:** fuente ASPRO Stable en `main`. Se conserva ASPRO-DIAG como
referencia funcional intacta. **No hubo compilación MAME, instalación,
cambio de ROM ni Commander** en este incremento.

1. Se identificó un error de sintaxis oculto por la comparación de
   coordenadas previa: la eliminación de la entrada FIND dejó
   `{ "SEND",7,0x01 }, , { "UP",7,0x08 }`.
   Se retiró la coma sobrante en `stable/alphasma.cpp`. El mapeo Pro
   conserva **78 entradas** válidas y el contacto físico de FIND sigue
   sin atribuirse.
2. `tools/test_pro_ui_matrix.py` ahora rechaza expresamente la secuencia
   de comas duplicadas y comprueba paridad entre matriz física Pro,
   puente GTK y referencia DIAG. **La nueva revisión del test no fue
   ejecutada en un equipo remoto**.
3. `stable/aspro_ui.py` deja de expandir el LCD de 240×36 píxeles
   mediante bucles Python; agrega `frame_to_rgb(raw)` con expansión de
   bytes en código nativo de Python, valida 8640 bytes 0/1, crea un
   `GdkPixbuf` RGB24 de stride 720, conserva el último fotograma y
   elude repintar contenido idéntico. La marca temporal se compromete
   después de una conversión correcta. Se retiró el botón virtual
   `Find` no implementado.
4. Se agregó `tools/test_stable_lcd_frontend.py`: prueba sin GTK ni ROM
   de fotogramas 0, 1, alternados, longitud y valores inválidos; prueba
   estática de política de caché y comandos de teclado.
5. **Pruebas locales, aisladas (no MAME ni GUI):**
   `ISOLATED_EXACT_FRAME_TO_RGB_FRAGMENT_PASS` y
   `ASPRO_PRO_KEYMAP_ISOLATED_CPP_SYNTAX_PASS` usando el fragmento de
   tabla extraído y compilador C++17 local. No equivalen a compilar todo
   `alphasma.cpp` con el árbol MAME.
6. **Medición sintética local**, 100 cuadros en el método anterior y
   10000 en el nuevo: ~2.170 ms vs ~0.122 ms por fotograma
   (**17.7×** en expansión RGB solamente). CPU local y condiciones
   sintéticas; no demuestra aceleración proporcional de ASPRO ARM.
7. La referencia [AP-08 DIAG](../docs/AP08_DIAG_COLD_WARM_TIMING_20261022.md)
   sigue siendo la evidencia de arranque sin GTK en la T640
   (12 s emulados en 0.555/0.504 s reales, `-nothrottle`).

**Estado:** SOURCE_PREPARED / ISOLATED_RENDER_CONVERSION_PASS /
ISOLATED_CPP_TABLE_SYNTAX_PASS / FULL_MAME_COMPILE_PENDING /
STABLE_ARM_GUI_RUNTIME_PENDING. Las instalaciones v0.1.0 de VONTAR
y Surf siguen ejecutando binarios anteriores; no atribuirles el arreglo.
