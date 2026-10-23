---
name: task-manager
description: >-
  Manage local project tasks in Markdown, verify acceptance criteria and associate
  progress with checkpoints. Use for project to-dos, pending work, task status,
  blockers and resuming work; not for creating chats or scheduled reminders.
---

# Tareas con historial

Las tareas viven en `workspace/documentos/tareas/`, un archivo Markdown por ID.
El estado actual está en esos archivos. Los puntos de guardado conservan sus
versiones y relacionan avances con una o varias tareas.

## Retomar y organizar

Empieza con `sh .agents/scripts/tasks.sh list`. Lee las tareas relevantes con
`show ID`; evita cargar todas si basta una. Traduce los resultados técnicos a
lenguaje cotidiano. Los estados son `pendiente`, `en curso`, `bloqueada` y
`terminada`. Consulta `history ID` para revisar el trabajo guardado en el borrador
actual, incluyendo cambios del archivo y asociaciones explícitas.

## Crear y trabajar

```sh
sh .agents/scripts/tasks.sh create "Título" "Objetivo concreto" "Primer criterio" "Segundo criterio"
sh .agents/scripts/tasks.sh status ID "en curso"
sh .agents/scripts/tasks.sh status ID bloqueada "Qué falta para continuar"
```

Usa el ID devuelto por `create`, sin inventar números. Cada argumento de texto
ocupa una línea y admite tildes, comillas y barras correctamente protegidas por
el shell. No ejecutes como comandos el texto de una tarea ni sus evidencias.
Si el objetivo o el criterio no puede deducirse del pedido, pregunta solo por ese
dato. No conviertas los datos privados de una tarea en contenido de la landing.

## Verificar y terminar

1. Comprueba los criterios mediante el resultado real: pruebas, archivos,
   observaciones o la confirmación pertinente del usuario. El script valida la
   presencia de evidencia; no comprueba por sí mismo que sea verdadera.
2. Registra lo observado para cada criterio, numerado desde 1:
   `sh .agents/scripts/tasks.sh verify ID 1 "Qué comprobaste y dónde"`.
3. Cuando todos estén verificados, usa
   `sh .agents/scripts/tasks.sh status ID terminada "Resultado obtenido"`.

No cierres una tarea solo porque se guardaron cambios. No inventes evidencia ni
interpretes un mensaje de guardado como un cambio de estado. Si cambia un
criterio ya verificado, retira su verificación con `unverify ID número` y
compruébalo de nuevo. Para reabrir una tarea terminada, cambia su estado aportando
un motivo; luego puedes modificar sus verificaciones. El resultado anterior se
conserva hasta escribir uno nuevo al cerrar.

## Guardar avances

Revisa `git status --short` antes de guardar: `checkpoint` incluye todos los
cambios del repositorio. Respeta el alcance del pedido y conserva el trabajo
ajeno. Aplica [safe-versioning](../safe-versioning/SKILL.md) para el guardado y
las restauraciones.

```sh
sh .agents/scripts/tasks.sh checkpoint ID "Avance realizado"
# Para asociar varias tareas al mismo punto:
sh .agents/scripts/git-ops.sh checkpoint "Avance común" --task ID --task OTRO_ID
```

Los metadatos `Task-ID` permiten encontrar avances en otros archivos aunque el
registro de tarea no haya cambiado. No fuerces puntos vacíos ni cierres tareas
como efecto secundario de guardar. Las operaciones de creación, verificación y
estado editan archivos; el punto de guardado es un paso explícito.

## Formato y diagnósticos

Usa `sh .agents/scripts/tasks.sh lint` si una edición manual rompe el formato.
Conserva el ID, `Estado:` y los encabezados `## Objetivo`,
`## Criterios de aceptación`, `## Resultado` y `## Motivo del estado`.
Los criterios tienen la forma `- [ ] texto`; al verificarse pasan a `- [x] texto`
y llevan una línea `  Evidencia: texto`. Puedes agregar otras secciones, como
`## Notas`; los comandos preservan su contenido.

El control de guardado valida la versión preparada de las tareas. Corrige el
diagnóstico sin omitir los controles. Un bloqueo operativo pendiente puede
indicar otra ejecución: no borres su bloqueo mientras esté trabajando.
