# AP-07 — Bootstrap auténtico del AlphaSmart Pro (MC68HC11D0P)

**Fecha:** 2026-10-20. **Estado:** `DATASHEET_CONTRACT_RECORDED / BOUNDED_PAYLOAD_VALIDATOR_IMPLEMENTED / STATIC_TEST_PENDING / SCI_AND_CPU_INTEGRATION_PENDING`.

**Objetivo autorizado por el usuario:** incorporar la capacidad de *special bootstrap* **específica del D0P** del AlphaSmart Pro, fundada en la hoja de datos y en el funcionamiento real del boot ROM HC11Dx. No heredar el arranque ZPSD/DictROM de AS2K ni sustituir el protocolo SCI con una copia directa de SRAM presentada como transferencia auténtica. Sólo ASPRO-DIAG puede hacer las pruebas; AS2K, ASPRO normal sin bootstrap y el MAME canónico permanecen intactos.

## Fuentes primarias y discriminación de variantes

1. [Motorola/Freescale, MC68HC11D3 Technical Data, sección 4.1.4, tabla 4-2, `HPRIO`](https://www.nxp.com/docs/en/data-sheet/MC68HC11D3.pdf). Incluye las características HC11 Dx de las que deriva el HC11D0, y arranque ROM/SCI.
2. [Freescale, MC68HC711D3/MC68HC11D3/MC68HC11D0 datasheet, revisión 2.1, apéndice A](https://www.nxp.com/docs/en/data-sheet/MC68HC711D3.pdf). D0 **no tiene ROM principal interna de usuario** (`0 bytes on-chip ROM`), pero tiene RAM interna y modo bootstrap. El D0 sólo funciona en modo **expanded multiplexed** y **special bootstrap**; no suponer single-chip normal utilizable en D0.
3. [Motorola, MC68HC11D3 Technical Data, figura 2-2 y apéndice B, variante DIP40](https://static.datasheets.com/doc/25302592-motorola-mc68hc11d0cfn3r2-ds.pdf). En el encapsulado 40-pin del Pro: `RESET=13`, `PD0/RxD=15`, `PD1/TxD=16`, `MODB/VSTBY=36`, `MODA/LIR=37`; PA4/PA6 no están conectados externamente en DIP40. El sufijo P corresponde a variante de montaje DIP40 en las referencias de dispositivo; no usar pinout PLCC44 ni mezclar señales del D0FN del AS2K.
4. [Freescale AN1060, M68HC11 Bootstrap Mode, Rev. 1.1, tabla 2](https://www.nxp.jp/docs/en/application-note/AN1060.pdf): rama D3/711D3 de boot ROM `0–192` bytes a `$0040–$00FF`, sincronización SCI por `$FF`, duración inactiva de cuatro caracteres. La tabla documenta un salto especial del D3 a ROM interna `$F000` ante `$00`; **NO trasladar ese salto como ROM interna al D0**, que no dispone de ella.

**Identidad del equipo dentro de este repositorio**: driver Pro `src/mame/skeleton/alphasma.cpp` anota `MC68HC11D0P`, cristal 8 MHz, CPU MAME `MC68HC11D0(config,...)`; firmware externo `alphasmartpro212.rom` de 32 KiB con mapa `$8000–$FFFF` y RESET `$FFFE->$C000` en arranque ordinario. El modo bootstrap por RESET es **distinto**: reset vector y loader de ROM **especial** `$BFxx`, no ejecución directa de ROM principal del Pro.

## Contrato de hardware AP-07

| Campo | Valor que debe modelarse |
| --- | --- |
| Selección en reset | `MODB=0`, `MODA=0` únicamente si se solicita bootstrap |
| HPRIO esperado al entrar | `RBOOT=1,SMOD=1,MDA=0` → bits `$C0` |
| ROM especial de loader | `$BF40–$BFFF` (192 bytes) y vectores en la zona especial `$BFxx` |
| RAM interna HC11D0 | `$0040–$00FF` = 192 bytes, cargada sin invadir registros `$0000–$003F` |
| Entrada/eco SCI | `PD0/RxD` → `PD1/TxD`, nivel eléctrico abierto según `DWOM` y resistencia pull-up de la hoja |
| Sincronización | primer byte SCI `$FF`; selección de velocidad del boot ROM |
| Descarga de programa | entre 1 y 192 bytes de código para la política DIAG; el hardware también describe descarga de 0 bytes, pero ejecutar RAM no inicializada queda excluido aquí |
| Terminación | tras recibir 192 bytes, o inactividad de al menos 4 caracteres |
| Transferencia completa | echo/verificación, RAM exacta, PC=$0040 e inicio de código HC11 realmente ejecutado |
| E y baud | reloj XTAL de 8 MHz → `E=2 MHz`; AN1060 documenta nominalmente `7812` y `1200` baudios para familias compatibles. Usar el detalle exacto del D3/D0, no generalizar a otras 68HC11 |

**Protección de alcance:** ningún payload de Pro admite más de 192 bytes ni origen fuera de `$0040`; los mecanismos de banco SRAM externa del equipo, fichero ROM, LCD, teclado, Send y NVRAM **no se recablean**. No invocar o compilar el MAME/AS2K de referencia. No interpretar `RBOOT=1` como autorización para incluir el bytecode propietario de la ROM de bootstrap en el repositorio.

## Reutilización comprobada y diferencia pendiente real

En `SamDelorean/AS2K-Emulator` existe `scripts/patch-mc68hc11-bootstrap.py` (licencia BSD-3) que implementa **de forma acotada** `mc68hc11d0_device::diag_bootstrap_load`, HPRIO y una entrada a código en RAM con `PC=$0040`. Ese código se estudia/reutiliza **solo** para la etapa posterior a una descarga válida porque aplica al mismo silicio HC11D0, **no** por identidad de firmware, ROM externa ni pinout del Pro. Se revisará el SHA y las precondiciones de su CPU parcheada antes de llevar el adaptador a la copia independiente `ASPRO-emu/build/send-mame`.

**Brecha confirmada en el MAME donante fijado:** `src/devices/cpu/mc68hc11/mc68hc11.cpp` del commit `c4e48388ca620472643110db2941ce70aa5f3c07` define `SCCR1/SCCR2` principalmente como lecturas, y `SCDR` `nopw`; todavía **no implementa la recepción/eco SCI completa** del boot ROM. Una mera inyección de bytes a RAM saltaría la secuencia `$FF` → recepción SCI → eco → idle y **no puede recibir PASS de bootstrap auténtico**.

La implementación deberá contemplar dos piezas separadas, sin alterar el arranque normal:

1. **Contrato y transferencia:** entrada especial de RESET opt-in, velocidad/sincronización, memoria `$0040–$00FF`, eco SCI, finalización exacta y errores de sobrelongitud; producir marcador de transición propio. Si se reutiliza el cargador CPU diagnóstico como síntesis del resultado final, declarar explícitamente `POST_SCI_BOOTSTRAP_INJECTION`, no `AUTHENTIC_SCI_PASS`.
2. **Ejecución DIAG:** habilitar HPRIO/RBOOT/SMOD propios del D0 y pasar al PC de RAM `$0040` sólo al consumarse la descarga. Ejecutar un **programa sintético HC11 de 2–8 bytes**, preparado fuera de ROM propietaria, comprobar efecto en RAM y mostrar evidencia de PC/estado e invariancia del arranque normal Pro. Probar límites 1/192/193 bytes y rearme por RESET. En pruebas sólo `asprodiag`, nunca `asma2k`, stable ni MAME genérico.

No crear ninguna imagen obligatoria de 192 bytes (la duración es variable); no aceptar un 0-byte vacío como programa listo; el byte de sincronización `$FF` no cuenta entre los 192 bytes cargados.

## Artefactos implementados ahora

- [`tools/ap07_d0_bootstrap_contract.py`](../tools/ap07_d0_bootstrap_contract.py): carga un archivo local privado de 1–192 bytes, establece `$0040..`, valida límite, registra SHA-256 y contrato en JSON **sin publicar bytes ni declarar ejecución**.
- [`tools/ap07_static_selftest.py`](../tools/ap07_static_selftest.py): tests de límites y de conservación de arranque normal/Send. Sin usar Commander, ROM ni ejecutable MAME.
- Esta especificación conserva vínculo a las fuentes primarias. No se ha creado aún un código fuente CPU de bootstrap Pro ni recompilado MAME; `STATIC_IMPLEMENTATION_PREPARED / BOOTSTRAP_RUNTIME_PENDING`.

## Política anti-gate y secuencia inmediata

Un incremento coherente AP-07, sin repetir AP-02–AP-06: adaptación acotada a CPU D0 + receptor de transporte SCI + una prueba dirigida `asprodiag` con firmware Pro privado aislado, tal como está documentado. Compilación incremental `-j3` sólo en el árbol independiente ASPRO, restauración ante fallo, evidencias SHA y logs en Drive privado. Commander requiere la intervención autorizada, no dedicar llamadas a inventarios ni polling.
