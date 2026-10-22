# ASPRO-DIAG — única instancia incremental (22-oct-2026)

**Directriz del usuario:** trabajar desde AP02 hasta AP07 y siguientes
sobre **una sola instancia ASPRO-DIAG**, incrementando el mismo producto y
reutilizando pruebas PASS. La creación de motores/copias/árboles por
incremento fue una desviación: se elimina la redundancia y no debe repetirse.

## Instancia única conservada — T canónica HP t640

- Proyecto: `/home/spc/Projects/alphasmart/ASPRO-emu`, rama
  `codex/ap02-aspro-diag-20261019`; checkout fuente conservado.
- **Único árbol de compilación**:
  `/home/spc/Projects/alphasmart/ASPRO-emu/build/send-mame`.
- **Único binario instrumentado**:
  `build/send-mame/asprodiag`; 71.573.008 bytes;
  SHA-256 `1437d66f8f3149f6cf3157df960ddeeb9616535586e75f062fbaf9ecc699a662`.
- Manifiestos: `build/send-mame/.aspro-binary.json`,
  `build/send-mame/.aspro-send-source.json` y marcador AP07
  `.ap07-cpu-marker.json`.
- Estado: AP07 `PASS_AP07_DIAG_SCI_RX_TXD_RAM_LCD_BOOT_OK`,
  **calificado en el alcance registrado**, no afirmación de que
  todo el hardware esté validado.
- Binarios, objetos y cachés **se modifican en ese árbol mismo**
  al avanzar. No crear `build/mame`, `build/prebuilt`,
  `build/send-mame-*` ni exportaciones independientes.
- `ASPRO-STABLE`, `AS2K`, y proyecto `ASPRO_DIAG_ROM` son otros
  productos y quedan expresamente fuera de esta limpieza.

## Redundancia retirada de T (sin eliminar conocimiento)

1. `build/prebuilt`: antiguo ejecutable AP02–AP04 adoptado,
   71.528.800 bytes; SHA-256
   `e55b25dc4540d89c4e292b03a009dd32b4cb396c943aaec9fe3e9dbe828dc7ba`.
   Directorio ~69 MiB. No contiene las ampliaciones AP06/AP07.
2. `build/send-mame.incomplete-20261020`: exportación MAME
   interrumpida de ~293 MiB, sin `makefile` completo ni
   ejecutable AP07 validado.

La documentación AP02–AP07 y su evolución permanecen en Git. Los
informes, observaciones, capturas y campañas con ROM/NVRAM privada
permanecen en Drive y en `ASPRO-emu/private`, **sin tocar**.
No publicar la ROM, LCD ROM, payload binario ni SRAM.
No se conserva una copia extra de ejecutables obsoletos.

Los siguientes entrypoints históricos quedan **bloqueados** para que
no recrean copias: `tools/adopt_engine.py`,
`tools/prepare_mame.py`, `tools/build_diag.sh` y
`tools/ap02_run_once.sh`. Las campañas AP04 y posteriores usan
el único `build/send-mame/asprodiag`. `tools/run_diag.py`
exige esa identidad, el manifiesto exacto y el SHA del binario.

## Flujo canónico de nuevos incrementos

1. Leer el estado vigente Git/Drive, contratos y último resultado
   ejecutado; **no repetir PASS** históricos.
2. Actualizar el driver/CPU y construir incrementalmente en
   `build/send-mame`, usando `tools/build_send_diag.sh` y sus
   overlays/restauraciones ya existentes, sin duplicar árboles.
3. Usar **sólo `asprodiag`** para pruebas instrumentadas.
   Registrar SHA del mismo binario, contrato, prueba, resultado y
   continuidad; Git contiene el conocimiento, Drive la evidencia.
4. Proteger `private/`, binarios Stable, AS2K, T640 y datos de
   usuario de limpiezas no relacionadas. Commander solo con permiso
   explícito y llamadas agrupadas; la eliminación actual no autoriza
   limpiezas futuras fuera de estas dos rutas.

**Estado de esta acta:** registro de la limpieza autorizada. La
comprobación efectiva de borrado y del SHA del único ejecutable
debe constar en el resultado operativo del mismo incremento.
