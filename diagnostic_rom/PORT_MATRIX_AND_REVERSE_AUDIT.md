# ASPRO-DIAG-ROM — auditoría inversa inicial y matriz de portabilidad (2026-10-21)

## 1. Evidencia preexistente que NO se repite

| Evidencia ASPRO-DIAG | Fuente | Estado heredado (no nueva prueba) |
|---|---|---|
| Arranque ROM Pro 2.1.2 + LCD + tecla A | `docs/AP03_FUNCTIONAL_EVIDENCE.md` | `AP03_PASS` |
| F1–F8 / 128 KiB NVRAM en cuatro bancos | `docs/AP04_FILES_NVRAM_FUNCTIONAL_EVIDENCE.md` | `AP04_PASS` |
| Conexión PC/Send a TXT | `docs/AP06_PC_SEND_TXT.md` | `AP06_PASS` |
| Bootstrap especial D0; FF + SCI RX 121/121 + 122 ecos; PC=$0040; BOOT OK | `docs/AP07_FUNCTIONAL_PASS_20261020.md` | `AP07_PASS`, *modelo SCI MAME, no instrucciones ROM silicio* |
| Port de pruebas HC11 L2 a Pro | No se ha ejecutado | `NOT_PORTED` |

**Precisión:** el Pro mostró `BOOT OK` mediante el payload original `src/payload0_pro.asm`, 121 B, SHA-256 `25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`. Esto prueba bootstrap + LCD del Pro dentro del límite de ese ensayo, **no** monitor residente ni diagnóstico de componentes.

## 2. Auditoría directa de ROM privada 2.1.2, sin publicar firmware

Archivo recibido desde Drive: `ASPRO/asmapro/alphasmartpro212.rom`. Solo se registran atributos derivados:

| Propiedad | Resultado observado |
|---|---|
| Longitud | 32768 B |
| SHA-1 | `c3c6a421c9ced92db97431d04b4a3f09a39de716` |
| SHA-256 | `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e` |
| CRC32 global | `896ddf1c` |
| ROM CPU mapeada | $8000–$FFFF según driver Pro |
| ROM de archivo, primeros 8 KiB ($8000–$9FFF) | **8192 bytes constantes 0x01**, CRC32 `4cb181fe` |
| Segundo bloque 8 KiB ($A000–$BFFF) | **8192 bytes constantes 0x01**, CRC32 `4cb181fe` |
| Tercer bloque ($C000–$DFFF) | datos variables, CRC32 `133520e8` |
| Cuarto bloque ($E000–$FFFF) | datos variables, CRC32 `245b3004` |
| Vector RESET | $FFFE->$C000; primera instrucción $C000: LDS #$00FF (confirmación previa del mapa) |
| Cadenas verificadas en imagen | `Attached to Mac, emulating keyboard.` en $F8EC, PC en $F911, `Sending....` en $F956 |
| Diferencia de documento heredado | La secuencia literal `Low Battery!!` aparece en **$F53F** según el binario; AP-05 la listaba en $F532. Reconciliar anchura/cadena antes de usar su dirección como oráculo |

**Interpretación acotada:** 16 KiB iniciales del **archivo** son relleno 0x01; no se demuestra que el circuito físico replique ese relleno ni que existan bancos de ROM. Para L2.5 no emplear firmas de AS2K ni asumir ZPSD. El primer oráculo seguro de la ROM conocida Pro puede construirse desde regiones $C000–$FFFF, con lectura externa real, firma por versión y tolerancia a revisiones no reconocidas. Ningún test debe escribir sobre ROM ni SRAM sin restauración.

## 3. Matriz mínima de traducción por contratos (sin copiar hardware AS2K)

| Etapa AS2K | Contrato lógico reusable | Pro: delta mínimo requerido | Calidad actual |
|---|---|---|---|
| L0, L1 / D0 | RESET/MODA/MODB, bootstrap 7812.5 baud, eco, entrada $0040 | Usar motor AP07 existente y D0P; calibrar timing real aparte | Bootstrap emulado AP07 PASS, producto Pro DIAG no integrado |
| BDS 0.1 | Trama A5,01,TEST_ID,STATUS,SUBCODE,DH,DL,XOR, 8 B | Invariante HC11; test específico y oráculo Pro | Reuso documental, sin prueba de recepción Pro |
| Monitor | LOAD 1..80 + XOR, overlay JSR/RTS y READY, sin RESET | Auditar SRAM interna y stack Pro D0; conservar ventana propuesta $0040–$008F, monitor $0090–$00EB, state $00EC–$00EF, stack $00F0–$00FF **solo si se demuestra compatibilidad** | Estudio de espacio AS2K, no PASS Pro |
| L2.0 | Overlay A-B-C-B-A, estabilidad | Reusar las mismas pruebas si no tocan MMIO de placa; no alterar payloads sin divergencia medida | Revisión byte-level pendiente |
| L2.0B | Bus externo / E/RW/AS y decode | Identificar select externos y señales Pro por driver/PCB/Ghidra; no copiar control AS2K | Investigación dirigida |
| L2.1 / L2.2 | Patrones acotados de datos y alias de direcciones; save/restore | Adaptar ventanas RAM Pro y direcciones accesibles, oráculo de bus del Pro | Port mínimo pendiente |
| L2.3 | RAM rápida no destructiva, verificación restauración | 128 KiB y cuatro bancos; evitar destruir archivos almacenados | Banco y ventana conocida; prueba pendiente |
| L2.4 | Aislamiento de bancos | Pro: `((PA>>3)&1)|((PA>>4)&2)`; atención PA5 también pulsa LCD1 | Contrato de driver, ensayo pendiente |
| L2.5 | Lectura/firma ROM stock | ROM Pro 2.1.2 SHA fijado, contenido relevante $C000–$FFFF; versión desconocida = no reconocida, no daño | Oráculo de imagen derivado, prueba en bus pendiente |
| L2.6 | AS2K distingue ZPSD/Chip Z | **NO EXISTE base para trasladar ZPSD**; reemplazar por clasificación Pro de ROM/decodificación externa SOLO si evidencia | Exclusión explícita |
| L3 y boot normal | Pruebas teclado/batería/LED y cierre | Teclado Pro 16 columnas, dos LCD KS0066, conectores PC/Mac distintos; reutilizar control ASPRO AP03/04/06 | Plataforma funcional demostrada, tests de fallas nuevos pendientes |
| Arduino/probe | Secuencia, códigos, stop-on-first, pantalla independiente | Reusar semántica de controlador AS2K; mantener firmware/exposición de producto Pro separado | Diseño común reusado, no producto portado |

## 4. Invariantes y límites

1. Un solo simulador autorizado: **`asprodiag` / ASPRO-DIAG**. Nunca probar en ASPRO-STABLE, `asma2k` genérico ni crear un segundo emulador. No modificar el checkout AS2K.
2. **STATIC_FIRST** y no repetir los PASS AP03/04/06/07. Cada incremento integral cubre investigación -> diferencias -> código -> pruebas apropiadas -> evidencia, sin fragmentación artificial.
3. Todos los comandos de CPU y memoria quedan anclados en el MC68HC11D0P y su mapa. La ZPSD del 2000 y las direcciones LCDCFG $2000 / CTRL $4000 de AS2K son incompatibles con Pro. PORTD PD5..PD2 controla nibbles LCD Pro; PA7 E0, PA5 E1, $8000 bit1 RS; **PA5 también afecta selección RAM** según driver.
4. Sólo se declara `PASS` de nueva función con binarios, hashes, trazas/lcd y oráculo; documentación o fixtures no equivalen a prueba dinámica. El software de diagnóstico no se incorpora a stable por anticipado.
5. Si la SRAM o sus bancos son el objeto de prueba, código/stack/monitor viven en RAM **interna**, nunca en SRAM externa; salvar/restaurar byte por byte y verificar restauración.
6. Los límites y condiciones de la ROM Pro privada no se extrapolan a todas las revisiones de AlphaSmart Pro.

## 5. Ghidra y evidencias que faltan (no inventar resultados)

Ghidra del AS2K está localizado en Drive, pero no se ha demostrado aún un proyecto Ghidra **ASPRO 2.1.2 fijado a su SHA**. Hay un listado tercero `AlphaSmart001-20230301b.lst.txt` y un `AlphaSmart001.HEX` en la carpeta Pro; sin comprobar que su binario sea la misma versión **no usar nombres de funciones ni saltos del listado como verdades para ROM 2.1.2**.

Investigar de forma prioritaria y agrupada en **Ghidra Pro**:
- RESET $C000, vectores $FFE0–$FFFF y registro/configuración PA/PD, controles RAM y ROM.
- Banco PA3/PA5; separación acceso a RAM y pulso LCD1; señales seguras para prueba.
- Tabla ROM por versión y ubicación de la zona activa $C000–$FFFF; leer en $8000/$A000 con oráculo no dependiente de material de relleno.
- Rutinas de bootstrap Pro y entrada a $0040, delimitación entre RAM interna y externa y pila.
- Originalidad / revisión de `AlphaSmart001.HEX` y listado previo a tomar símbolos; procedencia.

Las observaciones Ghidra faltantes no impiden comenzar el port **de contratos de transporte/BDS/monitor** ya demostrados. Los experimentos requieren autorización y jamás se declaran ejecutados sobre la base de esta matriz.

## 6. Revisión exhaustiva con un solo incremento técnico

Aprobar como bloque integrado: (A) calificar reuso literal o delta de **11 imágenes AS2K (934 B)** sin cambios automáticos; (B) ensamblar/parametrizar monitor y overlay para mapa D0 Pro, con ABI/protección de stack; (C) ejecutar una campaña única y dirigida `asprodiag` de BDS/overlay A-B-C-B-A y ROM/RAM por etapas; (D) tomar mapas/evidencias Ghidra, clasificar huecos reales; (E) cerrar port con evidencia en Drive y celdas del Excel rector. La ejecución MAME o Commander requiere la autorización aplicable; no usar la falta de una herramienta como razón para reiniciar investigaciones ya cerradas.
