# ASPRO-emu

Emulador reducido de AlphaSmart Pro basado en **MAME 0.289 y el driver existente `src/mame/skeleton/alphasma.cpp`**. El trabajo continúa el flujo técnico del emulador AS2K, sin reconstruir una CPU, LCD o matriz de teclado ya implementados.

**Decisión arquitectónica (19-oct-2026):** desarrollar y validar primero ASPRO-DIAG como variante independiente. NO incorporar Pro a AS2K ni crear producto público estable durante esta etapa. Al terminar la calificación funcional de DIAG, el usuario decidirá entre ampliar AS2K o conservar ASPRO separado. No anticipar ni automatizar esa decisión.

**Único entorno autorizado para pruebas:** `ASPRO-DIAG` (`asprodiag`). Una eventual versión estable dependerá de la decisión posterior del usuario y nunca se utilizará como banco de pruebas.

## Resultados disponibles

- Firmware principal: AlphaSmart Pro 2.1.2, 32 KiB, SHA-1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`; datos **privados fuera de Git**.
- LCD externo: KS0066 F05 CGROM de 4096 bytes localizada en Drive, SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51` (necesaria para arranque fiel; privada).
- Reutilización: MAME ya proporciona CPU MC68HC11D0, 2 × KS0066 (LCD 40×4), matriz de teclado 16 columnas, 128 KiB NVRAM y mapa Pro.
- Archivo de origen recuperado: [SamDelorean/mame-as3k, `src/mame/skeleton/alphasma.cpp`](https://github.com/SamDelorean/mame-as3k/blob/c4e48388ca620472643110db2941ce70aa5f3c07/src/mame/skeleton/alphasma.cpp).
- Estado: **implementación estática de runner, ROM audit y receta de subtarget**; ningún PASS dinámico reclamado.

## Uso (sin alterar el MAME canónico)

```bash
python3 tools/rom_audit.py --rom /ruta/privada/alphasmartpro212.rom --json
bash tools/build_diag.sh /ruta/al/arbol/MAME 2
python3 tools/run_diag.py --rom /ruta/privada/alphasmartpro212.rom --lcd-rom /ruta/privada/ks0066_f05.bin --bin /ruta/al/arbol/MAME/asprodiag --seconds 8
python3 tools/static_selftest.py
```

La construcción reducida usa `make SUBTARGET=asprodiag SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1` del propio MAME; evita volver a importar o modificar su código, y utiliza el mismo driver del que ya procede el AS2K. Solo crea resultados de compilación de subtarget. Para reducir aún más el binario a **un único sistema Pro**, se podrá aplicar `SOURCEFILTER` del MAME **solo después de comprobar su contrato**; no sustituir la primera ejecución por esa optimización.

El runner prepara un `asmapro.zip` temporal con la ROM original, de uso local exclusivamente, y genera logs y estado en un directorio de diagnóstico separado. La ROM nunca se versiona, no se imprime y no se altera.

**Los scripts NO llaman Commander ni ejecutan pruebas por sí mismos en este repositorio.** Su empleo en T640 requiere la autorización propia de cada intervención.

Véase [plan](docs/MASTER_PLAN.md), [mapa](docs/ROM_HARDWARE_MAP.md), [procedencia](docs/SOURCE_PROVENANCE.md) y [continuidad](docs/HANDOFF.md).
