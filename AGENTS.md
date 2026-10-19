# ASPRO-emu — directiva máxima

1. **Único workspace: ASPRO-emu**, con entorno de compilación y artefactos aislados. AS2K y su MAME reducido son exclusivamente una **referencia de código de lectura**, no un entorno donde se trabaje, compile, borre o escriba. Reutilizar las implementaciones probadas sin reconstruir CPU, LCD, teclado ni infraestructura.
2. Único emulador autorizado para toda ejecución experimental: ASPRO-DIAG, **nunca** estable o MAME genérico. No crear ASPRO-STABLE ni ampliar AS2K hasta que el usuario elija explícitamente entre integración o producto separado, después de validar DIAG.
3. STATIC_FIRST, pero no gates artificiales ni división de un incremento coherente en microtareas. Desarrollar todo lo viable antes de gastar una intervención remota.
4. Commander: T640 canónica, ID dee0b4b6-578a-41a5-88de-73dbeb808983. No ejecutar sin autorización expresa para intervención concreta, max. 3 llamadas salvo excepción expresa. Drive primero, scripts autónomos, SIN polling.
5. Evidencia de compilación != PASS de ROM. Éxito del launcher != éxito funcional. Requiere prueba auténtica del HC11 y LCD/teclado cuando se declare funcional.
6. Mantener ROM/NVRAM/trazas privadas FUERA de Git. No alterar MAME ni instalaciones AS2K existentes. No copiar código propietario.
7. Ante un error, diagnosticar diferencia concreta, no reabrir infraestructura calificada ni improvisar nueva arquitectura. Registrar SHA, fuente, instrumento, resultado, pendientes.
8. Si Codex informa `gpt-5.5 is not supported ... with a ChatGPT account`, seleccionar modelo **Predeterminado** o disponible en el cliente Codex antes de reintentar; no colocar modelo dentro de prompts ni inventar que el repositorio cambia esa configuración.
9. No desplegar en Vontar o Surface hasta comprobar el núcleo en DIAG y reutilizar la cadena de compilación cruzada existente. No rehacer ese entorno.
