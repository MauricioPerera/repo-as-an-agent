# Historial de cambios

Novedades y correcciones de las versiones publicadas de Repo-as-an-Agent.

## Pendiente de publicación

### Añadido

- Primera fase de la batería adversarial: observador independiente de archivos
  con dos controles ficticios, contrato externo fijado por una huella, tres
  canarios, capturas y evidencias verificables. Distingue PASS, FAIL y ERROR sin
  ejecutar código de las copias ni acreditar aislamiento del sistema operativo.
- Controles positivos y negativos del observador en Linux, macOS y Windows,
  integrados en GitHub Actions sin paquetes nuevos. Guía de uso, límites y
  correspondencia con el plan adversarial; los 60 escenarios y las campañas
  reales de agentes siguen pendientes.
- [Sección de evaluaciones e intentos de v1.3.0 en la landing](https://mauricioperera.github.io/repo-as-an-agent/#evaluaciones), con ejemplos interactivos de `exito`, `fallo` e `interrumpido`, sus observaciones, informes y vínculos al contexto y a la evidencia guardada. Los desenlaces conservan la separación respecto a los cuatro estados de tarea.
- Diagrama de los cuatro momentos de guardado: contexto, inicio del intento, informe con el intento abierto y desenlace. Tres ejemplos de evaluación explican el respeto de la referencia, la evidencia insuficiente y el cambio de alcance, con sus resultados observables y límites.
- Cuatro botones de copia para pedidos y comandos de intentos y evaluación, con acceso a la guía y a v1.3.0. Pruebas de navegación por teclado, vínculos históricos ilustrativos, portapapeles y adaptación entre 320 y 1280 px en escritorio y móvil emulado.

### Actualizado

- Cabecera, navegación y acceso principal para destacar las evaluaciones e intentos; se conserva la última versión y su enlace generados automáticamente durante la publicación de Pages.
- Resumen de las pruebas del motor: 158 comprobaciones por sistema. La documentación distingue los 18 controles simulados del evaluador de la evaluación de un agente real.
- Validación del sitio para detectar destinos inexistentes o vacíos en botones de copia y controles de paneles. El motor y el gestor conservan sus requisitos y dependencias.

### Verificación

- Suite de **36 controles del observador adversarial**, con positivos y negativos
  simulados. Las capacidades de archivos no disponibles se enumeran como SKIP,
  sin acreditarlas como pruebas aprobadas ni evaluación de un modelo.
- **52 pruebas con Playwright**, incluidas **18 nuevas**, y **18 pruebas del sitio**, aprobadas localmente. Los botones se contrastan con el contenido real del portapapeles y el diseño se comprueba entre **320 y 1280 px**.

## [v1.3.0] - 2026-10-24

Evaluaciones observables del comportamiento del agente y registro de intentos
de ejecución con contexto, desenlaces y evidencias históricas recuperables.

### Añadido

- Registro opcional de intentos por tarea mediante `attempt-start`, `attempt-finish`
  y `attempts`: agente, acción, herramienta, inicio y fin en UTC y contexto guardado.
  Cada intento finaliza con `exito`, `fallo` o `interrumpido` y un informe histórico.
  Un intento abierto impide terminar la tarea; su desenlace no cambia estados ni
  verifica criterios automáticamente. Los reintentos conservan los registros anteriores.
- Evidencias vinculadas a puntos de guardado inmutables que contienen el informe
  y el inicio original del intento. Se rechazan archivos inexistentes, puntos
  anteriores al inicio y contextos incompatibles. El historial incluye los puntos
  de los intentos, también sin asociación explícita; las restauraciones con respaldo
  y los borradores paralelos conservan los registros. Cambiar el acuerdo ADD mantiene
  los intentos con su contexto original.
- Evaluador de comportamiento con tres escenarios aislados y datos ficticios:
  respeto de la referencia, evidencia insuficiente y cambio de alcance. Comprueba
  resultados observables mediante el evaluador original y las entregas guardadas,
  sin copiar datos del usuario, llamar modelos ni añadir dependencias.
- Regresiones de intentos, controles simulados correctos e incorrectos del evaluador
  y ejecución de ambas suites en Linux, macOS y Windows mediante GitHub Actions.
- [Guía de uso y límites](docs/evaluaciones-e-intentos.md), instrucciones para agentes
  y documentación para usuarios y colaboradores. Se conservan los cuatro estados
  y la compatibilidad con tareas anteriores.

### Verificación y compatibilidad

- **102 pruebas del gestor**, incluidas **28 del registro de intentos**, y **18 controles
  del evaluador** con respuestas simuladas correctas e incorrectas.
- **158 comprobaciones del motor por sistema**: 38 generales, 102 del gestor y 18
  del evaluador, aprobadas en Linux, macOS y Windows. Además, **16 pruebas de la
  landing** y **34 con Playwright** en escritorio y móvil emulado.
- Se mantienen los estados **pendiente**, **en curso**, **bloqueada** y **terminada**,
  el piloto ADD y las tareas anteriores, con cero dependencias nuevas.

Los controles de CI verifican la infraestructura con resultados simulados. Para
evaluar a un agente real, se le entrega el pedido de cada escenario y se comprueban
sus resultados desde el evaluador original. La existencia de un informe no certifica
la veracidad de su contenido ni toda la actuación del agente.

## [v1.2.1] - 2026-10-23

Guía visual del piloto ADD en la landing y acceso directo desde el README.

### Añadido

- [Sección del piloto ADD de v1.2.0 en la landing](https://mauricioperera.github.io/repo-as-an-agent/#add), con ejemplos de referencia acordada, evidencias por criterio y cierre, un diagrama de puntos de guardado, pedidos y comandos copiables y enlaces a la guía y a la versión.
- Enlace directo desde la sección del piloto ADD del README a la nueva guía visual.
- Comprobaciones de navegación y copia del ejemplo ADD en escritorio y móvil mediante Playwright.

### Actualizado

- Cabecera, navegación y acceso principal de la landing para destacar ADD, conservando la versión estable y su enlace generados automáticamente al publicar GitHub Pages.

### Verificación

- **34 pruebas con Playwright**, incluidas **ocho nuevas** para el ejemplo ADD, sus vínculos y los tres botones de copia en escritorio y móvil emulado. La copia se contrasta con el contenido real del portapapeles.
- **16 pruebas de la landing** y **112 comprobaciones del motor por sistema**: 38 generales y 74 del gestor en Linux, macOS y Windows. El gestor mantiene sus cuatro estados y no añade dependencias.
- Diseño comprobado entre **320 y 1280 px**, sin desbordamientos horizontales. El enlace del README se verifica desde GitHub y sitúa la página al inicio de la sección ADD.

## [v1.2.0] - 2026-10-23

Piloto opcional de desarrollo guiado por artefactos (ADD): conectar la referencia acordada con las evidencias de entrega mediante puntos de guardado recuperables. Consulta la [guía del piloto](docs/piloto-add.md).

### Añadido

- Piloto ADD opcional por tarea: referencia acordada y evidencias de entrega por criterio, con archivos vinculados a puntos de guardado inmutables mediante `agree` y `deliver`. Mantiene los cuatro estados y las tareas anteriores, sin dependencias adicionales.
- Validación de artefactos históricos regulares no vacíos y de la relación entre los puntos de referencia y entrega, también al guardar archivos preparados o editados manualmente. Cambiar el acuerdo retira las verificaciones anteriores; retirar un criterio retira su entrega.
- Historial ampliado con los puntos de los artefactos actuales, guía del piloto y regresiones para cierre, reaperturas, restauraciones y borradores paralelos.

### Actualizado

- Cabecera de la landing con la última release estable y su enlace generados durante la publicación de Pages; se actualiza al publicar una release y usa las versiones del repositorio actual. Las copias sin releases muestran «Ver versiones».
- Pruebas con Playwright en escritorio y móvil emulado para los cuatro estados, evidencia y resultado de cierre, navegación por teclado y todos los botones de copia, incluido `prompt.md` y los casos de copia denegada.
- Regresiones de la versión automática para repositorios nuevos, etiquetas escapadas y fallos de la API. Un fallo de consulta detiene el despliegue y conserva la publicación anterior.
- Entorno de pruebas del navegador aislado en `tests/browser/`, con dependencias fijadas y ejecución en GitHub Actions. El gestor mantiene sus requisitos de Git y herramientas POSIX, sin paquetes adicionales.

### Pruebas

- **74 pruebas del gestor**, incluidas **40 nuevas para ADD**: referencias y evidencias válidas, rechazo de archivos o puntos inexistentes, cierre por criterio, cambios de acuerdo, historial y recuperación.
- **112 comprobaciones del motor** por sistema: 38 generales y 74 del gestor, ejecutadas en Linux, macOS y Windows.
- **16 pruebas de la landing** y **26 pruebas con Playwright** en escritorio y móvil emulado.

La validación comprueba los archivos guardados y sus vínculos históricos. La conformidad del contenido con lo acordado requiere la revisión del agente o de la persona responsable.

## [v1.1.1] - 2026-10-23

Guía visual del gestor de tareas y acceso directo desde el README.

### Añadido

- [Sección de tareas en la landing](https://mauricioperera.github.io/repo-as-an-agent/#tareas) con ejemplos interactivos de los estados **pendiente**, **en curso**, **bloqueada** y **terminada**.
- Ejemplos de avance parcial, motivo de bloqueo y cierre con evidencia por criterio y resultado escrito.
- Diagrama de puntos de guardado que explica cómo vincular avances a una tarea y por qué guardar no la termina automáticamente.
- Cuatro pedidos copiables para el agente y una guía técnica desplegable con comandos copiables, navegación por teclado y diseño adaptable a escritorio y móvil.
- Enlace directo desde la sección de tareas del README a la nueva guía visual de la landing.

### Actualizado

- La cabecera de la landing destaca el gestor incorporado en v1.1.0 y la página muestra las **72 comprobaciones del motor**: 38 generales y 34 del gestor de tareas.

### Verificación

- Estados, contenido de cierre y los cinco botones de copia comprobados en escritorio de **1280 px** y vista móvil de **390 px**, sin desbordamientos horizontales.
- Enlace del README comprobado desde GitHub: abre la landing y sitúa la página al inicio de la sección de tareas.
- Pruebas generales y del gestor aprobadas en Linux, macOS y Windows; siete pruebas de la landing, validación de JavaScript y construcción pública aprobadas.

## [v1.1.0] - 2026-10-23

Seguimiento de tareas con evidencia y puntos de guardado, junto con una landing para aprender a usar la plantilla.

### Añadido

- Gestor local de tareas en Markdown, sin dependencias adicionales, con un archivo por tarea en `workspace/documentos/tareas/`.
- Estados **pendiente**, **en curso**, **bloqueada** y **terminada**. El bloqueo y la reapertura de una tarea terminada requieren un motivo.
- Criterios de aceptación con evidencia registrada por criterio y resultado obligatorio al cerrar. Se rechazan los cierres con criterios pendientes o sin evidencia; un criterio reabierto debe verificarse de nuevo.
- Vínculos `Task-ID` entre tareas y puntos de guardado: un punto puede asociarse a varias tareas y una tarea puede tener varios puntos. Guardar avances no cambia el estado ni termina la tarea automáticamente.
- Historial por tarea en el borrador actual, incluidos avances en otros archivos, restauraciones con respaldo y consultas después de retirar el archivo de tarea.
- Habilidad `task-manager`, documentación de uso y controles que validan las tareas preparadas al guardar, también cuando se editan manualmente.
- Landing en GitHub Pages con guías para usuarios técnicos y no técnicos, diagramas, ejemplos interactivos, navegación por teclado y animaciones con pausa y movimiento reducido.
- [Prompt de despliegue](prompt.md) listo para copiar a un agente y publicar la landing en una copia del template.
- Constructor con una lista explícita de archivos públicos y siete pruebas para enlaces, rutas de proyecto y exclusión de documentos privados.
- Flujo de publicación automática de Pages y validación de la landing en el flujo de pruebas existente.

### Pruebas

- **34 pruebas del gestor de tareas** para estados, bloqueos, evidencia de cierre, reaperturas, vínculos a puntos de guardado, historial, restauraciones y borradores paralelos.
- **72 pruebas aprobadas y 0 fallos en cada sistema**: las 38 pruebas generales y las 34 del gestor se ejecutan en Linux, macOS y Windows mediante GitHub Actions.
- **Siete pruebas de la landing**, además de la validación de JavaScript y la construcción de los archivos públicos.

## [v1.0.0] - 2026-10-23

Primera versión estable de la plantilla.

### Añadido

- Instrucciones para asistentes de IA en `AGENTS.md` y `CLAUDE.md`, con comunicación en lenguaje sencillo y separación entre documentos, memoria y herramientas del asistente.
- Memoria estructurada en `knowledge/`, con índice, perfil del espacio y bitácora de conocimiento.
- Procedimientos de bienvenida, versionado seguro, curaduría de memoria y asistencia documental.
- Scripts para crear puntos de guardado, trabajar con borradores paralelos, conciliar cambios y restaurar versiones con respaldo previo.
- Controles de guardado para archivos sensibles, archivos mayores de 50 MiB, marcadores de conflicto y memoria inválida.
- [Flujo de GitHub Actions](.github/workflows/tests.yml) que ejecuta la suite en Linux, macOS y Windows con cada actualización y solicitud de cambios, además de permitir su ejecución manual.
- Insignias del estado de las pruebas y de la licencia MIT en el README.

### Corregido

- Las restauraciones se detienen antes de sobrescribir archivos locales excluidos del respaldo, incluidas las colisiones entre archivos y carpetas. Los archivos excluidos sin colisión se conservan y los posibles secretos permanecen fuera del rescate.
- El control de guardado valida la versión preparada y sus enlaces, incluidas las eliminaciones de archivos obligatorios. Los cambios que solo existen en disco no ocultan errores ni bloquean una versión preparada válida.
- La validación del perfil YAML detecta comillas y listas sin cerrar, escapes inválidos, claves duplicadas, campos obligatorios nulos y caracteres de control. Las estructuras fuera del perfil admitido se rechazan con un diagnóstico.
- El tratamiento de texto UTF-8 es consistente entre Linux, macOS y Windows.

### Pruebas

- Suite de **38 pruebas**, incluidas **22 pruebas de regresión** para las correcciones.
- Resultado de la versión publicada: **38 pruebas aprobadas y 0 fallos en cada uno de los tres sistemas**.
- [Ejecución verificada de v1.0.0](https://github.com/MauricioPerera/repo-as-an-agent/actions/runs/39908134186).

### Licencia

- Distribución bajo la [licencia MIT](LICENSE).
- Copyright (c) 2026 Mauricio Perera.

[v1.2.1]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.2.1
[v1.2.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.2.0
[v1.1.1]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.1.1
[v1.1.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.1.0
[v1.0.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.0.0
