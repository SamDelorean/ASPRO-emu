# ASPRO-DIAG-ROM — HANDOFF CANÓNICO — 2026-10-21

## 0. Solicitud vigente
Crear vertiente ROM de diagnóstico **AlphaSmart Pro** aprovechando **al máximo** la infraestructura ya implementada para **AS2K**, con el mínimo de cambios y la menor cantidad de intervenciones. Comenzar con ingeniería inversa de diferencias restantes (Ghidra / emulador / hardware). **No reescribir ni repetir trabajo cerrado salvo necesidad demostrada**. Flujo, pruebas, directrices anti-gate y respaldos propios en Drive/Git. El usuario exige continuidad autónoma, con rector Excel actualizado tras cada incremento.

## 1. Activos canónicos creados para esta vertiente
- Git ASPRO independiente de AS2K: `SamDelorean/ASPRO-emu`, rama `codex/aspro-diag-rom-port-20261021`. La rama arranca de `main@26fe52709ac22e9210e4772e0c09f02e2526ec6b`.
- Código, portabilidad y auditoría: `diagnostic_rom/README.md`, `diagnostic_rom/PORT_MATRIX_AND_REVERSE_AUDIT.md`.
- Carpeta Drive privada y separada de stable: `ASPRO_DIAG_PRIVATE/ASPRO_DIAG_ROM`, ID `1Xpq-N-0KsK_0QHIssT7IksWVkz5CxpXO`, https://drive.google.com/drive/folders/1Xpq-N-0KsK_0QHIssT7IksWVkz5CxpXO
- **Excel rector propio**, siete hojas `Estado`, `Hitos y avance`, `Port AS2K a Pro`, `Ingeniería inversa`, `Pruebas`, `Fuentes y respaldos`, `Directrices`: ID `1wzolTxo3QXIvKaCuf9XjueuO-n8PkWLI`, https://docs.google.com/spreadsheets/d/1wzolTxo3QXIvKaCuf9XjueuO-n8PkWLI/edit
- Donante solo lectura `SamDelorean/AS2K-probe-tools@e3b3a3b41e541cf70c823c2a2c6d135ab48e2616`, contrato BDS, monitor, overlays, secuencia, pruebas y generación de imágenes; `SamDelorean/AS2K-DictROM-Takeover` solo si se necesita referencia de bootstrap. No modificar ninguno.
- Su homónimo emulador ASPRO ya existe, y su base no debe recrearse.
- Esta tarea **NO** crea otra suite de hardware ni otra placa Arduino. Reutiliza lógica/contratos establecidos; toda implementación física requiere decisión posterior.

## 2. Estados PASS heredados (no nuevas pruebas)
- AP03: ROM Pro arranca, LCD/editor/teclado.
- AP04: F1–F8 y 128 KiB NVRAM, persistencia.
- AP06: PC Send/TXT `abcabc`, conexión/desconexión.
- AP07: Special Bootstrap **modelo MAME-DIAG** D0P SCI $FF + 121/121 bytes + 122 ecos, RAM PC=$0040 y Payload-0-Pro de 121 B muestra `BOOT OK` en LCD; regresión arranque normal. Enlace: `docs/AP07_FUNCTIONAL_PASS_20261020.md`. **No** se ha ejecutado la ROM interna del silicio Motorola ni se ha probado aún un monitor/overlay Pro.
- AP07 binario `asprodiag` previamente compilado SHA256 `1437d66f8f3149f6cf3157df960ddeeb9616535586e75f062fbaf9ecc699a662`; referenciar, no reconstruir hasta que haya cambio real.

## 3. Ingeniería inversa completada ahora
ROM Pro 2.1.2 privada desde `Drive/asmapro/alphasmartpro212.rom`: 32768 B, SHA1 `c3c6a421c9ced92db97431d04b4a3f09a39de716`, SHA256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`, CRC32 `896ddf1c`.
- Los dos primeros bloques de 8192 B son **0x01 puro**, CRC32 `4cb181fe` cada uno. Bloques $C000–$DFFF y $E000–$FFFF variables, CRC32 `133520e8` y `245b3004`.
- Vector RESET $FFFE->$C000, `LDS #$00FF`; $F8EC cadena Mac attached, $F911 PC attached, $F956 Sending.
- La cadena literal `Low Battery!!` comienza $F53F; documento AP05 decía $F532: divergencia detectada sin silenciar, pendiente de cotejo.
- `AlphaSmart001.HEX` en carpeta ASPRO (fuente tercera) **NO coincide** con ROM Pro 2.1.2: Intel HEX válido 512×16=8192 B direccionados 0x0000–0x1FFF; SHA256 datos `0c62f7f97d9b9df9243f6782ad3f4d64b89d33d6468ac8d99cb2b2f5c9d5e093`. Coinciden solo 123/8192 B (1.5%) contra imagen Pro $C000–$DFFF. Por tanto **NO** asignar nombres y direcciones del listado 2023 a Pro 2.1.2. No se inventó proyecto Ghidra Pro.
- Fuentes fotos/libro de interconexiones y MAME driver ya registradas en `diagnostic_rom/PORT_MATRIX_AND_REVERSE_AUDIT.md`, con delta Pro LCD / bancos.

## 4. Diferencias que impiden port binario ciego
- Pro MC68HC11D0P 8 MHz, 32 KiB ROM externa y 128 KiB SRAM en 4×32 KiB; mapa ventana/ROM/IO distinto de AS2K.
- CPU PORTD PD5..PD2 para nibble LCD, PA7 E LCD0, PA5 E LCD1, matriz alta $8000 bit1 RS y PA5 también participa en banca SRAM. AS2K LCDCFG $2000/CTRL $4000, PA6/ZPSD/DictROM NO pertenecen a Pro.
- D0 MCU especial 192 bytes $0040–$00FF, pero el mapa teórico de monitor donante [80 overlay $0040–$008F / 92 monitor $0090–$00EB / 4 state $00EC–$00EF / 16 stack $00F0–$00FF] **NO ES PASS EN PRO**. Revisar el algoritmo sin alterar semántica.
- ROM Pro v2.1.2 usa zona variable $C000–$FFFF del archivo; NO clasificar Chip Z ni usar firma ROM AS2K.
- Pro tiene PS2/ADB y 40×4 con dos KS0066; no suponer puerto IR ni RS232 físico sin evidencia. Las pruebas LCD son ronda final.

## 5. Directrices duras
- **STATIC_FIRST**, reuso del código y contratos originales, incrementos amplios; no microgates administrativos, no repetir nada marcado PASS auténtico ni abrir proyectos paralelos.
- Solo **ASPRO-DIAG `asprodiag`** autorizado para ejecutar Pro; nunca ASPRO-STABLE, MAME genérico o `as2kdiag` contra Pro.
- Drive primero para documentos/artefactos privados, Git para código/procedimientos no secretos. Actualizar **el mismo Excel rector** al cerrar cada incremento. No crear hojas o libros alternos sin necesidad.
- Commander solo intervención **expresamente autorizada**, T640 canónica `dee0b4b6-578a-41a5-88de-73dbeb808983`, hasta tres llamadas por intervención, sin sondeo/polling/preflight repetido; no asumir que está disponible.
- Codex implementador puede emplearse cuando proceda y cualquier encargo debe incluir prompt íntegro, fuentes fijadas y resultados de pruebas; ChatGPT supervisor. No delegar pruebas al emulador stable.
- PASS necesita commit, SHA de binarios, logs, oráculo y evidencia de ejecución. STATIC_PASS no es DYNAMIC_PASS; AP07 no prueba silicio físico.
- No publicar ROM propietaria Pro, CGROM ni SRAM en Git. En pruebas de RAM externa preservar y verificar restauración; propio monitor/pila residir en RAM interna.

## 6. Próximo incremento integral (no fraccionar)
1. Partir de **11 binarios HC11 / 934 B** y ABI canónicos `AS2K-probe-tools`; discriminar con desensamblado/bytes directos cuáles son *byte-identical portable* sin consultar hardware AS2K, cuáles tocan placa y requieren mínimos deltas. No regenerar todos automáticamente.
2. Examinar en Ghidra/driver ROM Pro 2.1.2 los select/PA3/PA5/PA7/$8000, la ventana ROM/RAM y las condiciones seguras de inyección/monitor. El listado tercero de 8 KiB **no es** la ROM 2.1.2.
3. Portar la forma mínima del monitor + L2.0 A-B-C-B-A, BDS 8 B, contrato sin RESET y pila; excluir L2.6 ZPSD o convertir a oráculo externo Pro justificadamente.
4. Someter a una sola campaña dirigida `asprodiag` con ROM Pro privada, SCI/BDS/monitor/overlay y regresión normal ya cubierta sin repetir innecesariamente. Commander/ejecución remota requiere autorización concreta. Guardar fuentes, binarios resultantes, log y capturas solo si existen.
5. Registrar resultados en **`ASPRO_DIAG_ROM_Control_Rector_20261021.xlsx`**, luego en Handoff y Drive. Reportar problemas únicamente si materialmente bloquean compatibilidad.

**Estado exacto hoy**: `FOUNDATIONS_VERIFIED / ROM_STATIC_AUDIT_PASS / PORT_MATRIX_CREATED / ASPRO_DIAG_ROM_IMPLEMENTATION_PENDING / GHIDRA_PRO_PENDING / NEW_DYNAMIC_TESTS_NOT_RUN`. No se ha compilado o cargado una nueva ROM de diagnóstico Pro, ni usado Commander. El Excel existe en Drive. Ningún resultado de los nuevos tests se afirma PASS.

Para retomar desde cualquier chat, leer ESTE HANDOFF, `diagnostic_rom/PORT_MATRIX_AND_REVERSE_AUDIT.md`, `docs/AP07_FUNCTIONAL_PASS_20261020.md`, `docs/ROM_HARDWARE_MAP.md`, `AS2K-probe-tools/docs/FUNCTIONAL_PROTOCOL.md`, `BDS_PROTOCOL_V0_1.md`, `I0_2_MONITOR_OVERLAY_RAM_FEASIBILITY.md`, junto con el Excel rector, ANTES de planear/ejecutar. Ya están fijados repositorios y carpetas.

## 7. Incremento de auditoría de fuentes completado después del handoff inicial

Inspección de los ensambladores originales de `AS2K-probe-tools@e3b3a3b41e541cf70c823c2a2c6d135ab48e2616`:
- Monitor HC11 (172 B, SHA-256 `076c2244d1ce86cbc7ab79a7f5ecbabc7f1f42229f28f5dbb68b0c52422b8896`): solamente SCI $002E/$002F y RAM interna; linker garantiza MON_BDS=$00DD, MON_TX=$00E9, monitor $0090–$00EB, state $00EC–$00EF y stack $00F0–$00FF. Pila máxima DONANTE smoke 7 B. **CANDIDATO REUSO LITERAL, NO PRO PASS**.
- Overlay A 23 B (SHA `dfed5bb5f048913207e5be6aa28826fe01c1994ef1d1382661d7793c9470dad2`), B 80 B (`72bdf88f63bab9e8b4bc204cc91e2ffbe9e89c8cc896409f913ef933438b2d4d`), C 31 B (`c1ebc01c7e274b0594402a44cfaf4ab28a1ebc6767371166d35d2cbe67d51be9`). Solo JSR MON_TX $00E9, BDS A001/B002/C003, sin dependencia MMIO externo. **306 B** combinados con monitor son candidatos a reutilizar bytes idénticos.
- L2.0B a L2.4 utilizan PORTA y DUT $018D/$7FFF/$0100/$7FEA: revisar banco y seguridad en Pro. L2.5 lee desde $8000 y firmas AS2K A1C7/B65F: oráculo Pro obligatorio. L2.6 ZPSD excluido.
- **Ver detalle y clasificación definitiva provisional** en `diagnostic_rom/PORT_MATRIX_AND_REVERSE_AUDIT.md` sección 7 y Excel rector actualizado, ID sin cambios `1wzolTxo3QXIvKaCuf9XjueuO-n8PkWLI`.

**Nuevo siguiente incremento de mínimo retrabajo:** probar específicamente la reusabilidad **byte-identical** del monitor y A/B/C en Pro con BDS y ABI completo, no reconstruir ninguna imagen antes de detectar divergencia. Complementar la ingeniería Ghidra de bancos/MMIO únicamente en paralelo con ese port, no crear más gates.


## 8. Reanudación 2026-10-22 — discriminación adicional y continuidad

Se han releído el Excel rector *existente* en Drive y los manifiestos originales fijados del donante. No se crearon libros alternativos, no se modificó AS2K, no se usó Commander, no se reconstruyó MAME ni se ha ejecutado una ROM-diagnóstico Pro nueva.

**Compilación AS2K que se pretende conservar literalmente**: monitor 172 B SHA256 `076c2244d1ce86cbc7ab79a7f5ecbabc7f1f42229f28f5dbb68b0c52422b8896`; overlays A 23 B SHA `dfed5bb5f048913207e5be6aa28826fe01c1994ef1d1382661d7793c9470dad2`, B 80 B SHA `72bdf88f63bab9e8b4bc204cc91e2ffbe9e89c8cc896409f913ef933438b2d4d` y C 31 B SHA `c1ebc01c7e274b0594402a44cfaf4ab28a1ebc6767371166d35d2cbe67d51be9`. Verificados contra manifiestos Git `payloads/monitor/generated/monitor.json` y `payloads/l2_0/generated/overlays.json`. Símbolos MON_BDS=$00DD y MON_TX=$00E9; ventana overlay $0040–$008F, monitor $0090–$00EB, estado $00EC–$00EF, pila $00F0–$00FF; pico de pila donante smoke 7 B (no medido en Pro).

**Hallazgo nuevo en la instrumentación ASPRO-DIAG**: el driver `src/mame/skeleton/alphasma.cpp` en rama de port, blob `14796d807aa731035d572bc5c3ef1e00bf970887`, acepta `payload0_pro.bin` de 1..192 B al RESET y el `ap07_sci_tick` verifica eco únicamente mientras dura esa descarga. Tras `diag_bootstrap_done()`, cambia `m_ap07_sci_streaming=false` y detiene el temporizador. El código examinado **no demuestra aún un puente host SCI después de arrancar el monitor**, necesario para transmitir LOAD/overlays y recoger READY/BDS. Antes de adaptar HC11, revisar y reutilizar un transporte existente del donante AS2K o del harness; si no existe, agregar el **mínimo puente de UART post-bootstrap a ASPRO-DIAG**, manteniendo intactos los bytes del monitor. No confundir entrada inicial de 172 B con aceptación de A-B-C-B-A. Es una brecha de *harness*, no prueba de incompatibilidad CPU/ROM.

**Separación Git**: se comprobó que existe `SamDelorean/aspro-probe-tools` (privado, sin commits, tamaño 0), candidato natural a repositorio propio de producto. Intento de crear el primer README mediante conector GitHub devolvió HTTP 422 (`sha wasn't supplied`) al estar vacío. **No se inicializó** ni se trasladó código; mantener por ahora la rama ASPRO-emu fijada como autoridad y no crear un repositorio duplicado. La inicialización técnica de ese Git queda pendiente sin bloquear el port.

**Ingeniería Ghidra restante**: proyecto Ghidra Pro 2.1.2 ligado al SHA privado aún no demostrado; tampoco hay medida física del efecto PA5 banco/LCD1. El listado tercero `AlphaSmart001.HEX` sigue excluido como mapa Pro 2.1.2. Revisar driver/fotos/mapa y construir oráculos solamente para diferencias probadas. No inventar emulación de fallas eléctricas.

**Próxima ejecución integrada y única**: calificación UART post-bootstrap -> monitor READY -> overlays A-B-C-B-A con BDS exacto, checksum, retorno READY y stack interno -> variantes L2 sujetas a RAM/ROM Pro -> cierre de evidencia y actualización del mismo Excel rector. Exclusivamente `asprodiag`. Commander/T requiere nueva autorización expresa; ninguna prueba funcional nueva ejecutada en esta reanudación.

**Estado**: `STATIC_RECONCILIATION_PASS / MONITOR_OVERLAY_BINARY_REUSE_CANDIDATE / ASPRO_RUNTIME_NOT_TESTED / POST_BOOT_SCI_HOST_BRIDGE_TO_VERIFY / GHIDRA_PRO_PENDING`. El libro rector sigue en https://docs.google.com/spreadsheets/d/1wzolTxo3QXIvKaCuf9XjueuO-n8PkWLI/edit ; handoff privado en https://docs.google.com/document/d/19xFk25eEamVXA9-ZMINd0YCaQbpVNe4Z7Y0EumXs3Io/edit .
