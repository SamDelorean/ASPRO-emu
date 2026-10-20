# AP-05 — Auditoría estática de periféricos reales AlphaSmart Pro

**Fecha:** 2026-10-20
**Estado:** `HARDWARE_PERIPHERAL_INVENTORY_STATIC_REVIEWED` / `ADB_PS2_EXTERNAL_EMULATION_PENDING`
**Alcance:** AlphaSmart Pro, ROM privada v2.1.2, `asmapro` en MAME 0.289. No confundir con AlphaSmart 2000 / AlphaSmart 3000; no modificar AS2K ni construir ASPRO-STABLE.

## Resultado principal

**No hay evidencia de un puerto IR/IrDA propio del AlphaSmart Pro comercializado.** El manual original sólo documenta el puerto PC compatible con teclado AT/PS/2, el puerto Mac/Apple IIGS ADB, el jack DC y las fuentes de energía. La guía complementaria de Get Utility diferencia los modos: **Pro por cable** y **transferencia inalámbrica sólo con módulo IR opcional de AS2000/AS3000**. El propio driver MAME tiene comentario `Optional IrDA sub board` *bajo `ROM_START(asma2k)`*, y **no** bajo `ROM_START(asmapro)`. Ausencia de documentación no es prueba absoluta para cualquier modificación de terceros, pero **no justifica implementar IR en Pro stock**.

El conjunto de periféricos no cualificados funcionalmente por AP-02/03/04 consiste principalmente en **emulación de teclado/transferencia hacia un host PC PS/2 y hacia host Macintosh ADB**, y en segundo término en el **comportamiento de alimentación**, más allá del estado lógico de batería y la NVRAM que ya están representados.

## Matriz de presencia, estado del emulador y evidencia

| Recurso | Pro físico | Estado ASPRO-DIAG actual | Fuente / cautela |
|---|---|---|---|
| CPU MC68HC11D0P 8 MHz | Confirmado en driver, placa y libro de interconexiones | CPU real del driver, funcional | No reabrir pruebas de instrucción HC11 |
| 2 KS0066F05 + HD44100H, 40×4 | Confirmado | Texto y cursores probados en AP-03/04 | Drivers de segmento Pro difieren del AS2K |
| Matriz de teclado (16 columnas) | Confirmada | Entrada normal y F1–F8 PASS de alcance | No equivale a protocolizar un teclado externo |
| SRAM externa 128 KiB, 4 bancos | Confirmada | Archivo NVRAM de 128 KiB, texto recuperado tras reinicio | No prueba tensión de retención física |
| **Conector PC AT/PS/2** | **Confirmado por manual Pro** | **FALTA emulación de host conectado y salida de scancodes** | `Send`, teclado remoto, velocidad, detección de conexión/hotplug |
| **Conector Mac/IIGS ADB** | **Confirmado por manual Pro** | **FALTA emulación de host ADB y sus transacciones** | `Send`, protocolo ADB, host, TurboTransfer y Get Utility según compatibilidad firmware |
| **Jack de alimentación DC** | Confirmado | No hay modelo eléctrico de adaptador | Manual 1997: 8–12 V DC, centro positivo; no simular voltajes sin datos |
| 2 pilas AA / paquete NiCad opcional | Confirmado | No hay descarga/carga electroquímica | Manual: posibilidad de alimentar por cable PC/Mac; pack recargable opcional |
| **Pila CR2032 de respaldo SRAM** | Confirmada, visible en foto de placa | NVRAM persistente como modelo lógico | Sin simulación de fallo de pila ni consumo |
| **Batería baja (PA1 en lógica MAME)** | Confirmada por firmware, libro de conexiones y driver | Interruptor lógico `BATTERY: Normal/Low` | Es entrada lógica simplificada, no circuito de umbral |
| Botón/interruptor encendido | Confirmado como operación manual y placa | Reinicio y apagado de proceso sólo | Transiciones de power/reset no calificadas |
| **IR/IrDA** | **NO documentado como hardware stock Pro** | No implementado; no añadir por ahora | Sólo AS2K/AS3K mencionan módulo opcional |
| **USB nativo** | **NO documentado en Pro** | No implementar | `PDIUSBD11D`/`ISP1161ABD` en archivo `specs` mezclado: libro del usuario advierte no atribuirlo a Pro |
| **Puerto impresora directa** | **NO documentado en Pro** | No implementar sin evidencia | El Pro transfiere texto como teclado a un ordenador; la impresión directa corresponde a generaciones posteriores |
| Puerto RS-232 tradicional | NO identificado como conector físico Pro | No implementar genérico | HC11 tiene SCI, pero PD0/PD1 aún no están trazados; **SCI interno ≠ conector RS-232** |
| Audio / zumbador / altavoz | NO confirmado en Pro | No modelado | Manual, driver y fotos inspeccionados sin identificación inequívoca |

## Evidencia específica ROM 2.1.2 (análisis de cadenas, NO ingeniería inversa completa)

ROM privada de **32768 bytes**; SHA-256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`. Inspección de secuencias ASCII imprimibles reales, sin alterar ni publicar firmware:

- `$F8EC` → `Attached to Mac, emulating keyboard.`
- `$F911` → `Attached to PC, emulating keyboard.`
- `$F935` → `Press Send key to transfer file`
- `$F956` → `Sending....`
- `$F5FF` → `To change Send speed, type 1, 2, 3 or 4.`
- `$F532` → `Low Battery!!`

Estas cadenas corroboran funciones de firmware **presentes**, no demuestran que el dispositivo externo esté emulado ni señalan directamente las rutinas/los pines físicos. Buscar cadenas `IR` no sustituye un análisis del código: la clasificación IR se fundamenta en manual y driver.

**Compatibilidad Get Utility según plataforma:** la [guía de Get Utility para Mac](https://www.manualslib.com/manual/207841/Alphasmart-As-Pro.html) documenta Pro con ROM **v2.05 o posterior** para selección remota de archivo, por lo que **2.1.2 entra en ese criterio para Mac**. La [guía posterior de Get Utility para Windows](https://manualzz.com/doc/1619937/alphasmart-alphasmart-3000--alphasmart-2000--alphasmart-p...) indica Pro 2.09 o ≥2.1.3 y excluye expresamente **2.1 y 2.1.2**. Son compatibilidades de utilidades y versiones diferentes, no afirmaciones universales de hardware. Verificar el protocolo efectivo de la ROM 2.1.2 por ADB/PS2; no prometer recepción Windows. La transferencia **saliente** mediante `Send` está documentada.

## Auditoría de driver MAME existente

Archivo fijado: [mame-as3k: alphasma.cpp, c4e4838](https://github.com/SamDelorean/mame-as3k/blob/c4e48388ca620472643110db2941ce70aa5f3c07/src/mame/skeleton/alphasma.cpp).

- `alphasmart_state::alphasmart(machine_config&)` instancia MC68HC11D0, dos KS0066, pantalla/paleta y NVRAM, y conecta callbacks PA y PD.
- Con `INPUT_PORTS_START(alphasmart)` se emula la matriz de teclado y `BATTERY`. El mapa incluye SRAM y MMIO de matriz, pero **no** hay modelo de host ADB ni PS/2 conectado al Pro ni backend para que `Send` emita scancodes externos.
- `port_d_r()` devuelve `m_port_d` y `port_d_w()` registra ese estado; PD0/RxD y PD1/TxD son funciones posibles del silicio según datasheet, pero ninguna relación física con conectores debe suponerse sin continuidad/código.
- Comentario `Optional IrDA sub board` aparece en la descripción AS2K, no Pro. No transferir módulo IR de AS2K automáticamente.
- La entrada BATTERY lógico `Normal/Low` no sustituye un circuito de fuente, cargador NiCad o VSTBY.

## Fuentes originales contrastadas

1. [AlphaSmart Pro Owner's Manual, 1995, texto](https://manualzz.com/doc/892512/alphasmart-pro-keyboard-user-manual) — puertos PC/Mac, Send, velocidades, NiCad, CR2032, bajo voltaje.
2. [AlphaSmart Pro Owner's Manual, edición 1997, PDF](https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Peripherals/Other/AlphaSmart/Manuals/AlphaSmart%20Pro%20-%20Owner%27s%20Manual.pdf) — fuente de energía, comunicación, Get Utility, características posteriores; **no todas las funciones garantizadas en ROM 2.1.2**.
3. [Supplementary Get Utility (incluye Pro)](https://www.manualslib.com/manual/207841/Alphasmart-As-Pro.html) — cable vs módulos IR de AS2K/AS3K.
4. [Driver MAME fijado](https://github.com/SamDelorean/mame-as3k/blob/c4e48388ca620472643110db2941ce70aa5f3c07/src/mame/skeleton/alphasma.cpp) — hardware instanciado y falta de host interfaces.
5. [Desensamblado exploratorio tercero](https://hackaday.io/project/189608-rom-disassembly-alphasmart-pro) — mapa lógico PA/PD y rutinas PS/2/ADB (puede corresponder a otra ROM; no confundir con v2.1.2).
6. **Documento privado del usuario, no creado ni cargado por este informe:** [ASPRO_Interconexiones_Hardware_Expansion_Runtime_v01.xlsx](https://drive.google.com/file/d/1ohGHsS6CzD_Ij_C85zJihLjJgTghxwpe/view), 17 hojas; pines PA1, PD0/PD1, adaptadores, componentes; continuidad de PCB **NO_MEDIDA**.
7. [Foto real asp1](https://drive.google.com/file/d/1IAAZrCFuXfUzWugwWg3iCj1kOXxmyqy_/view) y [asp3](https://drive.google.com/file/d/1yzf-lE8I7Uaz60DOsVd36wJW3CAO01Rc/view). Fotografías respaldan batería CR2032, cable LCD y conjunto de conectores; **no bastan para adjudicar toda señal del conector**.

## Delta mínimo para cerrar paridad de periféricos

**Una sola fase coherente, sin gates artificiales:**

1. **Estática de la ROM 2.1.2**: localizar en el binario las rutas de detección de host, inicialización y línea/s de protocolo PC-AT/PS2 y ADB, Send/scancodes, tiempo, transición a modo teclado externo y rutas receptivas Get Utility; contrastar posiciones PD0/PD1 o GPIO reales. No usar como verdad de v2.1.2 un desensamblado de versión distinta.
2. **Reutilizar sólo el backend probado de AS2K** donde protocolarmente sea compatible; conservar el esquema/temporización Pro. Añadir endpoints aislados dentro de ASPRO-DIAG, sin cambiar core HC11, LCD, NVRAM, driver AS2K ni emulador estable.
3. **Una campaña dirigida ASPRO-DIAG** de detección/cambio de modo, envío de un archivo de texto mediante `Send`, comparación de scancodes/transcripción en host virtual, desconexión y reanudación del editor. ADB + PS/2, si es viable, en la **misma** encomienda/instrumentación; no repetir AP-02/03/04. Probar `BATTERY=Low` sólo si se necesita comprobar una diferencia de comportamiento relevante, aprovechando el switch ya instalado.
4. Entregar evidencia y matriz de capacidades con estados separados `STATIC_CONFIRMED`, `DYNAMIC_PASS`, `NOT_IMPLEMENTED`, `NOT_PRESENT_STOCK`, `HARDWARE_UNVERIFIED`. No reclamar `FULL_HARDWARE_PASS` hasta los puertos externos.
5. Tras cierre de paridad de periféricos, **volver a presentar decisión de producto**: ASPRO independiente o integración AS2K. No adelantarla.

**No autorizado automáticamente:** construir ASPRO-STABLE, añadir infrarrojos/USB, editar AS2K, crear diseño de PCB, o ejecutar pruebas en otro emulador. Commander con aprobación y presupuesto vigente.
