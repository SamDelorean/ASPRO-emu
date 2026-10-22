# Manifiesto canónico — ASPRO Stable v0.1.0

Fecha de corte: **21 de octubre de 2026**.
Repositorio: `SamDelorean/ASPRO-emu`.
Rama estable: `release/stable-v0.1.0-vontar-surf`.

## Paridad fuente realmente instalada

Los siguientes objetos Git **se verificaron en los dos equipos**
mediante `git hash-object` de los archivos instalados/staged y
comparación con el árbol de GitHub.

| Fuente | SHA de objeto Git |
| --- | --- |
| `stable/alphasma.cpp` | `fe589b3a5f9203eb42c309cf3dc83567028db8dc` |
| `stable/aspro_ui.py` | `572b6717e5e1e18ac224bf57829bfd4f8751690c` |
| `stable/aspro_session.py` | `873f6263708b58025526bb9d056773b7b3272d40` |
| `stable/proven_hc11/mc68hc11.cpp` | `f25752fc03165c9938a456ae9c0d6d9e9b5841f0` |
| `stable/proven_hc11/mc68hc11.h` | `fb08eb8386b9c06712c34d883f91199160132d4b` |

## Evidencias de producto instalado

| Host | Arquitectura | Estado | SHA-256 binario de producción |
| --- | --- | --- | --- |
| Vontar (Armbian) | aarch64 | BUILD/VALIDATE/INSTALL PASS, `EXIT=0` | `2c0282172b43cb1d4d33c92d32abe2505a77f99b65bbf36aeb6181e431eb12b1` |
| Surf (postmarketOS) | ARMv7 musl | BUILD/ROM-smoke PASS; instalación y coincidencia binaria PASS después de reparación de permisos | `aa4c96cc8b3c0b5ea61f96622ae354627a69482dc752b1296e6385de7c376223` |

El binario Surf NO se derivó del de Vontar ni de compilación cruzada
en T. Se produjo directamente en Surf, con el compilador y bibliotecas
ARMv7/musl y la adaptación original `bx` de 17-oct.

Los registros de Vontar documentaron exactamente **1 controlador
`asmapro`** y los de Surf `-listfull` también identificaron
`asmapro`. El constructor AS2K Stable se reutilizó como patrón,
sin copiar ni sobrescribir el producto instalado.

## Insumos privados (solo identidad, sin contenido)

- Firmware Pro 2.1.2: 32.768 bytes, SHA-1
  `c3c6a421c9ced92db97431d04b4a3f09a39de716`.
- CGROM KS0066 F05: 4.096 bytes, SHA-1
  `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- Payload bootstrap SCI: 121 bytes, SHA-256
  `25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`.

## Alcance de las pruebas y límites

- ASPRO-DIAG previo: pruebas funcionales de SCI/bucle de
  transmisión, teclado y LCD registradas en `docs/AP07_FUNCTIONAL_PASS_20261020.md`.
- Vontar producto Stable: compilación, validación y binario/GUI
  estáticos PASS; **no verificado con prueba interactiva posinstalación**.
- Surf producto Stable: compilación y arranque con ROM original
  sin interfaz gráfica PASS; fuente y ejecutable instalado coincidentes;
  **sin prueba interactiva posinstalación**.
- MAME advierte `ks0066_f05.bin ROM NEEDS REDUMP`; la advertencia
  no impidió la prueba de arranque, pero no debe ocultarse.
- No se afirma PASS de teclado, pantalla, PC o bootstrap **en la
  interfaz pública instalada** hasta ejecutar pruebas específicas.

## Integridad y privacidad

Esta rama no contiene ROMs, firmware, NVRAM ni payload binario.
El código fuente del procesador y el driver constituye adaptación
del proyecto MAME; conservar cabeceras y licencias originales.
No crear ni subir paquetes con contenido privado.
