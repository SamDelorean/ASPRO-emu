# ASPRO Stable v0.1.0 — Vontar ARM64 y Surface RT ARMv7

Esta carpeta es el **producto estable reducido AlphaSmart Pro**, separado de
`ASPRO-DIAG` y de la instalación de `AS2K`. Contiene el **mismo driver, CPU
HC11 y menú GTK** que se compilaron e instalaron en ambos equipos el
21 de octubre de 2026. Los cinco blobs de fuentes verificados coinciden
exactamente en Surf y Vontar; consúltese `RELEASE_MANIFEST.md`.

## Funciones integradas

- Driver MAME reducido: **solo `asmapro`**, AlphaSmart Pro 2.1.2;
  MCU **MC68HC11D0P**, LCD **KS0066**, NVRAM aislada.
- Interfaz GTK3 con ventana y LCD virtual **240 × 36**, teclado y
  puente de comandos y fotogramas a MAME.
- Menú **Archivo**: Abrir ROM Pro, Abrir payload bootstrap,
  Arranque normal, Guardar captura LCD, Salir.
- Menú **Máquina**: Reiniciar AlphaSmart Pro, PC conectado/desconectado.
- Menú **Ver**: escalas LCD 1× a 4× y pantalla completa.
- Menú **Configuración**: carpeta de ROM y payload.
- Menú **Ayuda**: acerca de ASPRO.
- Bootstrap SCI con payload privado opcional, conexión PC y eventos de teclado,
  implementados en el código de producto y expuestos en la interfaz.

**Calificación:** núcleo compilado, enlazado y validado en Vontar y Surf;
rom original probada en el smoke test de Surf. La apertura gráfica real y
las interacciones de teclado, PC y bootstrap **no tienen todavía un PASS
manual posinstalación en ambas máquinas**. No presentar los menús integrados
como prueba funcional independiente.

**Cambio en `main`, 22-oct-2026 (aún NO instalado):** se corrigió
exclusivamente el mapa de teclas virtuales GTK→matriz física Pro en
`stable/alphasma.cpp`. La comparación estática coincide en 78 de 78
contactos documentados; FIND no tiene posición Pro comprobada.
`tools/test_pro_ui_matrix.py` agrega una regresión aislada de firmware.
Los binarios/hashes de v0.1.0 arriba siguen representando la instalación
**anterior** y todavía necesitan compilación y prueba del nuevo teclado.
Ver `stable/RELEASE_MANIFEST.md`.

## Archivos de producto

| Archivo | Uso |
| --- | --- |
| `alphasma.cpp` | Driver Pro, LCD/teclado, bootstrap/PC y puente UI |
| `proven_hc11/mc68hc11.cpp`, `.h` | Implementación D0 con SCI usada en las compilaciones |
| `aspro_ui.py` | Menús GTK, LCD 240×36 y teclado virtual |
| `aspro_session.py` | Preparación de ROM/NVRAM y sesión privada de MAME |
| `install_stable.sh` | Instalación separada en `/usr/local`, permisos 0755 |
| `build_install_vontar_as2k_method.sh` | Constructor nativo **Vontar**, reproduciendo AS2K Stable |
| `deploy_surf_native_autonomous.sh` | Constructor nativo **Surf**, parche musl v2 recuperado |

Los otros scripts `stable/*cross*`, `stage_private_T.sh`,
`deploy_vontar_autonomous.sh` y `vontar_resume_consolidated.sh`
son **antecedentes experimentales o recuperación**. NO son rutas de
instalación de esta versión y se conservan solo por trazabilidad histórica.
No utilizar la compilación cruzada desde T para Surf.

## Vontar — Armbian aarch64

Requiere el árbol MAME nativo ya instalado en
`~/projects/mame-as2k-stable-arm64`, usuario `spc`, `sudo -n`,
GTK3 y ROMs privadas en
`~/.local/share/alphasmart/private/aspro/roms/` más payload en
`~/.local/share/alphasmart/private/aspro/payload/`.

Desde un checkout de **este repositorio**, preparar únicamente fuentes
públicas en el staging histórico utilizado en la instalación aprobada:

```sh
STAGE="$HOME/Projects/alphasmart/aspro-stable-pack/stable"
mkdir -p "$STAGE"
cp stable/alphasma.cpp stable/aspro_ui.py stable/aspro_session.py stable/install_stable.sh "$STAGE/"
cp stable/proven_hc11/mc68hc11.cpp stable/proven_hc11/mc68hc11.h "$STAGE/"
bash stable/build_install_vontar_as2k_method.sh
```

El script respalda los archivos donantes, aplica el driver Pro y la CPU
D0, excluye `asma2k` de `mame.lst`, ejecuta `make -j2 NOWERROR=1`,
valida el ejecutable sin SIGPIPE y instala ASPRO por separado.
Comprueba que el SHA del AS2K instalado no cambie y restaura la fuente
donante al terminar. Resultado en
`~/.local/share/alphasmart/private/aspro/logs/vontar-as2k-method-reuse.status`.

**Evidencia de Vontar:** `STEP=PASS`, `EXIT=0`. Ejecutable instalado:
`/usr/local/libexec/aspro/aspro-bin`, SHA-256
`2c0282172b43cb1d4d33c92d32abe2505a77f99b65bbf36aeb6181e431eb12b1`.

## Surf — postmarketOS ARMv7/musl

Requiere el entorno nativo existente:
`~/Projects/alphasmart/as2k-surf-native/sources/mame-as3k`,
revisión `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`,
GCC/G++, herramientas MAME/GTK3, `sudo -n`, la instalación AS2K
original y ROM/payload privados en las mismas rutas de usuario.

Desde un checkout local de este repositorio en **Surf**:

```sh
sh stable/deploy_surf_native_autonomous.sh
```

El script usa **únicamente Surf**, `make -j1`, sin `make clean`,
`MAKEFLAGS=ARCHITECTURE=`, `PLATFORM=arm`,
`NOASM=1`, `FORCE_DRC_C_BACKEND=1`, `NOWERROR=1`,
`OPTIMIZE=1`. Aplica la adaptación **musl v2** ya comprobada
en AS2K (`bx/platform.h`, `bx/file.cpp`, `bx/thread.cpp`),
restaura los donantes, comprueba ROM/ELF/driver y smoke test,
y después instala el binario y frontend con el instalador
de permisos corregidos.

**Evidencia de Surf:** compilación ARMv7 exitosa, smoke con firmware
Pro exit 0, núcleo instalado idéntico al compilado. SHA-256:
`aa4c96cc8b3c0b5ea61f96622ae354627a69482dc752b1296e6385de7c376223`.
El informe del build original acabó `EXIT=6` **solo por permisos**
del directorio raíz; se repararon y la comparación del ejecutable
instalado PASS. Esto no equivale a un PASS de GUI.
Registro: `~/.local/share/alphasmart/private/aspro/logs/surf-native-build-install.log`.

## Arranque en ambos equipos

El instalador crea
`/usr/local/bin/aspro`,
`/usr/local/libexec/aspro/aspro-bin`,
`/usr/local/libexec/aspro/frontend/`, y
`/usr/local/share/applications/aspro.desktop`.

Abrir desde el menú **ASPRO Emulator** o ejecutar `aspro`.
Se utiliza la configuración privada `~/.config/aspro` y
datos en `~/.local/share/aspro`, sin mezclar AS2K.

## Política de distribución

**NO incluir** firmware, ROM LCD, payload binario, SRAM/NVRAM, claves,
archivos de configuración, capturas ni registros privados en GitHub.
Las huellas SHA sirven para comprobar materiales que el usuario
proporciona separadamente; no representan permiso de redistribución.
Esta publicación distribuye código fuente y scripts nativos, **no los
binarios compilados de cada equipo**.

Para detalles, ver `docs/HANDOFF.md`,
`docs/SURF_NATIVE_MUSL_RECOVERY_20261021.md` y
`stable/RELEASE_MANIFEST.md`.

## Corrección pendiente de integrar (22-oct-2026)

`main` contiene el mapa Pro corregido en
`stable/alphasma.cpp`, sin el error de coma duplicada que impedía
compilar la primera corrección. El framebuffer GTK en
`stable/aspro_ui.py` ahora convierte píxeles mediante bytes y omite
fotogramas repetidos; el botón `Find` se retiró al no tener contacto
Pro identificado.

Verificaciones preparadas:
`python3 tools/test_pro_ui_matrix.py` y
`python3 tools/test_stable_lcd_frontend.py`. La validación local del
fragmento RGB y la prueba aislada de sintaxis del mapa C++ pasaron.
**Aún no se ejecutaron esos dos scripts completos en la máquina y
no se recompiló el núcleo MAME**, por lo que las pruebas interactivas
del nuevo código están pendientes.

**Importante:** los binarios ya instalados en VONTAR y Surf son anteriores
a esta corrección; DIAG permanece inalterado. No usar estos cambios para
declarar que la lentitud del arranque o el editor GTK han quedado resueltos.
