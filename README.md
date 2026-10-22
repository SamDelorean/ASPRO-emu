# ASPRO-emu — AlphaSmart Pro Stable

**Versión estable de código fuente: v0.1.0 (21 de octubre de 2026).**
Emulador reducido basado en MAME para AlphaSmart Pro 2.1.2, separado de
AS2K Stable y del banco de pruebas ASPRO-DIAG.

[**Producto Stable, menús e instalación Vontar/Surf**](stable/README.md) ·
[**Manifiesto y SHA verificados**](stable/RELEASE_MANIFEST.md) ·
[**Continuidad del proyecto**](docs/HANDOFF.md) ·
[**Historia de ASPRO-DIAG**](docs/DIAG_RESEARCH_README_20261020.md)

## Estado de las compilaciones e instalaciones

| Equipo | Plataforma | Resultado |
| --- | --- | --- |
| **Vontar** | Armbian **aarch64** | ASPRO reducido: compilación, validación e instalación **PASS** (`EXIT=0`) |
| **Surface RT (Surf)** | postmarketOS **ARMv7/musl** | Compilación nativa y smoke con ROM **PASS**; binario instalado y comparado **PASS** tras reparación de permisos |
| **ASPRO-DIAG** | Entorno de diagnóstico aislado | Ensayos funcionales previos documentados en `docs/AP07_*` |

La fuente instalada en ambos equipos se contrastó directamente con
los **mismos cinco blobs Git**: driver `stable/alphasma.cpp`,
frontend `stable/aspro_ui.py`, gestor `stable/aspro_session.py`
y los dos archivos `stable/proven_hc11/mc68hc11.*`.
Véase [manifest](stable/RELEASE_MANIFEST.md).

Los resultados de compilación, validación e instalación **no
constituyen un PASS de uso interactivo posinstalación**. Aún deben
verificarse con pantalla real la interfaz, teclado, conexión PC y
bootstrap SCI en ambas máquinas.

## Interfaz pública incluida

El frontend GTK3 proporciona LCD virtual 240 × 36, teclado y menús:
**Archivo**, **Máquina**, **Ver**, **Configuración** y **Ayuda**.
Entre sus funciones están selección de ROM y payload bootstrap, modo
normal, captura LCD, reinicio, PC conectado/desconectado, escalado y
pantalla completa. El firmware privado debe estar disponible por
separado: **no se distribuyen ROMs con este repositorio**.

## Compilación e instalación

Los dos equipos tienen **constructores nativos distintos**:

- Vontar: `stable/build_install_vontar_as2k_method.sh`, recupera la
  arquitectura del constructor AS2K Stable y genera **solo asmapro**.
- Surf: `stable/deploy_surf_native_autonomous.sh`, ejecutado
  **directamente en Surf** con `make -j1` y la adaptación
  comprobada de `bx` para musl; **no usar T640 para compilar Surf**.

Los scripts requieren el árbol MAME donante ya preparado y los archivos
privados del usuario en sus ubicaciones existentes. Consultar
[las instrucciones completas](stable/README.md) antes de ejecutarlos.
Ambas instalaciones crean el lanzador `/usr/local/bin/aspro` y
entrada de menú **ASPRO Emulator**, sin reemplazar AS2K.

**No confundir con los scripts experimentales históricos** de
compilación cruzada o recuperación, que permanecen solo como evidencia.

## Procedencia y privacidad

El código MAME y HC11 conserva sus avisos de autoría y licencia; las
adaptaciones ASPRO se proporcionan como código fuente. Excluidos de
Git: ROM AlphaSmart Pro, ROM LCD, payload binario, imágenes privadas,
NVRAM, copias de SRAM, credenciales y registros con datos privados.
Las huellas de los materiales privados se documentan para permitir
comprobación local, no redistribución.

Consulta el [plan técnico](docs/MASTER_PLAN.md),
[mapa de hardware](docs/ROM_HARDWARE_MAP.md) y
[documentación de procedencia](docs/SOURCE_PROVENANCE.md).
