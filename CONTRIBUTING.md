# Guía para contribuir

Puedes ayudar corrigiendo errores, mejorando la documentación o ampliando las pruebas. Procura que cada propuesta resuelva un problema concreto y sea fácil de revisar.

## Preparar una copia de trabajo

Necesitas Git y una terminal con `sh` y las herramientas POSIX habituales, como `awk`, `sed` y `grep`. En Windows, utiliza **Git Bash**, incluido en Git for Windows. En macOS y Linux puedes usar la terminal del sistema. La suite no requiere instalar paquetes adicionales.

1. Crea una copia del repositorio en tu cuenta con el botón **Fork** de GitHub.
2. Descarga tu copia sustituyendo `TU-USUARIO` por tu usuario de GitHub:

   ```sh
   git clone https://github.com/TU-USUARIO/repo-as-an-agent.git
   cd repo-as-an-agent
   ```

3. Lee [AGENTS.md](AGENTS.md) y ejecuta el diagnóstico, que activa los controles locales de guardado:

   ```sh
   sh .agents/scripts/boot-check.sh
   ```

4. Crea un borrador paralelo para tu propuesta:

   ```sh
   sh .agents/scripts/git-ops.sh draft-create "mi-mejora"
   ```

   Este ejemplo crea el borrador `borrador/mi-mejora`. Puedes elegir otro nombre y usarlo también al subir los cambios.

## Criterios para los cambios

- Conserva la separación entre `workspace/` (documentos del usuario), `knowledge/` (memoria) y `.agents/` (herramientas del asistente). Usa datos ficticios para los ejemplos y las pruebas.
- Mantén los scripts compatibles con POSIX `sh` y respeta los finales de línea LF definidos en [.gitattributes](.gitattributes).
- Si corriges un error, añade una prueba que reproduzca el fallo y verifique la solución en [.agents/tests/run-tests.sh](.agents/tests/run-tests.sh). Mantén las operaciones de prueba en el entorno temporal de la suite.
- No omitas los controles de guardado ni elimines pruebas para ocultar un fallo. Conserva los respaldos previos de las operaciones de restauración y la protección de los archivos excluidos.
- Si cambias la memoria, respeta el perfil YAML y los enlaces descritos en el [README](README.md).
- Actualiza la documentación afectada. Para novedades de comportamiento, añade una sección **Pendiente de publicación** al [CHANGELOG.md](CHANGELOG.md) si aún no existe, sin modificar las entradas de versiones publicadas.

## Ejecutar las pruebas

Desde la carpeta principal del repositorio, ejecuta:

```sh
sh .agents/tests/run-tests.sh
```

La suite prepara una copia temporal aislada para probar los guardados, los borradores, las restauraciones y la validación de memoria. Al terminar debe indicar `FAIL=0` y `TEST_SUITE_VERDICT=PASS`. Un resultado de fallo devuelve un código de salida distinto de cero; revisa las líneas `[FAIL]` y sus detalles antes de enviar tu propuesta.

Si modificaste `knowledge/`, también puedes comprobar directamente su formato y sus enlaces:

```sh
sh .agents/scripts/okf-lint.sh
```

Antes de guardar, comprueba además el formato de los cambios:

```sh
git diff --check
```

El [flujo de GitHub Actions](.github/workflows/tests.yml) ejecuta la misma suite en Linux, macOS y Windows con cada actualización y solicitud de cambios. Consulta sus resultados en la pestaña **Actions**; ejecutar las pruebas localmente ayuda a detectar problemas antes de subirlos.

## Trabajar en la landing

El sitio está en `site/` y sus instrucciones de despliegue en [prompt.md](prompt.md).
Para construirlo necesitas Python 3.9 o posterior, sin paquetes adicionales:

```sh
python -m unittest discover -s tests -p 'test_*.py'
python scripts/build-site.py
python -m http.server 8000 --directory _site --bind 127.0.0.1
```

Abre `http://127.0.0.1:8000` y comprueba escritorio y móvil, ambas guías,
los ejemplos, el mapa de carpetas, los botones de copia y el movimiento reducido.
Puedes verificar la sintaxis con `node --check site/app.js` si tienes Node disponible.
En algunos sistemas el comando de Python es `python3`.

Las pruebas de la landing están en `tests/test_site.py` y también se ejecutan en
GitHub Actions. Si agregas recursos públicos, inclúyelos explícitamente en
`PUBLIC_FILES` de `scripts/build-site.py`. El artefacto `_site/` debe contener solo
la landing y el prompt; conserva fuera los documentos y la memoria del usuario.
El flujo de Pages publica desde `main` después de validar y construir el sitio.

## Guardar y enviar la propuesta

Revisa qué archivos cambiaste y crea un punto de guardado con una nota descriptiva:

```sh
git status --short
sh .agents/scripts/git-ops.sh checkpoint "Explicar la mejora realizada"
git push -u origin borrador/mi-mejora
```

En GitHub, abre una **solicitud de cambios (pull request)** desde tu borrador hacia `main` de `MauricioPerera/repo-as-an-agent`. Incluye:

- El problema que resuelve y el comportamiento resultante.
- Los cambios principales y cualquier limitación relevante.
- Las pruebas ejecutadas y su resultado; si corriges un error, explica cómo lo reproduce la nueva prueba.

Comprueba que las pruebas automáticas pasen en los tres sistemas y atiende los comentarios de revisión.

## Reportar un problema o sugerir una mejora

Abre un [issue](https://github.com/MauricioPerera/repo-as-an-agent/issues) con los pasos para reproducir el problema, el resultado esperado, el resultado observado y el sistema operativo utilizado. Incluye mensajes de error o ejemplos mínimos sin credenciales ni documentos privados.

Puedes consultar la [licencia MIT del proyecto](LICENSE).
