# Procedencia y reutilización

Fuente upstream efectivamente verificada: `SamDelorean/mame-as3k` commit `c4e48388ca620472643110db2941ce70aa5f3c07`, `src/mame/skeleton/alphasma.cpp`, `// license:BSD-3-Clause`, autor Sandro Ronco.

Ese **mismo archivo** implementa clases `alphasmart_state` (Pro) y `asma2k_state` (2K), CPU MC68HC11D0, matriz de 16 columnas, dos KS0066, RAM bancarizada, persistencia y mapas separados. El driver contiene `ROM_START(asmapro)` / `COMP(...asmapro...)` con hashes que coinciden exactamente con la ROM privada.

**Decisión de arquitectura:** referenciar y compilar el archivo original de MAME directamente con `SOURCES=src/mame/skeleton/alphasma.cpp`. No copiar 42 KiB de driver ni mantener un fork redundante. El binario es un **subtarget reducido**, aunque contiene los dos registros de sistema de ese único archivo; la reducción a Pro solamente es optimización posterior, no condición para arrancar.

Fuentes AS2K/Vontar: documentación en `SamDelorean/AS2K-Emulator`; el repositorio público contiene documentación y aún no fuente reducida (README expresa que no la ha importado). La copia concreta de código adaptado en Vontar/T requiere reconciliación con su árbol canónico; no atribuirle un SHA inexistente ni reemplazarla por una recompilación genérica. Herramientas MAME ya presentes en T se reutilizan, nunca se borra su instalación.

Documentación de compilación oficial MAME 0.289: `SUBTARGET` + `SOURCES` + `REGENIE=1` para un target limitado.

Los scripts del repositorio son propios; no se incluyen ROM, datos particulares ni código derivado de firmware propietario.
