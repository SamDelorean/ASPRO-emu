# Plan maestro de ASPRO-emu

## Objetivo técnico
Arrancar, visualizar y editar texto en la ROM AlphaSmart Pro 2.1.2 utilizando **MAME reducido**, reutilizando los componentes existentes de AS2K/Vontar. Solo ASPRO-DIAG se usa para pruebas. La distribución estable y su integración en AS2K quedan expresamente **sin decidir** hasta completar la validación funcional y recibir una decisión del usuario.

## Directiva superior vigente
**Entorno de trabajo exclusivamente ASPRO-emu.** AS2K es una **referencia de código en sólo lectura**, no un workspace para compilar o editar. Toda construcción Pro se realiza en entorno autónomo ASPRO (directorio y outputs independientes). No llamar `make` sobre el árbol AS2K.

**Codex:** para reintentos con cuenta ChatGPT, usar selector **Predeterminado** o modelo explícitamente admitido, nunca forzar `gpt-5.5` después del error de compatibilidad. El modelo se configura en el cliente Codex, no en el encargo.

**ASPRO-DIAG primero y separado.** No fusionar, ampliar ni modificar el emulador AS2K existente. Al concluir la validación de ASPRO-DIAG, presentar evidencias técnicas y alternativas, y dejar al usuario la decisión final: (a) ampliar AS2K para ambos modelos o (b) conservar una distribución propia ASPRO. Ninguna de las opciones está aprobada por anticipado. Evitar gates y trabajos fraccionados.

## AP-01 — INCREMENTO ESTÁTICO INTEGRAL
- Comparar ROM, fotos, especificaciones y driver MAME existente.
- Reutilizar el driver que ya implementa **asmapro**; NO escribir driver nuevo ni CPU nueva.
- Preparar auditor de ROM y HEX, construcción SUBTARGET reducida, runner DIAG, logs aislados, comandos de depuración y pruebas estáticas.
- Entregar código versionado con procedencia, límites y un único plan de ejecución agrupada.

## Investigación futura de memoria — archivada, NO bloqueante
- [ASPRO-HW-A17](ASPRO_HW_A17_EXPANSION_256K_CONCEPT.md): expansión 128→256 KiB con A17 retenido en latch, a validar eléctricamente; queda aplazada hasta después de AP-02 y no implica un cambio del hardware ni del plan de emulación.

## AP-02 — ÚNICA INTERVENCIÓN DIRIGIDA EN T (por autorizar)
- Reconciliar las referencias AS2K/MAME en lectura y trabajar sólo en workspace ASPRO independiente; no compilar dentro de AS2K ni alterar sus objetos, cachés o ejecutables.
- Compilar `asprodiag` reducido usando `SOURCES`, sin construir MAME completo y sin modificar fuente original.
- Ejecutar la ROM privada bajo `asprodiag` con script diagnóstico y observación RESET→teclado→LCD.
- Registrar errores y corregir la causa concreta en el mismo incremento, si la evidencia permite hacerlo.
- La meta no es cerrar un gate RESET sino obtener pantalla y respuesta de teclado. Toda afirmación de éxito requiere evidencia funcional.

## AP-03 — CIERRE FUNCIONAL Y DECISIÓN POSTERIOR
- Completar sólo las diferencias reales de banco, LCD, teclado, persistencia o temporización.
- Calificar carga de archivos, editor y persistencia mediante ASPRO-DIAG.
- Tras demostrar funcionalidad en ASPRO-DIAG, comparar coste real y mantenimiento de las dos opciones. **No construir ni publicar ASPRO-STABLE ni ampliar AS2K antes de la decisión expresa del usuario.**

## AP-05 — AUDITORÍA DE PERIFÉRICOS POST AP-04 (vigente)

AP-03 (arranque/LCD/tecla A) y AP-04 (F1–F8/persistencia emulada) obtuvieron PASS visual de alcance; **la decisión de integrar o separar ASPRO todavía no procede como cierre total de hardware** hasta revisar periféricos. [Auditoría AP-05](AP05_PERIPHERAL_HARDWARE_AUDIT.md): Pro comercial incorpora interfaz PC AT/PS2 y Mac ADB; están ausentes del emulador actual como host externo, aunque ROM 2.1.2 sí contiene modos attached y Send. No existe evidencia de IR stock Pro; módulo IrDA opcional corresponde AS2K/AS3K. DC, AA/NiCad, CR2032 y low-battery requieren sólo modelado útil, no simulación eléctrica completa. Prioridad: estudio estático ROM 2.1.2 y adaptación mínima de los endpoints externos de envío de texto; **sin reabrir el núcleo HC11/LCD/F1–F8 ni modificar AS2K**. No construir stable ni elegir arquitectura sin decisión expresa.

## AP-06 — TRANSMISIÓN AL PC → TXT (implementación estática vigente)

A petición del usuario, utilizar el transporte PC **ya probado** en `AS2K-Emulator/release/vontar-stable-public-20261018` (Set 2, PD0/PD1, scancodes, UTF‑8) para activar en ASPRO-DIAG `PC_CONNECTED` y capturar `Send` en `send.txt`. Reutilizar el núcleo exacto, con clase `aspro_send_state` y pinout candidato PA0/PA2 del Pro; no leer la SRAM como sustituto del envío. [Plan y fuente real](AP06_PC_SEND_TXT.md). Compilar sólo `ASPRO-emu/build/send-mame` desde el árbol T canónico en solo lectura; campaña dirigida única, TXT exacto `abc`; no refuncionalizar módulos cerrados ni alterar AS2K. `STATIC_CODE_REUSE_PASS`; `COMPILE_PENDING / DYNAMIC_PENDING`. ADB y otras ampliaciones quedan fuera de esta función PC, sin adelantar producto estable.

## Sin burocracia
No subdividir en PRE-01 / GATE-X / REQUALIFY a menos que un fallo real documentado lo exija. Reutilizar SHA, fuentes y resultados; no repetir PASS existentes. 3 llamadas Commander por intervención aprobada, máximo, sin polling.

## Estado del 19-oct-2026
AP-01 implementado estáticamente como scripts y documentación. **Sin compilación ni ejecución de MAME**. AP-02 espera ejecución autorizada.
