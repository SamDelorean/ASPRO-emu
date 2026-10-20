# AP-04 — F1–F8 y persistencia NVRAM, cierre funcional emulado

**Fecha:** 2026-10-20. **Estado:** `F1_F8_TEXT_AND_REBOOT_RECOVERY_VISUAL_PASS` (alcance exacto de esta campaña). Sólo `ASPRO-DIAG / asmapro`; no implica PASS global de firmware, hardware físico, teclado completo, impresión o apagado energético.

## Origen y reglas

Plan AP-03: tras demostrar el arranque hasta el editor y la introducción de `a`, comprobar F1–F8 y contenido retenido tras cerrar y volver a iniciar ASPRO-DIAG. Instrumentación probada `as2kdiag` reutilizada como ejecutable copiado `ASPRO-emu/build/prebuilt/asprodiag`; **no recompilar ni modificar AS2K**. ROM y CGROM exclusivamente privadas. Commander T640 canónica en 2 llamadas de lanzamiento autorizadas, sin polling ni exploración.

- Motor SHA256 `e55b25dc4540d89c4e292b03a009dd32b4cb396c943aaec9fe3e9dbe828dc7ba`.
- ROM Pro 2.1.2 SHA256 `286000f3ffdd4802b4b1446032e108300c1fd6df7386c731b36dba00aef2d99e`.
- LCD KS0066 F05 SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- Árbol de trabajo de producto (ejecución final): `67c1efab423171e744060e549b1ab1253d01592b`, rama `codex/ap02-aspro-diag-20261019`. No PR.
- Scripts `tools/ap04_files_observe.lua`, `tools/ap04_campaign.py`, `tools/ap04_run_once.sh`. Sintaxis shell/Python PASS en T; sin cambios a motor.
- [Lanzamiento real](https://drive.google.com/file/d/1vmjl3rzJ2jsWWNvmwNBAl-7_G3-1r0_c/view): `ASPRO_AP04_EXT_STATIC_SYNTAX_PASS`, `AP04_RUNNER_EXIT=0`, `AP04_RESULTS_IN_DRIVE=YES`, `ASPRO_AP04_EXT_LAUNCH_EXIT=0`.

## Primera corrida, temporización insuficiente

`campaign-4lj_l3kx`: dos sesiones de ocho selecciones; el programa terminó (`exit=0`) pero las capturas se hicieron tras aproximadamente 1,5 s de abrir el archivo y mostraban `Opening File N....`. Cada PNG de primera sesión coincidía con su equivalente del reinicio, pero **no validaba texto ni persistencia de contenido**. No repetirla ni promoverla a PASS.

Se corrigió únicamente el período de apertura; a cada F1–F8 se le reservan ~13 s antes del siguiente archivo, se toma snapshot `ready_fN` antes de escribir y luego `fN` después. No se modifica firmware, driver MAME ni NVRAM de AS2K.

## Campaña corregida (única corrida final)

`campaign-r29tga0_`: fase `write` y fase `verify`, dos procesos MAME reales independientes con directorio `nvram` común al experimento. Cada fase finalizó con **exit 0**, `OBSERVATION_COMPLETE` verdadero y **8/8 PNG válidos**. Entradas ROM temporales eliminadas (`inputs_cleanup=COMPLETE`). En fase `write`, teclas F1–F8 seleccionadas y caracteres respectivos insertados; en fase `verify`, después de salir de MAME y reiniciar el binario, se abrieron los mismos ocho archivos **sin volver a teclear letras**.

La inspección visual confirmó un carácter correcto en la primera posición del editor, seguido del cursor, para cada archivo. **Las ocho parejas de capturas write/verify son exactamente iguales por SHA256**, no sólo semejantes. Las imágenes `ready` permiten distinguir un editor abierto de la pantalla transitoria `Opening File N....`.

| Archivo | Caracter escrito | Captura write | Captura verify |
|---|---|---|---|
| F1 | a | [write](https://drive.google.com/file/d/1AyzSp-sl0q9PRtiPkb0MBvan1lGLPtIG/view) | [verify](https://drive.google.com/file/d/1QYA5waZ6u3HGygVEO7UwHq6gbt04b0Ap/view) |
| F2 | b | [write](https://drive.google.com/file/d/1KlvfAL2wlT65PxSffvMZhrFF5wsxlGcE/view) | [verify](https://drive.google.com/file/d/1q3LcO4gvYtgfmMaWP_cUWL61K9vr6s7t/view) |
| F3 | c | [write](https://drive.google.com/file/d/1w-79nldkfLmx_9xKyFbrHN2ugpJYeNE9/view) | [verify](https://drive.google.com/file/d/1rcUCDL4SlNbwIbBXQSCzqTvMaujATq5F/view) |
| F4 | d | [write](https://drive.google.com/file/d/1f6F_Y3arDKDosJoqyZ5PeTStg-6wUQvm/view) | [verify](https://drive.google.com/file/d/10Scak9-wlzzsVlOgEX-jt3Wk1TGFoJEc/view) |
| F5 | e | [write](https://drive.google.com/file/d/16tPqDu8KI6rQPz8wFKTJ1YsJNTBi9qkE/view) | [verify](https://drive.google.com/file/d/1wMZUtOgcX6tjJYeJVyDPLwbQaIH646wx/view) |
| F6 | f | [write](https://drive.google.com/file/d/1J7Nkg6_dpjCgKG6A-rB46LyOQZK-1MGQ/view) | [verify](https://drive.google.com/file/d/1Bep0JOwdEpOnEwi5LJzNWuDFm2TrzEJR/view) |
| F7 | g | [write](https://drive.google.com/file/d/1utruqinOTZOZrjT6ng1VkCd6TkmPVggJ/view) | [verify](https://drive.google.com/file/d/1C66Wg4d5_shGky1EP94yi1Ke0ctrWt1O/view) |
| F8 | h | [write](https://drive.google.com/file/d/1AZKJ9p9eTztAhrZ0oSMemFWEYsdS38G2/view) | [verify](https://drive.google.com/file/d/15Iy1OhC4x7XA6CXz4ZwH396uQ1K8yEgW/view) |

Ejemplo de foto antes de teclear, con F1 vacío y el cursor: [ready F1](https://drive.google.com/file/d/17Jc0EynYMRXCyceWCfHKqQFTUUA1VRPn/view). Las restantes siete están en la misma [carpeta privada](https://drive.google.com/drive/folders/1q52Cx-DFixfmGrPJ9DIRGma4Q79yGHX1).

### Persistencia NVRAM real

- Archivo privado `asmapro/nvram` de **131072 bytes** tras ambas sesiones.
- SHA256 NVRAM al finalizar la primera sesión: `03637f7fc8305be3c7065f795ed762dca4f6bcaf12cc2445bd1819229a2115cd`.
- SHA256 NVRAM al finalizar la segunda sesión: `4daad301f0749160e8451ce0c5140c62ab09dfed2c327b0e994b9965e3a5ee89`.
- Los hashes de NVRAM **son diferentes**. No confundir esta diferencia binaria con pérdida de contenido: la prueba determinante es que los ocho textos se recuperaron visualmente sin reescritura, y las ocho capturas write/verify son idénticas por SHA.
- La SRAM respaldada es almacenamiento privado de la emulación, **no** prueba de retención eléctrica con batería.

### Archivos de evidencia y validez

[Informe JSON privado](https://drive.google.com/file/d/1ELvKLvj9O8TQPlb5I0G_efdQwUJbnj8b/view), [marcadores write](https://drive.google.com/file/d/1nxefZD1Wa--p1MDjenaDP1HFt_z2hRlg/view), [marcadores verify](https://drive.google.com/file/d/1lWE_XWKUaHfE1kDcSTDBaXlBNpg-cIc_/view), [lanzamiento](https://drive.google.com/file/d/1vmjl3rzJ2jsWWNvmwNBAl-7_G3-1r0_c/view). Capturas con contenido sintético bajo carpeta privada; sin ROM/NVRAM en GitHub.

El runner automático indica `functional_pass:false` y `TWO_SESSIONS_CAPTURED_PENDING_VISUAL_QUALIFICATION` por diseño: no implementa OCR ni decodificador de LCD. **El PASS declarado aquí procede de la inspección visual de los caracteres y de los hashes exactos por archivo tras el reinicio**, no de reinterpretar automáticamente el booleano del runner.

## Cierre / siguiente decisión

AP-02 motor + AP-03 arranque/teclado + AP-04 ocho archivos/persistencia quedan calificados en su alcance. No repetir pruebas HC11, bancos, LCD, arranque, tecla A, F1–F8 ni persistencia de este caso sin evidencia contradictoria. A partir de aquí el usuario decide si integra ASPRO al proyecto AS2K o mantiene ASPRO independiente. **No crear ASPRO-STABLE, no modificar AS2K ni adelantar la decisión de arquitectura.**
