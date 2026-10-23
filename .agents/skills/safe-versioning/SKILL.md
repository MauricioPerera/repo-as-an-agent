---
name: safe-versioning
description: >-
  Manages checkpoints, parallel drafts (branches), version comparisons, conflict
  resolution, and zero-data-loss rollbacks in plain non-technical language. Use
  this skill whenever the user asks to save a version, create an alternative draft,
  check what changed, merge drafts, resolve conflicts, or undo changes.
---

# Máquina del Tiempo y Versionado Seguro (`safe-versioning`)

Opera Git de forma 100% determinista a través de [git-ops.sh](../../scripts/git-ops.sh), traduciendo cada acción a lenguaje humano claro.

## Procedimientos por Intención del Usuario

### 1. Guardar un punto de control ("Guarda cómo vamos")
1. Ejecuta:
   ```sh
   sh .agents/scripts/git-ops.sh checkpoint "<Resumen claro de lo realizado>"
   ```
2. Si devuelve `CHECKPOINT_STATUS=SAVED`, confirma brevemente qué quedó guardado.
   Si el avance pertenece a una tarea registrada, añade `--task ID` al comando;
   puedes repetirlo para asociar varias tareas. Consulta `task-manager` para los
   estados y la evidencia: guardar avances no termina tareas automáticamente.
3. Si devuelve `CHECKPOINT_STATUS=BLOCKED`, lee el diagnóstico del hook `pre-commit` (ej. un error en `knowledge/` o un archivo >50 MB), corrígelo o explícalo en palabras simples y vuelve a intentar. **Jamás uses `--no-verify`.**

### 2. Crear o cambiar entre borradores paralelos ("Probemos otra versión sin tocar la actual")
- **Crear borrador nuevo:**
  ```sh
  sh .agents/scripts/git-ops.sh draft-create "<nombre-corto>"
  ```
- **Consultar borradores existentes:**
  ```sh
  sh .agents/scripts/git-ops.sh draft-list
  ```
- **Cambiar a otro borrador (o volver a `main` / `principal`):**
  ```sh
  sh .agents/scripts/git-ops.sh draft-switch "<nombre-o-main>"
  ```
  *(Nota: `draft-switch` guarda automáticamente los cambios pendientes antes de cambiar para que nada se pierda).*
- **Incorporar un borrador aprobado en la versión principal:**
  1. Cambia a `main` con `draft-switch main`.
  2. Ejecuta:
     ```sh
     sh .agents/scripts/git-ops.sh merge-draft "<nombre-del-borrador>"
     ```

### 3. Revisar qué cambió ("¿Qué modificamos desde ayer?")
1. Consulta el historial estructurado:
   ```sh
   sh .agents/scripts/git-ops.sh history-human 10
   ```
2. Si el usuario pide el detalle entre dos momentos, usa `git diff <ref1>..<ref2> -- workspace/` de solo lectura y **resume los cambios en viñetas comprensibles** (qué párrafos, cifras o secciones se agregaron, quitaron o ajustaron), sin volcar código diff crudo salvo que lo pida.

### 4. Deshacer cambios sin riesgo ("Deshaz esto / Vuelve a la versión anterior")
Usa **siempre** `undo-safe`, que crea automáticamente una etiqueta inmutable `rescate/YYYYMMDD-HHMMSS-*` con todos los archivos (incluso nuevos sin guardar) antes de tocar nada:
- **Descartar cambios recientes aún no guardados:**
  ```sh
  sh .agents/scripts/git-ops.sh undo-safe working
  ```
- **Volver al punto de guardado inmediatamente anterior:**
  ```sh
  sh .agents/scripts/git-ops.sh undo-safe last
  ```
- **Restaurar un punto específico del historial (o incluso recuperar un `rescate/*`):**
  ```sh
  sh .agents/scripts/git-ops.sh undo-safe "<referencia>"
  ```
Informa al usuario que sus documentos regresaron a la versión solicitada y que, por seguridad, el estado descartado quedó respaldado por si cambia de opinión.

Si devuelve `UNDO_STATUS=BLOCKED_IGNORED_FILES`, no se modificó ningún archivo ni se creó un rescate. Explica que los archivos locales excluidos indicados deben moverse fuera del repositorio antes de restaurar. No los añadas forzadamente al respaldo: pueden contener secretos. Los archivos excluidos que no colisionan se conservan sin bloquear la operación.

### 5. Conciliar conflictos sin tecnicismos (`CONFLICT_STATE=true`)
El usuario jamás debe ver `<<<<<<<` ni `>>>>>>>`:
1. Ejecuta `sh .agents/scripts/git-ops.sh conflict-check` para listar los archivos afectados.
2. Abre cada archivo con conflicto, extrae el texto de la **Opción A** y el de la **Opción B**, y preséntaselos al usuario en lenguaje natural preguntando cuál prefiere conservar (o cómo combinarlos).
3. Edita el archivo dejando el texto limpio elegido (eliminando todos los marcadores `<<<<<<<`, `=======`, `>>>>>>>`).
4. Ejecuta `sh .agents/scripts/git-ops.sh conflict-check` para confirmar que `UNRESOLVED_MARKERS=false` (`CONFLICT_STATE=ready_to_checkpoint` si provenía de unir dos borradores, o `CONFLICT_STATE=false`).
5. Cierra la conciliación guardando el punto de control:
   ```sh
   sh .agents/scripts/git-ops.sh checkpoint "Conciliar cambios entre versiones"
   ```
