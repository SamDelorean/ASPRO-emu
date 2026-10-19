# ASPRO-HW-A17 — Expansión SRAM 128 → 256 KiB (respaldo de idea)
Fecha: 2026-10-19
Estado: **CONCEPTO ELECTRÓNICO REGISTRADO / NO AUTORIZADO PARA CONSTRUCCIÓN**
Alcance: investigación futura de hardware y posible port del Runtime AS2K al Pro. **No altera el plan AP-02 de ASPRO-DIAG.**

## Motivo y dirección aprobada
La placa Pro lleva SRAM externa de 128 KiB organizada en cuatro bancos de 32 KiB. Se desea investigar un máximo inicial de **256 KiB (8 bancos de 32 KiB)** conservando compatibilidad con la ROM Pro v2.1.2. No sustituir la estrategia vigente de ASPRO-DIAG por este trabajo. Al finalizar el DIAG, el usuario decidirá si amplía AS2K o mantiene ASPRO separado.

Documento de partida en Drive (subido por el usuario): [ASPRO_Interconexiones_Hardware_Expansion_Runtime_v01.xlsx](https://docs.google.com/spreadsheets/d/1ohGHsS6CzD_Ij_C85zJihLjJgTghxwpe/edit). Fuente de mapeo emulado: [alphasma.cpp, commit c4e4838](https://github.com/SamDelorean/mame-as3k/blob/c4e48388ca620472643110db2941ce70aa5f3c07/src/mame/skeleton/alphasma.cpp). Los datasheets MC68HC11D0, KM681000B, SRAM 256K×8, 74HC138 y 74HC74 son las fuentes de diseño **a cotejar pin por pin antes del esquemático de fabricación**.

## Lo que sabemos y lo que sólo suponemos
- **Demostrado en el driver:** RAM externa 128 KiB; cuatro entradas de 0x8000; `m_rambank->set_entry(((data >> 3) & 1) | ((data >> 4) & 2))`. Por tanto, el modelo lógico de banco usa **PA3 y PA5**: `bank2 = 2*PA5 + PA3`.
- **Modelado, NO medido en la PCB:** la correspondencia física PA3 → SRAM A15 y PA5 → SRAM A16. Requiere continuidad y revisión de chip select / lógica auxiliar.
- **Principio externo:** el HC11 sólo direcciona una ventana RAM de 32 KiB; no hace falta un pin A17 del micro. La entrada A17 del chip SRAM ampliado es un **bit de estado registrado**, no otra fase del bus multiplexado.
- **Supuesto de encapsulado a confirmar:** SRAM 256K×8 compatible en DIP32 (por ejemplo AS6C2008A): A17 se ubica en pin 1 donde la SRAM original 128K×8 tenía NC. Consultar hojas de datos exactas y tensiones antes de conexión. Este dato no valida compatibilidad global del reemplazo.

## Esquema conceptual de señales

```text
MC68HC11D0P (bus externo)
  Direcciones CPU A15,A14,A13 [PB7,PB6,PB5] --+
  R/W (0=escritura), E (ciclo válido) --------+--> [U1 74HC138 / decodificación]
                                               |         |
   Bus datos D0 [PC0 fase datos] -----------+  |     /Y5 (pulso bajo)
                                           |  |         |
                                           v  v         v
                                      [U2 74HC74] <--- CLK (flanco al terminar /Y5)
                                           D             |
                                           |             |
                                           +---- Q ------+--------> SRAM A17 (pin 1*)
                                                           *pinout sujeto a modelo final
PA3 ---------------------------------------------------------------> SRAM A15 (modelo)
PA5 ---------------------------------------------------------------> SRAM A16 (modelo)
BUS normal A0..A14 -----------------------------------------------> SRAM A0..A14
R/W + CS/OE/WE originales ----------------------------------------> SRAM controls
```

**Interpretación:** una escritura de la CPU en una dirección destinada al latch lleva D0=0 o 1. El decodificador genera un pulso; el registro mantiene ese bit. Q es A17 hasta siguiente escritura o RESET; PA3/PA5 siguen eligiendo uno de cuatro bancos dentro de cada mitad de 128 KiB.

En el ejemplo anterior se propuso **región candidata $A000–$BFFF**, porque A15..A13=101 genera `/Y5` activo al habilitar U1; `STAA $A000` con bit0=1 seleccionaría bancos 4–7, y bit0=0 seleccionaría 0–3. **No se ha confirmado que esa región esté libre físicamente**. Este decodificador selecciona una región de 8 KiB, NO una dirección única `$A000`.

### Conexiones de trabajo del circuito propuesto (NO placa validada)

| Función | 74HC138 | 74HC74 |
|---|---|---|
| Dirección | A pin1 ← CPU A13, B pin2 ← CPU A14, C pin3 ← CPU A15 | — |
| Cualificador | /G2A pin4 ← R/W; /G2B pin5 ← GND; G1 pin6 ← E | — |
| Pulso | /Y5 pin10 → CLK del HC74 | CLK pin3 |
| Dato | — | D pin2 ← D0 durante fase de datos de Port C |
| Reset | — | /CLR pin1 ← reset supervisado; /PRE pin4 ← 1 |
| Dirección ampliada | — | Q pin5 → SRAM A17 |
| Alimentación | 16=VCC, 8=GND | 14=VCC, 7=GND |

El otro flip-flop del 74HC74 debe tener entradas definidas; desacoplo 100 nF por integrado.

### Tabla de ocho bancos

```
bank = (A17 << 2) | (PA5 << 1) | PA3
A17 PA5 PA3   banco   región física KiB
 0   0   0      0       0–32
 0   0   1      1      32–64
 0   1   0      2      64–96
 0   1   1      3      96–128
 1   0   0      4     128–160
 1   0   1      5     160–192
 1   1   0      6     192–224
 1   1   1      7     224–256
```

Pseudocódigo ROM/Runtime (solo para explicar la interfaz propuesta; **NO** grabar o ensamblar aún):

```asm
LDAA #$01
STAA $A000    ; A17 := 1, SI se valida esa escritura en hardware
LDAA #$00
STAA $A000    ; A17 := 0
```

## Problemas aún NO resueltos (importantes, no afirmar circuito final)
1. **Captura de datos / temporización:** /Y5 sube al terminar E. D0 quizá no cumpla setup/hold del 74HC74 respecto a ese flanco; antes de fabricar, contrastar las curvas de temporización MC68HC11D0 con 74HC138+74HC74 y evitar señales de clock con rebotes/glitches. Podría convenir un latch transparente 74HC573/373 o un pulso de captura diferente. El esquema **no está verificado**.
2. **Decodificación física:** confirmar que escritura a $A000–$BFFF no causa conflicto con decodificación ROM, teclado u otros periféricos en la PCB real, independientemente del comportamiento emulado MAME. Si no es seguro, elegir otro rango mediante comparador de direcciones y respetar E/RW.
3. **RESET y batería:** forzar A17=0 en arranque para compatibilidad stock. Definir power-on reset, salida Q frente a retención de SRAM, no back-power y protección /WE durante power-fail.
4. **Compatibilidad SRAM real:** cotejar pin a pin CE1/CE2, /OE, /WE, VCC, GND, niveles y tiempos con KM681000BLP y modelo exacto 256K×8; no confiar sólo en pin1 NC→A17.
5. **ROM y Runtime:** acceso al registro de banco sólo desde rutinas robustas del port; no poner allí código que se quede inaccesible tras cambiar banco; acceso al estado de archivos, stack/IRQ y restauración de banco según implementación. ROM ampliada requiere estudio separado.
6. **Medición de continuidad:** fotografiar reverso de PCB, confirmar PA3→A15, PA5→A16, pines SRAM y funcionamiento latch original; no inferir pistas por fotos de baja resolución.

## Regla de continuidad
Esta ampliación **queda registrada para retomarla después**, no se implementa ni prueba por ahora, y no bloquea AP-02. No reservar pines como 'libres' sin pinout y continuidad; no convertir este prototipo en un cambio de alcance del emulador ni del Runtime actual. Respetar las directrices Git/Drive/Commander y evitar gates administrativos.
