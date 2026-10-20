# AP-03 — AlphaSmart Pro 2.1.2: arranque y primera escritura en ASPRO-DIAG

**Fecha:** 2026-10-20. **Instrumento:** ASPRO-DIAG, rama `codex/ap02-aspro-diag-20261019`, producto ejecutado `941e41b30be4b758c5d873b10e39fc90cf85d1de`. Sin ejecución del firmware Pro en AS2K ni en MAME genérico. No se recompiló el motor.

## Resultado de la inspección real

**`BASIC_BOOT_LCD_KEYBOARD_MANUAL_VISUAL_PASS`**, exclusivamente para la secuencia comprobada: ROM arranca, pasa la etapa «Testing RAM...», abre pantalla vacía del editor, recibe una pulsación de A y presenta la letra minúscula `a` con cursor desplazado. Esto **no** equivale a PASS integral del editor, archivos F1–F8 o persistencia/NVRAM, y tampoco demuestra funcionamiento en placa física.

### Por qué AP-02 parecía detenido

Las primeras capturas AP-02 se tomaron en los frames 150 y 240 de pantalla a 50 Hz (3,0 y 4,8 s emulados). Ambas mostraban `Testing RAM...`; las imágenes diferían únicamente en un rectángulo 5×7 píxeles (x84–88,y27–33), correspondiente al indicador de actividad, **no** a una tecla insertada. Se concluyó que era prematuro diagnosticar un bloqueo de RAM. La ROM contiene literalmente `Testing RAM...` en su área de mensajes, e invoca una prueba de memoria tras imprimirlo; no se alteró ni parcheó ese firmware.

### Corrida AP-03 dirigida (30 segundos emulados, sin recompilación)

- T640 canónica, se usó el `asprodiag` privado ya adoptado (SHA-256 `e55b25dc4540d89c4e292b03a009dd32b4cb396c943aaec9fe3e9dbe828dc7ba`). Este SHA coincide con el motor MAME-DIAG canónico reutilizado; la variante ASPRO se ejecuta desde directorio y NVRAM independientes.
- ROM privada Pro 2.1.2: SHA-256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`; KS0066 F05 SHA-1 `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- Script `tools/ap03_startup_observe.lua`, seleccionado por `run_diag.py --seconds 30`: snapshots frame400 (8 s), frame800 (16 s), frame1200 (24 s), frame1350 (27 s, antes), inyección A en frame1380 (27,6 s), liberación en frame1400 (28 s), snapshot final frame1450 (29 s).
- **A los 8, 16, 24 y 27 s:** pantalla vacía del editor y cursor en primera posición; prueba de RAM ya superada desde el primer checkpoint.
- **A los 29 s:** letra `a` visible en la primera posición y cursor a su derecha, sin alteraciones en el resto de la pantalla.
- Comparación exacta RGB entre imágenes `before.png` y `after.png`: resolución **240×36**, **31 píxeles diferentes**, **caja [x0..10,y0..7]**, y todos los demás píxeles iguales. El mismo observador nativo anotó `ASPRO_DIFF_PIXELS=31_BBOX=0,0,10,7`.
- `ASPRO_KEY_DOWN_A`, `ASPRO_KEY_UP_A`, `ASPRO_OBSERVATION_COMPLETE` registrados; `exit_code=0`, `input_cleanup=COMPLETE`, sin modificación de AS2K ni recompilación.
- El reporte automatizado `run_diag.py` conserva expresamente `functional_pass:false`, `functional_keyboard:UNVERIFIED` y `lcd_text:UNVERIFIED`, porque su clasificador no decodifica caracteres ni aplica criterios de visión. **La categoría PASS de este documento es una valoración manual posterior de la evidencia visual**, no un valor generado por el runner.

### Fuentes de evidencia privadas en Google Drive

- [AP-02 antes, Testing RAM](https://drive.google.com/file/d/1iA5H-iM5Sa5fvOF9-tkAVKZfo_5FdVcq/view).
- [AP-02 después, Testing RAM](https://drive.google.com/file/d/1INN0xLcl1rfQXySd0sjv748b1XUpTrUp/view).
- [AP-03 editor ANTES](https://drive.google.com/file/d/1-pZpInWT71bLrEZjA5XlGPiBtAHCq9P5/view).
- [AP-03 editor DESPUÉS, con `a`](https://drive.google.com/file/d/13NUyq1W99x6LvnjYCrTcdVL1ngScGoAD/view).
- [AP-03 pantalla a 8 s](https://drive.google.com/file/d/1YOfrOl8flCEKxo5_u5w8dp5ZH1MlzA97/view).
- [AP-03 pantalla a 16 s](https://drive.google.com/file/d/1OfKjq6ITzw_7LRdQezKeMr6GaIHMiGfx/view).
- [AP-03 pantalla a 24 s](https://drive.google.com/file/d/1ptKnemhxXIpaujyjzsJhJdg0ayeThoQ5/view).
- [AP-03 runner JSON](https://drive.google.com/file/d/1wS0wGW0DLZJvOC62duHX0SyhDD7JfbM2/view).
- [AP-03 marcadores de observación](https://drive.google.com/file/d/1yahKW3yHPsyhFat7igm7uJ2rOBmM3Jvs/view).
- [AP-03 launcher](https://drive.google.com/file/d/1LgqYnhB8VuyYyeNdZk9AH2taeapKl5qR/view).

No introducir capturas, ROM, caracteres, NVRAM ni contenido privado en GitHub. En Drive están bajo permisos de usuario y permanecen fuera del repositorio.

## Continuidad / alcance pendiente

**No** repetir la prueba de arranque/tecla A ni recompilar por rutina; conservar sus SHA y enlaces. La siguiente verificación justificada es una campaña acotada que reutilice la instrumentación actual para **selección de archivos F1–F8 y persistencia NVRAM tras reinicio**, sólo si resulta necesaria para cumplir el criterio completo del plan AP-03. Antes de construir una versión estable o tocar AS2K, presentar al usuario el estado funcional y las opciones de integración. La decisión producto ASPRO separado vs integración AS2K es exclusivamente del usuario.

**Commander:** en esta intervención «siguiente» se efectuaron dos llamadas de ejecución dirigidas (copiar dos PNG preexistentes a Drive y una corrida AP-03). No se hicieron inventarios, polling ni reparaciones sobre la T; cualquier nueva intervención sigue sujeta a autorización.
