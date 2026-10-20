# AP-06 — PC Send → UTF-8 .txt por transporte físico (reutilización AS2K)

**Fecha:** 2026-10-20
**Estado:** `IMPLEMENTED_STATIC / COMPILE_PENDING / DYNAMIC_PENDING`. **NO es todavía un PASS de comunicación Pro.**

## Decisión de alcance

Implementar la comunicación **del AlphaSmart Pro original** a un PC anfitrión para que `Send` produzca un archivo `.txt`, reutilizando el núcleo ya calificado del emulador estable AS2K. Nada de emular una impresora, ejecutar MAME genérico, leer directamente contenido SRAM y fingir transferencia, reconstruir el HC11 ni modificar AS2K.

La interfaz solicitada es PC **primero**. ADB queda pendiente explícitamente de otra encomienda: su protocolo físico difiere del PC de dos hilos. IrDA no corresponde al Pro stock.

## Fuente de referencia realmente recuperada

**AS2K-Emulator**, rama `release/vontar-stable-public-20261018`, commit fijado `d66d8614314eb8bad20fdb4dc1e1aa21e148307d`, archivo `src/mame/skeleton/alphasma.cpp`; licenciado BSD-3. [Fuente pública](https://github.com/SamDelorean/AS2K-Emulator/blob/d66d8614314eb8bad20fdb4dc1e1aa21e148307d/src/mame/skeleton/alphasma.cpp).

Rutas operativas **ya probadas en AS2K**:
- `asma2k_state::asma2k_port_d_w`: PD0 flanco ascendente como clock, PD1 invertido como data.
- `pc_clock_rising`: toma trama de 11 bits, bit de inicio, bit de parada y paridad impar.
- `pc_set2_byte`: interpreta `F0`/break, `E0`/extend, `E1` e identifica teclas.
- `pc_key_event`: aplica Shift, Caps Lock, Alt-composición, mapa US a Unicode.
- `send_sink_codepoint`: serialización UTF-8.
- `send_sink_begin/end`: abre/sella un archivo de captura de la sesión.
- `frontend/as2k_ui.py::_save_send_capture`: Save As a `alphasmart-send.txt`, UI GTK. La campaña ASPRO actual es *headless* y guarda `send.txt` directamente, no abre diálogo.

**Comprobación estática:** las cinco rutinas `pc_keyboard_reset`, `pc_clock_rising`, `pc_set2_byte`, `pc_key_event` y `send_sink_codepoint` se trasladaron sin cambios lógicos; comparación textual exacta al normalizar solamente `asma2k_state::`→`aspro_send_state::` y `AS2K_PC_`→`ASPRO_PC_`: **5/5 coincidieron**. También se conservaron íntegros los mapas `s_set2_keys`, `s_pc_us_text`, `s_pc_windows_1252_extended`. Esto demuestra reutilización de código, **no** que el Pro emita idénticas tramas.

## Adaptación específica del Pro

Archivo nuevo **dentro de ASPRO**: `src/mame/skeleton/alphasma.cpp`, basado en driver MAME fijado `SamDelorean/mame-as3k/c4e48388ca620472643110db2941ce70aa5f3c07` (BSD-3), con clase `aspro_send_state`. Conserva íntegros LCD, teclado, memoria, MCU, ROM y selección de bancos Pro.

1. `PORT_START("PC_CONNECTED")` es una entrada de prueba propia de ASPRO, no una tecla física Pro; se expone mediante Pause/Break o Lua.
2. `pro_port_a_r` simula inicialmente **PA0=1, PA2=1** al conectar el PC, retomando el host sense probado AS2K. **Hipótesis por probar con ROM Pro 2.1.2**, no pinout real medido.
3. `pro_port_d_w` entrega exclusivamente los flancos de PD0 y PD1 al decodificador Set-2 reutilizado; datos PD2–PD5 conservan su relación con los KS0066 Pro sin cambios.
4. `send_sink_begin` crea **únicamente** `send.txt` en el `-snapshot_directory` privado del proceso de ASPRO, tras **recibir una trama válida de 11 bits**. No construye texto a partir del framebuffer, NVRAM, metadatos ni ROM.
5. `send_sink_end` cierra/descarga al terminar la sesión; el estado de decodificación no es persistente ni toca DynFS.
6. **Tecla Send Pro** según matriz propia: `COL.7`, bit `0x01`. **No** usar el bit `0x10` de AS2K en esa misma columna.

La fuente completa vive en ASPRO para construir su propia variante. **AS2K estable y su driver donante no se han modificado.**

## Cadena de ejecución agrupada

- `tools/prepare_send_mame.py`: exportar *sólo lectura* el HEAD Git del **árbol MAME de referencia que ya está instalado en T640** a `ASPRO-emu/build/send-mame`. No compila en AS2K, no consume cachés ni ejecutables ajenos, registra SHA de HEAD y SHA del driver; no sobrescribe árboles existentes sin marcador.
- `tools/build_send_diag.sh`: compilar `TARGET=mame SUBTARGET=asprodiag SOURCES=src/mame/skeleton/alphasma.cpp` en `ASPRO-emu/build/send-mame` con el driver ASPRO Send. Es necesario producir **una variante independiente** del binario previo: el motor adoptado de AP-04 no contiene el callback nuevo, por lo que no puede dar un `send.txt` genuino sin recompilar.
- `tools/ap06_pc_send_observe.lua`: arranque stock; a ~8 s escribir `abc` en archivo actual; conectar PC después, observar LCD, pulsar Send **en matriz Pro**, esperar, desconectar, observar salida.
- `tools/ap06_send_campaign.py`: validar hashes ROM/CGROM/ELF y manifiesto, ejecutar **únicamente** el nuevo `asprodiag`, registrar capturas y señales; aceptar `SEND_TXT_DYNAMIC_PASS` **sólo** si del decodificador físico proviene exactamente `abc` (3 bytes), con marcadores de teclado y conexión y salida del proceso 0. La presencia de `send.txt` vacío/no idéntico es `UNVERIFIED`, no PASS.
- `tools/ap06_run_once.sh`: las dos ROM privadas se leen por `rclone googledrive:` y se limpian; los reportes/capturas y, **sólo cuando el resultado sea exacto**, el archivo `.txt` se guardan en Drive privado `ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE`. No publicar datos privados en GitHub.

La ejecución debe hacerse en la T640 canónica exclusivamente bajo autorización Commander explícita (presupuesto ≤3 llamadas, preferencia **una intervención agrupada**), y las evidencias deben recuperarse de Drive sin polling. Para relanzar la primera prueba, no repetir AP-02/03/04 ni compilar en AS2K.

## Criterios de salida

- `STATIC_CODE_REUSE_PASS`: ya comprobado para el transporte (5/5).
- `COMPILE_PASS`: **PENDING**, exige ejecutable de variante Send propia y SHA de build.
- `PC_ATTACHMENT_PASS`: **PENDING**, debe visualizar o instrumentar modo PC del firmware Pro, no sólo subir PA2.
- `PC_SEND_WAVEFORM_PASS`: **PENDING**, requiere tramas Set-2 válidas del firmware real.
- `TXT_EXACT_PASS`: **PENDING**, requiere `send.txt` UTF-8 con exactamente `abc`, derivado sólo de bytes de salida del firmware.

Si el Pro usa otra codificación, líneas, host sense o tiempo que AS2K, adaptar **únicamente** la entrada/salida en `aspro_send_state`, preservando el decodificador probado donde resulte compatible y sin forzar un falso positivo. **No** convertir en exportación directa de SRAM para pasar la prueba.

## Fuera del alcance

- ADB/Mac, IR, USB, impresora, ASCii/OCR desde la pantalla; no prometidos en AP-06.
- Interfaz GTK propia de ASPRO: la petición de un `.txt` se satisface primero con salida automática privada real, sin construir estable ni cambiar decisión de producto.
- Emulador AS2K y Runtime AS2K: sólo lecturas de referencia, nunca escrituras.

## Enmienda autorizada: límites de sesión por conexión PC

**Regla explícita del usuario:** **conectar PC abre una sesión y desconectar PC la cierra**. Ninguna pulsación Send debe abrir otra captura ni cerrarla. La clase ASPRO `aspro_send_state` ahora detecta los cambios de `PC_CONNECTED` durante el sondeo PA/PD, ejecuta `send_sink_begin` al conectar y `send_sink_end` al desconectar, y sólo procesa bytes físicos durante la sesión. Dos pulsaciones Send consecutivas sobre un único archivo que contiene `abc` deben generar **un único `send.txt` con `abcabc`**, no dos archivos ni un fichero sustituido. Se exigen los marcadores de comienzo/fin, exactamente una apertura/cierre, y la coincidencia literal de seis bytes. `machine_stop` conserva únicamente un cierre de seguridad si hay una desconexión abrupta; no es el contrato normal. Esta enmienda se validará con el firmware Pro, no se asume PASS sin prueba.
