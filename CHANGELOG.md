# Historial de cambios

Novedades y correcciones de las versiones publicadas de Repo-as-an-Agent.

## Pendiente de publicación

### Añadido

- Gestor local de tareas Markdown con estados pendiente, en curso, bloqueada y terminada, criterios de aceptación, evidencia y resultado obligatorio al cerrar.
- Asociaciones `Task-ID` de una o varias tareas a puntos de guardado e historial por tarea en el borrador actual.
- Habilidad `task-manager`, validación de tareas preparadas al guardar y pruebas de regresión del ciclo de tareas en Linux, macOS y Windows.

- Landing en GitHub Pages con guías para usuarios técnicos y no técnicos, diagramas, ejemplos interactivos, navegación por teclado y animaciones con pausa y movimiento reducido.
- [Prompt de despliegue](prompt.md) listo para copiar a un agente y publicar la landing en una copia del template.
- Constructor con una lista explícita de archivos públicos y siete pruebas para enlaces, rutas de proyecto y exclusión de documentos privados.
- Flujo de publicación automática de Pages y validación de la landing en el flujo de pruebas existente.

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

[v1.0.0]: https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.0.0
