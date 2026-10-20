# AlphaSmart Pro 2.1.2 — mapa inicial verificado

**Fuentes:** ROM `alphasmartpro212.rom` de Drive; fotografía original de placa; driver BSD-3 `src/mame/skeleton/alphasma.cpp` en SamDelorean/mame-as3k, commit `c4e48388ca620472643110db2941ce70aa5f3c07`.

| Propiedad | Evidencia |
| --- | --- |
| ROM | 32768 bytes, SHA1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`, SHA256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`, CRC32 `896ddf1c` |
| Memoria ROM | `$8000–$FFFF` (de driver); datos en archivo de 32 KiB |
| RESET | Vector en `$FFFE` → `$C000` |
| Primera instrucción | `$C000: LDS #$00FF` (bytes `8E 00 FF`) |
| RAM | 128 KiB persistente, 4 bancos × 32 KiB |
| Ventana RAM | `$0000–$7FFF`, según driver (registros HC11 internos por dispositivo CPU) |
| Banco | puerto A: `((PA>>3)&1) | ((PA>>4)&2)`, valores 0–3 |
| CPU | MC68HC11D0P, 8 MHz documentados en driver |
| Teclado | Matriz 16 columnas, active-low; IRQ en transición; `$8000` lectura/columna alta, `$C000` columna baja |
| LCD | 2 × KS0066F05 + 8 × HD44100H en Pro, 40×4; salida de 240×36 píxeles |
| LCD I/O | Dos dispositivos KS0066, datos 4 bit por puerto D; control vía matriz alta y flancos de puerto A |
| NVRAM | Batería de respaldo en placa; no se obliga a borrar memoria al reiniciar |
| Comunicación PC/Mac | **Puertos físicos confirmados:** PC AT/PS2 y Macintosh/IIGS ADB. Firmware ROM 2.1.2 contiene modos attached, Send y velocidad de transferencia; **no hay host/periférico ADB/PS2 en driver**, queda por implementar. Ver [AP-05](AP05_PERIPHERAL_HARDWARE_AUDIT.md). |
| Infrarrojos IR/IrDA | **No documentados para Pro stock**; módulo IR opcional citado específicamente para AS2K/AS3K, no transferir al Pro. |
| Alimentación y respaldo | 2 AA, pack NiCad opcional, DC externo, CR2032 SRAM, batería baja por PA1. Driver sólo modela NVRAM y Normal/Low; no electrónica de carga/retención. |
| Interfaces sin evidencia Pro | USB, RS-232 físico, impresora directa, buzzer: no añadir por analogía con otras generaciones. |

### Distinciones y precauciones
- No atribuir PDIUSBD11D/ISP1161ABD del documento `specs` a la revisión Pro sin evidencia visual: pueden proceder de otra generación.
- El driver MAME declara `MACHINE_NOT_WORKING` (en ambos modelos); por tanto, el código heredado aún **no** es prueba de que el firmware arranque.
- `AlphaSmart001.HEX` ocupa rango distinto y **no** es ROM sustituta de Pro. Analizar por separado con `rom_audit.py`.
- Registros MMIO de HC11, retardos LCD, semántica de IRQ y NVRAM requieren comprobación dirigida en ASPRO-DIAG, no ensayo especulativo.
- La dirección `$C000` se usa tanto como instrucción ROM al leer como para escribir selección de teclado. El driver ya contempla esta diferencia por tipo de acceso.
