# Surface RT: configuración musl recuperada y adoptada

**Fecha:** 2026-10-21. **Máquina exclusiva de compilación:** Surf,
postmarketOS ARMv7/musl, sin compilación cruzada desde T.

## Evidencia de compilación anterior realmente satisfactoria

Rutas revisadas en la Surface RT:

- `/home/user/Projects/alphasmart/as2k-surf-native/scripts/surface-native-build-musl-v2-20261017.sh`
- `/home/user/Projects/alphasmart/as2k-surf-native/scripts/surface-native-musl-v2-20261017.sh`
- `/home/user/Projects/alphasmart/as2k-surf-native/status/native-musl-v2-20261017.status`:
  `STATUS=PASS`, `STEP=READY`, `AS2K=36996b91053969661371dc067d49026fab367a47`,
  `MAME=1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.
- `/home/user/Projects/alphasmart/as2k-surf-native/status/build.status`: `PASS STEP=READY`.
- Log `/home/user/Projects/alphasmart/as2k-surf-native/logs/pc-host-wakeup-update-20261020.log`
  contiene `BX_MUSL_NATIVE_SYNTAX_PASS`,
  `BX_FULL_LIB_PREFLIGHT_PASS`, y `Archiving libbx.a...`.
- Binario AS2K nativo previamente validado, SHA-256
  `2213e2080846fef14410ebc72561e9eabfd1bdeeb8dbf7aaf741d787f9955de6`.

La primera versión de corrección musl falló; **la segunda, v2, es la aprobada**.
No reutilizar `surface-native-musl-recovery-20261017.sh` v1 en lugar de v2.

## Solución técnica probada (no `-DBX_CRT_NONE=0` aislado)

La v2 preparaba copia temporal del constructor, respaldo de archivos de la
fuente donante MAME y corrección transitoria exacta de:

1. `3rdparty/bx/include/bx/platform.h`: declarar `BX_CRT_MUSL`,
   seleccionarlo en Linux sin `__GLIBC__`, excluir musl de
   `BX_CRT_NONE`, e identificar el nombre `musl libc`.
2. `3rdparty/bx/src/file.cpp`: alias POSIX
   `fseeko64=fseeko` y `ftello64=ftello` para musl.
3. `3rdparty/bx/src/thread.cpp`: incluir `<sys/prctl.h>` solo
   en `BX_CRT_MUSL && BX_PLATFORM_LINUX` (nunca duplicar
   `linux/prctl.h`).

Preflight antes de compilación extensa: preprocess de `bx/platform.h`
que verifica `BX_CRT_NONE==0 && BX_CRT_MUSL==1`, ABI `off_t` de 64 bits,
y `c++ -fsyntax-only` de `crtnone.cpp`, `file.cpp` y `thread.cpp`.
La v2 original compiló `libbx.a` explícitamente en `mameas2k`.
La compilación ASPRO genera un subtarget diferente (`mameaspro`);
**no reutilizar el Makefile de AS2K para enlazar ASPRO**.

Entorno restante exacto: `MAKEFLAGS=ARCHITECTURE=`, `PLATFORM=arm`,
`NOASM=1`, `FORCE_DRC_C_BACKEND=1`, `OPTIMIZE=1`,
`NOWERROR=1`, `REGENIE=1`, `-j1`; evitar limpieza total;
preservar configuración, ROM/NVRAM, caché de objetos y fuente original.

## Corrección publicada

- Rama `release/aspro-stable-vontar-surf-20261021`
- Script `stable/deploy_surf_native_autonomous.sh`
- Commit `a1b496a60031c526aa6d334e5576dd17b1f2ba8f`.
- Integra la adaptación v2 en tres archivos, respaldados y
  restaurados mediante el mismo trap que ya manejaba los fuentes HC11
  y driver, y añade preflight antes del `make -j1`.

**Estado:** reparación de código fuente preparada y documentada.
**NO** se lanzó otra compilación ASPRO, no hay PASS del nuevo ASPRO ni
instalación verificada. El último registro ASPRO continuaba en
`COMPILE_NATIVE_ARMV7_J1 / EXIT=2` por `crt0.h`.
Este antecedente AS2K PASS demuestra la compatibilidad del entorno
y la solución de `bx`, pero no prueba por sí solo el nuevo driver ASPRO.
