# Plan maestro de ASPRO-emu

## Objetivo técnico
Arrancar, visualizar y editar texto en la ROM AlphaSmart Pro 2.1.2 utilizando **MAME reducido**, reutilizando los componentes existentes de AS2K/Vontar. Solo ASPRO-DIAG se usa para pruebas; luego se extrae ASPRO-STABLE público.

## AP-01 — INCREMENTO ESTÁTICO INTEGRAL
- Comparar ROM, fotos, especificaciones y driver MAME existente.
- Reutilizar el driver que ya implementa **asmapro**; NO escribir driver nuevo ni CPU nueva.
- Preparar auditor de ROM y HEX, construcción SUBTARGET reducida, runner DIAG, logs aislados, comandos de depuración y pruebas estáticas.
- Entregar código versionado con procedencia, límites y un único plan de ejecución agrupada.

## AP-02 — ÚNICA INTERVENCIÓN DIRIGIDA EN T (por autorizar)
- Verificar ruta del árbol canónico y variante instalada a partir de documentación; no explorar sin necesidad.
- Compilar `asprodiag` reducido usando `SOURCES`, sin construir MAME completo y sin modificar fuente original.
- Ejecutar la ROM privada bajo `asprodiag` con script diagnóstico y observación RESET→teclado→LCD.
- Registrar errores y corregir la causa concreta en el mismo incremento, si la evidencia permite hacerlo.
- La meta no es cerrar un gate RESET sino obtener pantalla y respuesta de teclado. Toda afirmación de éxito requiere evidencia funcional.

## AP-03 — CIERRE Y PRODUCTO
- Completar sólo las diferencias reales de banco, LCD, teclado, persistencia o temporización.
- Calificar carga de archivos, editor y persistencia mediante ASPRO-DIAG.
- Derivar ASPRO-STABLE público desde el código validado, eliminando sólo instrumentación; mantener instalador reducido y controles humanos similares al AS2K/Vontar.

## Sin burocracia
No subdividir en PRE-01 / GATE-X / REQUALIFY a menos que un fallo real documentado lo exija. Reutilizar SHA, fuentes y resultados; no repetir PASS existentes. 3 llamadas Commander por intervención aprobada, máximo, sin polling.

## Estado del 19-oct-2026
AP-01 implementado estáticamente como scripts y documentación. **Sin compilación ni ejecución de MAME**. AP-02 espera ejecución autorizada.
