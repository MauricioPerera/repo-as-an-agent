# Guía para contribuir

Puedes ayudar corrigiendo errores, mejorando la documentación o ampliando las pruebas. Procura que cada propuesta resuelva un problema concreto y sea fácil de revisar.

## Preparar una copia de trabajo

Necesitas Git y una terminal con `sh` y las herramientas POSIX habituales, como `awk`, `sed` y `grep`. En Windows, utiliza **Git Bash**, incluido en Git for Windows. En macOS y Linux puedes usar la terminal del sistema. Las suites del motor y del gestor no requieren instalar paquetes adicionales. Las pruebas del navegador tienen un entorno de desarrollo separado, descrito más abajo.

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
sh .agents/tests/run-task-tests.sh
sh .agents/tests/run-agent-eval-tests.sh
sh .agents/tests/run-adversarial-tests.sh
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

La suite de tareas está en `.agents/tests/run-task-tests.sh`, usa un repositorio
temporal independiente y debe terminar con `FAIL=0` y `TASK_TEST_VERDICT=PASS`.
Si cambias el gestor, añade regresiones allí. Comprueba tanto el Markdown local
con `sh .agents/scripts/tasks-lint.sh` como los archivos preparados con
`sh .agents/scripts/tasks-lint.sh --staged`. Conserva la comprobación de evidencia,
los respaldos de restauración y la compatibilidad con borradores paralelos.

El piloto ADD se cubre en `.agents/tests/task-add-cases.sh`, incluido por la misma
suite del gestor. Conserva las tareas antiguas y los cuatro estados. Prueba
referencias y entregas guardadas, rutas y puntos inválidos, archivos históricos
regulares, ediciones manuales, la versión preparada frente a la local, reaperturas,
restauraciones y worktrees. Los casos usan archivos ficticios dentro de la copia
temporal; no crees tareas de prueba en el template ni dependencias de Node/Python
para el gestor. El flujo de uso está en [la guía ADD](docs/piloto-add.md).

Las regresiones de intentos están en `.agents/tests/task-attempt-cases.sh`,
incluidas por la suite del gestor. Conserva la separación entre desenlace de
intento y estado de tarea, el contexto inicial guardado, el informe histórico,
las versiones preparadas, las restauraciones y los borradores paralelos.

`.agents/tests/run-agent-eval-tests.sh` comprueba el evaluador con entregas
**simuladas**, positivas y negativas, en copias temporales con datos ficticios.
Debe terminar con `AGENT_EVAL_TEST_VERDICT=PASS`. Se ejecuta en los tres sistemas
en CI, sin llamadas a modelos. No presentes esos resultados como una medición
del comportamiento de un agente real. Para esa evaluación, entrega a un agente
el pedido de una copia preparada y aplica `check` desde el repositorio original,
según la [guía de evaluaciones e intentos](docs/evaluaciones-e-intentos.md).

La suite `.agents/tests/run-adversarial-tests.sh` comprueba el observador de la
[primera fase adversarial](docs/observador-adversarial.md) con controles simulados.
Debe indicar `ADVERSARIAL_TEST_VERDICT=PASS` y enumerar por separado las capacidades
omitidas como SKIP. Prueba la huella externa del contrato, los canarios, la captura,
los códigos PASS/FAIL/ERROR y la integridad de las evidencias. No ejecutes código
de la copia evaluada ni publiques capturas privadas en artefactos de CI o Pages.
El flujo ejecuta estos controles en un trabajo separado por sistema operativo;
no se añaden dependencias ni estados al gestor y no se llama a modelos.

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
El constructor comprueba también los destinos de los botones de copia y los
paneles enlazados mediante `aria-controls`; actualiza sus identificadores juntos.
El flujo de Pages publica desde `main` después de validar y construir el sitio.
También se ejecuta al publicar una release: solicita otra ejecución desde la rama
predeterminada y consulta la última release estable mediante `--fetch-release`.
El trabajo que solicita esa ejecución tiene `actions: write`; la construcción
mantiene `contents: read`. Así se conserva la protección de Pages que permite
publicar desde la rama principal y no desde etiquetas. No escribas el
número de la última versión a mano en `site/index.html`; conserva el espacio
`release:start` / `release:end`. Las menciones a la versión en la que se añadió
una función son contenido histórico y se mantienen.

Para probar la cabecera con releases reales, ejecuta:

```sh
python scripts/build-site.py --fetch-release --repository PROPIETARIO/REPOSITORIO
```

La construcción normal funciona sin red y muestra «Ver versiones». Si la API no
encuentra releases también se usa ese enlace; otros errores detienen la publicación.
En Actions se usa el permiso `contents: read` del token de la ejecución. No copies
tokens al código ni al HTML generado.

### Pruebas de navegador con Playwright

Necesitas Node.js 22 o posterior y Python. Desde la raíz:

```sh
cd tests/browser
npm ci
npx playwright install chromium
npm test
```

En Linux, si faltan bibliotecas del sistema, usa
`npx playwright install --with-deps chromium`, como hace GitHub Actions.
Si tu intérprete se llama `python3`, ejecuta `PYTHON=python3 npm test` desde Git Bash,
macOS o Linux. La suite construye la landing antes de iniciar su servidor local,
solo expone los archivos públicos y prueba la ruta `/repo-as-an-agent/`.

Los proyectos `escritorio` (1280 × 900) y `movil` (390 × 844, con emulación táctil)
verifican los cuatro estados, criterios pendientes y verificados, motivo de bloqueo,
evidencia y resultado de cierre, navegación por teclado y ausencia de desbordamiento.
Cubren también los tres desenlaces de intento (`exito`, `fallo`, `interrumpido`),
sus vínculos a los cuatro momentos de guardado, los tres escenarios del evaluador
y los pedidos y comandos copiables de la sección de v1.3.0. El diseño se comprueba
entre 320 y 1280 px. Los ejemplos de la landing son ilustrativos: no ejecutan un
agente ni modifican archivos o tareas reales.
La sección del observador de v1.4.0 añade ejemplos ficticios de los tres canarios,
PASS/FAIL/ERROR, navegación del contrato y las evidencias, tres botones de copia
y límites de aislamiento visibles. Conserva la separación entre una demostración
web, los controles simulados de infraestructura y una campaña real de agentes.
Los contratos, canarios y capturas de los ensayos permanecen fuera de `_site/`.
Comprueban el contenido real copiado por todos los botones, incluidos los ejemplos
técnicos y `prompt.md`, y las alternativas cuando el navegador deniega la copia.
Se ejecutan en serie para evitar interferencias entre portapapeles.

Puedes ejecutar un solo tamaño con `npm test -- --project=movil` y consultar el
informe con `npm run report`. Ante un fallo se conservan capturas y trazas en
`tests/browser/test-results/`; abre una traza con
`npx playwright show-trace RUTA/trace.zip`. Esos archivos, el informe HTML y
`node_modules/` quedan excluidos del repositorio y de Pages.
Si falla el trabajo de navegador en GitHub Actions, su artefacto
`diagnostico-playwright` conserva el informe y las trazas durante siete días.

`package.json` y su archivo de bloqueo solo pertenecen a las pruebas de desarrollo.
El motor en `.agents/`, el gestor y la landing publicada mantienen sus requisitos
anteriores. No añadas Playwright a sus scripts de ejecución ni a sus recursos públicos.

## Segunda fase adversarial del motor

Consulta la [cobertura y los límites](docs/adversarial-fase2.md) antes de añadir
variantes. Usa controles válidos y negativos con códigos y causas comprobados;
un error de herramientas no es un ataque rechazado. Ejecuta:

```sh
sh .agents/tests/run-adversarial-engine-tests.sh run
```

Conserva el directorio y la huella devueltos para ejecutar `verify` y
`check-engine-evidence.sh`. Las siete filas son escenarios con varias aserciones,
no siete modelos evaluados ni los 60 escenarios del catálogo. Los informes son
privados y no se adjuntan automáticamente a CI. No copies datos humanos al ensayo
ni conviertas las regresiones existentes en nuevos conteos.

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
