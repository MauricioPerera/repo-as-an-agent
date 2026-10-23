# Historial de cambios

Novedades y correcciones de las versiones publicadas de Repo-as-an-Agent.

## Pendiente de publicación

### Añadido

- Piloto ADD opcional por tarea: referencia acordada y evidencias de entrega por criterio, con archivos vinculados a puntos de guardado inmutables mediante `agree` y `deliver`. Mantiene los cuatro estados y las tareas anteriores, sin dependencias adicionales.
- Validación de artefactos históricos regulares no vacíos y de la relación entre los puntos de referencia y entrega, también al guardar archivos preparados o editados manualmente. Cambiar el acuerdo retira las verificaciones anteriores; retirar un criterio retira su entrega.
- Historial ampliado con los puntos de los artefactos actuales, guía del piloto y regresiones para cierre, reaperturas, restauraciones y borradores paralelos.

- Cabecera de la landing con la última release estable y su enlace generados durante la publicación de Pages; se actualiza al publicar una release y usa las versiones del repositorio actual. Las copias sin releases muestran «Ver versiones».
- Pruebas con Playwright en escritorio y móvil emulado para los cuatro estados, evidencia y resultado de cierre, navegación por teclado y todos los botones de copia, incluido `prompt.md` y los casos de copia denegada.
- Regresiones de la versión automática para repositorios nuevos, etiquetas escapadas y fallos de la API. Un fallo de consulta detiene el despliegue y conserva la publicación anterior.
- Entorno de pruebas del navegador aislado en `tests/browser/`, con dependencias fijadas y ejecución en GitHub Actions. El gestor mantiene sus requisitos de Git y herramientas POSIX, sin paquetes adicionales.

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

[v1.1.1]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.1.1
[v1.1.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.1.0
[v1.0.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.0.0
