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

## Actualización de evidencia — sesión PC y controles externos (20-oct-2026)

La campaña física real ya produjo `abcabc` (**6/6 bytes** tras dos `Send` en una conexión), con SHA256 `bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c`, y el binario ASPRO propio compila con `-j3`. El problema no está en el receptor Set 2: la prueba seguía capturando el puerto `PC_CONNECTED` como HIGH después de pedir su desconexión, como demuestra `ASPRO_AP06_PC_PORT_READBACK_1` en [observaciones de la tercera prueba](https://drive.google.com/file/d/1MqZ-FHgD9XidY8G9Y4dXUAXjbJsILrnW/view).

Se probaron dos arreglos insuficientes: `PORT_CHANGED_MEMBER` y un temporizador de 10ms. El estado `PORT_TOGGLE` continuaba enclavado pese a `attached:set_value(0)`, por lo que el cierre por desconexión no tenía aún un evento real LOW que observar.

**Corrección más reciente `d5c68bd7`:** entrada DIAG `PC_CONNECTED` sin `PORT_TOGGLE`; es un estado binario explícito `set_value(1)` para conectar, `set_value(0)` para desconectar. La representación de un botón de interfaz que alterna ese estado queda para el frontend, no para la señal subyacente. Se conservan callback+temporizador y todo el transporte probado. **Esta corrección no tiene todavía comprobación dinámica**. Exigir estado LOW leído del puerto, un solo evento de cierre y `abcabc` exacto antes de `FULL_SEND_SESSION_PASS`.

Evidencias del cierre incompleto: [primer `abcabc`](https://drive.google.com/file/d/1Kx5pDDaAm8YITgTIpgkO29gJ0TM3lX4p/view), [callback insuficiente](https://drive.google.com/file/d/1yzujO4DOhxqB05CAJpSIx74ki3qR3niP/view), [temporizador con puerto enclavado](https://drive.google.com/file/d/1h9jwgG582P-x4BdBjwTmnCWE4u7G6iN2/view). No confundir transmisión PASS con cierre de sesión PASS.

## Defecto compartido de activación diferida PC: observación del usuario y contraste estático AS2K (2026-10-20)

**Síntoma reportado en AS2K estable, tanto por menú como por atajo:** elegir Conectar PC no cambia inmediatamente el modo del firmware; tras pulsar **cualquier tecla** la conexión se activa. Tras `Send`/operaciones, Desconectar PC tampoco devuelve inmediatamente al editor; vuelve sólo después de pulsar otra tecla. Este comportamiento es evidencia de campo suministrada por el usuario, **no** ejecución nueva en T.

**Fuente precisa examinada, en solo lectura:** [AS2K-Emulator release/vontar-stable-public-20261018, `alphasma.cpp`](https://github.com/SamDelorean/AS2K-Emulator/blob/release/vontar-stable-public-20261018/src/mame/skeleton/alphasma.cpp), `ui_process_command()` (aprox. líneas 1828–1845). Los comandos `PC ON`/`PC OFF` modifican `m_ui_pc_connected`, el override y el receptor/sumidero, y emiten `STATUS`, **pero NO notifican IRQ al MC68HC11**. En contraste `ui_set_key()`, `ui_press_key()`, `ui_key_release()` y `kb_irq()` sí ejecutan `m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE)` (aprox. 277–280, 1680–1687 y 1781–1807); el firmware desactiva IRQ al seleccionar matriz (`kb_matrixl_w`, aprox. línea 298). [`as2k_ui.py::_toggle_pc()`](https://github.com/SamDelorean/AS2K-Emulator/blob/release/vontar-stable-public-20261018/frontend/as2k_ui.py) sólo envía `PC ON/OFF` y refresca el encabezado, **no solicita activación del firmware**.

**Diagnóstico:** código confirma **ausencia de evento IRQ en la transición del estado host**, y la observación del usuario coincide con una CPU esperando evento de teclado antes de volver a muestrear líneas PC (PA0/PA2). Es una **hipótesis causal fuerte pendiente de prueba dinámica**, no atribuirla aún a un cable de IRQ físico real; un IRQ lógico usado para despertar firmware **no implica** que las placas originales usen ese pin de manera idéntica.

**Diferencia importante en ASPRO:** el primer fallo específico Pro era un `PC_CONNECTED` tipo `PORT_TOGGLE` que continuó HIGH pese a `set_value(0)`, confirmado por `PC_PORT_READBACK_1`. Esto es **un segundo defecto de control**, distinto de la falta de notificación IRQ de AS2K. ASPRO ya eliminó PORT_TOGGLE; no decir que ambos bugs son literalmente el mismo sin pruebas.

**Cambio estático SOLO en ASPRO, commit `b638d5f26b285e61a3e38c9c8aa53f9917388feb`:** después de resolver una transición real PC conectado/desconectado en `sync_pc_session()`, emitir exactamente **un** `MC68HC11_IRQ_LINE ASSERT_LINE` y marcador `ASPRO_PC_HOST_EDGE_WAKE_IRQ attached=1/0`, sin pulsar tecla artificial, sin tocar decodificador Set2 ni almacenar el texto por SRAM. El firmware conserva la liberación normal de IRQ por su barrido de matriz. No hay nueva compilación ni prueba ejecutada aún de este ajuste: `STATIC_ONLY / DYNAMIC_PENDING`.

**Criterio dirigido mínimo antes de PASS:**

1. Conectar PC sin ninguna tecla posterior y observar en DIAG estado leído `PC_CONNECTED=1`, único marcador IRQ del borde conectado y la transición de firmware a modo host (LCD/observación ROM) **antes de pulsar Send**.
2. Tras dos `Send`, comprobar `send.txt` literal `abcabc`, único archivo/sesión y decodificador físico (ya comprobado en corridas anteriores; no volver a desarrollar).
3. Desconectar PC sin tecla adicional: `PC_PORT_READBACK_0`, un IRQ por borde desconectado, un `send_sink_end()`, `session_end_seen=true`, `session_close_count=1` y regreso visible del firmware al editor **sin teclado**.
4. No aceptar como prueba de activación del firmware un mero `STATUS PC connected` del menú GTK: es sólo UI. Verificar que el sistema no añade caracteres fantasma y que no deja IRQ permanentemente activo.

**AS2K**: no se alteró ningún archivo, binario o working tree. El defecto existe como **incidencia pendiente de corrección independiente bajo autorización**; arreglo mínimo propuesto en la rama apropiada del AS2K estable: emitir una notificación IRQ **sólo cuando cambie realmente `m_ui_pc_connected`** dentro de `PC ON/OFF` (y revisar además la alternativa Pause/Break), probar inmediatamente ambas transiciones tanto por menú como por combinación de teclas, sin rehacer `Send`, decodificador, UI ni emulador. Evitar doble IRQ o modificación de estado de teclado al recibir comandos repetidos.
