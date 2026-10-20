# ASPRO-emu

Emulador reducido de AlphaSmart Pro basado en **MAME 0.289 y el driver existente `src/mame/skeleton/alphasma.cpp`**. **Único entorno de desarrollo ASPRO-emu; AS2K es referencia de código en sólo lectura y no se usa para compilar el Pro.** El trabajo continúa el flujo técnico del emulador AS2K, sin reconstruir una CPU, LCD o matriz de teclado ya implementados.

**Decisión arquitectónica (19-oct-2026):** desarrollar y validar primero ASPRO-DIAG como variante independiente. NO incorporar Pro a AS2K ni crear producto público estable durante esta etapa. Al terminar la calificación funcional de DIAG, el usuario decidirá entre ampliar AS2K o conservar ASPRO separado. No anticipar ni automatizar esa decisión.

**Único entorno autorizado para pruebas:** `ASPRO-DIAG` (`asprodiag`). Una eventual versión estable dependerá de la decisión posterior del usuario y nunca se utilizará como banco de pruebas.

## Estado funcional — 20-oct-2026

**AP-02 a AP-04: PASS funcional emulado acotado.** Se reutilizó el motor MAME-DIAG de AS2K como una copia ASPRO independiente (sin recompilación ni modificaciones a AS2K). ROM Pro 2.1.2: arranque y LCD/teclado básicos PASS visual (AP-03); ocho archivos F1–F8 con caracteres `a`–`h` diferenciados y recuperación idéntica después de salir y volver a iniciar la emulación compartiendo exclusivamente su NVRAM privada (AP-04). [Evidencias AP-04](docs/AP04_FILES_NVRAM_FUNCTIONAL_EVIDENCE.md).

La clasificación automática de `run_diag.py` permanece conservadora (`functional_pass:false`) porque no interpreta el texto LCD: el PASS calificado aquí procede de capturas reales inspeccionadas y hashes de ocho parejas write/verify. No valida hardware físico, otras funciones de Writer, impresión ni todas las modalidades del firmware. ASPRO-STABLE/integración AS2K siguen sujetos a decisión del usuario.

## Resultados disponibles

- Firmware principal: AlphaSmart Pro 2.1.2, 32 KiB, SHA-1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`; datos **privados fuera de Git**.
- LCD externo: KS0066 F05 CGROM de 4096 bytes localizada en Drive, SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51` (necesaria para arranque fiel; privada).
- Reutilización: MAME ya proporciona CPU MC68HC11D0, 2 × KS0066 (LCD 40×4), matriz de teclado 16 columnas, 128 KiB NVRAM y mapa Pro.
- Archivo de origen recuperado: [SamDelorean/mame-as3k, `src/mame/skeleton/alphasma.cpp`](https://github.com/SamDelorean/mame-as3k/blob/c4e48388ca620472643110db2941ce70aa5f3c07/src/mame/skeleton/alphasma.cpp).
- Estado AP-02: **STATIC_PASS / COMPILE_PENDING / DYNAMIC_PENDING**. Preparación integral y pruebas sintéticas completas; ningún arranque HC11 ni PASS funcional reclamado. Véase [ejecución y resultados](docs/AP02_EXECUTION_AND_RESULTS.md).

## Uso (sin alterar el MAME canónico)

```bash
python3 tools/rom_audit.py --rom /ruta/privada/alphasmartpro212.rom --json
python3 tools/prepare_mame.py --source /ruta/verificada/referencia-Git-MAME
bash tools/build_diag.sh build/mame 2
python3 tools/run_diag.py --rom /ruta/privada/alphasmartpro212.rom --lcd-rom /ruta/privada/ks0066_f05.bin --bin build/mame/asprodiag --seconds 8 --capture auto
python3 tools/static_selftest.py
```

La construcción reducida requiere una exportación propia verificada en **ASPRO-emu/build/mame**, nunca el árbol AS2K. `prepare_mame.py` exporta el commit fijado desde objetos Git de una referencia local en sólo lectura, sin copiar sus cachés ni archivos privados; `build_diag.sh` rechaza destinos ajenos o sin identidad. No se descargan ni reinstalan toolchains. La construcción reducida usa `make SUBTARGET=asprodiag SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1` del propio MAME; evita volver a importar o modificar su código, y utiliza el mismo driver del que ya procede el AS2K. Solo crea resultados de compilación de subtarget. Para reducir aún más el binario a **un único sistema Pro**, se podrá aplicar `SOURCEFILTER` del MAME **solo después de comprobar su contrato**; no sustituir la primera ejecución por esa optimización.

El runner prepara un `asmapro.zip` temporal con la ROM original, de uso local exclusivamente, y genera logs y estado en un directorio de diagnóstico separado. La ROM nunca se versiona, no se imprime y no se altera.

**Los scripts no llaman Commander.** `tools/ap02_run_once.sh` agrupa preparación, compilación y ejecución auténtica cuando el usuario autorice la intervención T640 y estén disponibles sus insumos privados; invocarlo sí ejecuta DIAG. Véase la instrucción única en [AP-02](docs/AP02_EXECUTION_AND_RESULTS.md). Ningún log, ROM, NVRAM, estado o captura privada se debe publicar en Git.

Véase [plan](docs/MASTER_PLAN.md), [mapa](docs/ROM_HARDWARE_MAP.md), [procedencia](docs/SOURCE_PROVENANCE.md) y [continuidad](docs/HANDOFF.md).
