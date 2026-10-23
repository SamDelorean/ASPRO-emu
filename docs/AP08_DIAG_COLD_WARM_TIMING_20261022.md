# AP-08 — ASPRO-DIAG: tiempos de arranque y respuesta a tecla A

**Fecha:** 22-oct-2026. **Equipo:** T640 canónica (Linux x86_64).
**Ámbito:** ejecución de ASPRO-DIAG ya existente; no GTK ni ASPRO Stable.

## Método

- Dos procesos MAME independientes (arranque **cold** sin NVRAM, luego **warm** reutilizando la NVRAM generada en el primer ciclo).
- `asprodiag` existente y verificado contra su archivo local `.aspro-binary.json`. No se compiló, modificó ni sustituyó ningún ejecutable.
- Firmware AlphaSmart Pro 2.1.2 y CGROM KS0066 F05 privados: identidad validada por tamaño y SHA1 antes de ejecutar. Se eliminaron las copias de staging al terminar. No se versionó contenido privado.
- Parámetros principales: sistema `asmapro`, `-noreadconfig`, `-video none`, `-sound none`, `-nothrottle`, `-seconds_to_run 12`. Cada fase usó configuración aislada, compartiendo solo la NVRAM temporal de la campaña.
- Observador Lua temporal: `COL.14` bit `0x10`, frame 400 (8 segundos emulados) antes de pulsar, frame 420 A DOWN, frame 440 A UP, frame 530 comparación del LCD, frame 560 fin de observación. Se midió tiempo real mediante Python monotónico y muestreo de archivo de eventos (aproximación con resolución de muestreo de unos 50 ms).

## Mediciones reales

| Indicador | Cold | Warm |
|---|---:|---:|
| Tiempo total de proceso incluyendo monitoreo Python | **0.555 s** | **0.504 s** |
| Frame 400 (~8 s emulados), tiempo real desde lanzamiento | 0.403 s | 0.403 s |
| A DOWN (~8.4 s emulados), tiempo real | 0.454 s | 0.403 s |
| Frame 530 (~10.6 s emulados), tiempo real | 0.504 s | 0.453 s |
| Píxeles del LCD modificados tras pulsar A | 24 | 24 |
| Rectángulo modificado | x0–10, y2–7 | x6–16, y2–7 |
| A DOWN / A UP / OBSERVATION_COMPLETE | PASS | PASS |
| NVRAM de 131072 bytes | PASS | PASS |
| Código de salida | 0 | 0 |

**Resultado:** `ASPRO_AP08_BOUNDED_DIAG_TIMING_PASS`, salida de la tarea 0.

El desplazamiento de la caja de cambios de x0–10 a x6–16 es coherente con un cursor que avanza y una nueva pulsación A en la segunda ejecución. **No equivale a OCR ni identifica por sí solo el carácter.** El PASS visual anterior de la letra `a` se documenta en AP-03.

## Interpretación y límites

La referencia DIAG alcanza 8 segundos emulados en aproximadamente 0.4 segundos reales sobre T640 sin limitación de velocidad. El arranque con NVRAM preexistente es ligeramente más rápido para 12 segundos emulados, pero la diferencia de 0.051 s es demasiado pequeña para atribuir un comportamiento distinto al firmware sin repeticiones. Esta prueba demuestra que no se reproduce en este entorno la lentitud notificada para ASPRO Stable.

**No mide** la experiencia GTK en VONTAR o Surf, ni es una comparación cronométrica directa con los procesadores ARM. La implementación Stable sigue teniendo dos trabajos pendientes: compilar y verificar el mapa virtual Pro corregido y evaluar/optimizar el renderizado GTK. No reabrir HC11, bootstrap o ROM sin evidencia adicional.

## Evidencia y preservación

- Salida T640: `DIAG_COLD_OBSERVED`, `DIAG_WARM_OBSERVED`, `ASPRO_AP08_BOUNDED_DIAG_TIMING_PASS`, `PRIVATE_ROM_STAGING_REMOVED`; proceso completado con código 0.
- Informe y registros en el árbol privado local ASPRO:
  `~/Projects/alphasmart/ASPRO-emu/private/ap08_timing/diag_timing_lz6rk5lr/report.json`.
- **Commander:** 2 llamadas T640 (lanzamiento y lectura final), límite de 3 no agotado. No se usó Commander para ASPRO Stable, Surf o VONTAR.
- Sin recompilación, cambios al ejecutable o a la NVRAM de trabajo del usuario. Las imágenes ROM/CGROM temporales fueron eliminadas; la RAM de prueba continúa en la carpeta privada de AP-08.

**Estado:** DIAG_COLD_WARM_TIMING_PASS; STABLE_ARM_GUI_PERFORMANCE_NOT_MEASURED; STABLE_KEYBOARD_RUNTIME_PENDING.
