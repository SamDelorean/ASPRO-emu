# AP-01 — Evidencia estática de las imágenes

## ROM AlphaSmart Pro

- Archivo privado: `alphasmartpro212.rom` (Drive, subcarpeta asmapro).
- Longitud: 32768 bytes.
- SHA-256: `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`.
- SHA-1: `c3c6a421c9ced92db97431d04b4a3f09a39de716`.
- CRC32: `896ddf1c`.
- Referencia coincidente en `src/mame/skeleton/alphasma.cpp`: `ROM_START(asmapro)`.
- Vector RESET `$FFFE→$C000`; bytes `$C000: 8E 00 FF` = `LDS #$00FF`.
- Vectores distintos del handler genérico: `$FFF2→$C822`, `$FFF4→$C82B`, `$FFF8→$C83F`; mayoría restantes apuntan a `$C835`. La clasificación por tipo de interrupción se realizará usando la definición HC11D0, no con suposiciones.
- Se verificó que la región ROM física cubre 32 KiB, pero la decodificación MMIO superpuesta de Pro requiere la fuente del driver existente.

## Carácter LCD KS0066 F05

- Imagen privada de Drive: `ks0066/ks0066_f05.bin` 4096 bytes.
- SHA-1: `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- CRC32: `af9e7bd6`.
- Coincide con `ROM_START(ks0066)` de `src/devices/video/hd44780.cpp` del árbol MAME.
- Está seleccionada por el driver Pro con `set_default_bios_tag("f05")`. El runner exige esta ROM, la prepara en `ks0066.zip` aislado y la elimina tras ejecutar. No comprometerla en Git.

## Intel HEX auxiliar

- `AlphaSmart001.HEX` no pertenece al romset MAME asmapro según el driver.
- 23053 bytes de archivo textual, 512 registros de datos y 1 EOF, checksums Intel HEX correctos.
- 8192 bytes de datos efectivos, ventana `$0000–$1FFF`.
- Primeros bytes `8E 00 FF BD...` reflejan también instrucciones HC11, pero ello no prueba que sea la misma versión ni imagen. Mantener fuera de arranque.

## Hardware ya implementado en código público

- CPU `MC68HC11D0(..., 8_MHz_XTAL)`.
- Dos `KS0066(...)`, `set_lcd_size(2,40)` cada uno, visualización 240×36 combinada.
- 16 entradas `COL.0–COL.15`, interrupción IRQ por transiciones.
- 4 bancos × 0x8000 bytes de NVRAM externa.
- `$8000` lectura teclado y escritura columna alta; `$C000` escritura columna baja; ROM superpuesta al leer.
- LCD controlado por flancos de puerto A, datos de 4 bits por puerto D y control de matriz.
- Driver original mantiene bandera `MACHINE_NOT_WORKING`. No declarar PASS por el código o por coincidencia de hashes.

## Prueba y límites

Se inspeccionaron archivos en Drive y contenido de ROM localmente, sin Commander ni ejecución de emulador. Los scripts AP-01 requieren un entorno Python/MAME real para demostrar su ejecución. Las pruebas de firmware pendientes deben ejecutarse **solo en ASPRO-DIAG**, nunca en stable.
