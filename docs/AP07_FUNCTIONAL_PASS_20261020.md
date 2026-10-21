# AP-07 — Aceptación funcional del bootstrap ASPRO-DIAG

Fecha local de ejecución: 20 de octubre de 2026 (archivos de Drive, 21-oct-2026 UTC).
**Resultado: PASS_AP07_DIAG_SCI_RX_TXD_RAM_LCD_BOOT_OK**

## Código y plataforma evaluados

- Repositorio: `SamDelorean/ASPRO-emu`, rama `codex/ap02-aspro-diag-20261019`
- HEAD de producto compilado: `5d174edf12c2ebb92e6f1e6657fff1fa709584e8`
- Binario exclusivo: `build/send-mame/asprodiag` dentro del checkout ASPRO T640
- SHA-256 del binario MAME-DIAG: `1437d66f8f3149f6cf3157df960ddeeb9616535586e75f062fbaf9ecc699a662`
- Payload visual original Pro: 121 bytes, desde `$0040`, final exclusivo `$00B9`, bucle de espera `$008B`
- SHA-256 del payload: `25516cfc116850b4e7ac8b2a54f24137ec3d0250fde5c283b12848bd68517d53`
- Fuente MAME independiente reutiliza el parche D0 existente de AS2K, sin modificar donantes

## Aceptación dinámica MAME-DIAG

Ejecución en la T canónica HP t640; MAME terminado con código 0 en ambos perfiles:
- SCI: sincronización `$FF` observada y 121/121 bytes recibidos con contenido e índices exactos
- Eco TXD 8N1 del MCU modelado: 122/122 ecos verificados, incluido `$FF`
- Cierre de transferencia por reposo de SCI: 40 tiempos de bit, sin error
- Transferencia a RAM: salto a `$0040` registrado; llegada real al PC de bucle `$008B` observada en MAME
- LCD0: `$28,$01,$06,$0C` en secuencia de inicialización, sin error RS; caracteres observados en bus `42 4F 4F 54 20 4F 4B` = **BOOT OK**
- Captura gráfica MAME: se inspeccionó directamente en formato PNG 240x36 y **se lee BOOT OK**; SHA-256 `41921bdd98cdb5418e5451ce967e1e6eb4735d854902f6195c978ef7eab28428`
- Regresión arranque ordinario: código 0, pulsación de A DOWN/UP observada y cambio visual de la captura LCD entre dos SHA-256 diferentes
- Suite estática previa: contrato D0 15/15 PASS; Payload-0-Pro 18/18 PASS; smoke C++ real SCI RX/TXD 5/5 PASS

## Referencias canónicas de evidencia privada

- Informe de máquina: Drive `COMMANDER_PIPELINE/outbox/ASPRO_AP07_campaign.latest.json`
  https://drive.google.com/file/d/18vn5E5ot6k3ylA-SJoQ4MtFytD-ituJR/view
- Pantalla `BOOT OK`: Drive `ALPHASMART/Alphasmart Pro/ASPRO_DIAG_PRIVATE/AP07_bootstrap_bootstrap.png`
  https://drive.google.com/file/d/1OdmpmywqclJAvkLFt2gOVIyph0V9_LLn/view
- Registro de compilación/enlace:
  https://drive.google.com/file/d/1vRXEeKGxfSauaTYGmEmEtQI8xMGNlDtq/view
- Salida final `AP07_JOB_EXIT=0` (sin error):
  https://drive.google.com/file/d/1wfvI3xL4Y-Ta00DtOStyW0MMXEiqO39D/view

## Límite importante

La aceptación **sí** demuestra una implementación funcional en ASPRO-DIAG del
modelo de bootstrap D0 por UART SCI 8N1, eco TXD, RAM y LCD real de MAME.
**No** pretende afirmar que se haya ejecutado bit por bit la ROM interna de
bootstrap del silicio Motorola: el receptor SCI es un modelo de comportamiento,
no una traza de instrucciones de ROM interna. La versión estable, DIAG-ROM-Pro
y OS2K-Pro no fueron modificados. La bandera automática
`visual_review_pass=false` se generó antes de la **revisión visual humana de la
captura exacta cuyo SHA coincide**; esta constancia documenta ese paso manual.

**AP-07 cerrado al alcance diagnóstico solicitado.**
