# AGENTS.md — Constitución Operativa del Espacio de Trabajo

Este repositorio funciona bajo la arquitectura **Repo-as-an-Agent** (El Repositorio ES el Agente), diseñada para asistir a **personas no técnicas** usando Git como máquina del tiempo invisible, **Open Knowledge Format (OKF)** como memoria estructurada y scripts POSIX `sh` como músculo determinista.

Esta especificación aplica por igual a **Antigravity, Codex, Claude Code, OpenCode, Cursor** o cualquier otro agente con acceso a archivos y terminal.

---

## 1. Contrato de Interfaz Humana (Regla de Oro)

El usuario principal de este espacio **NO es técnico**. Cumple siempre estas reglas de comunicación:

1. **Cero jerga de Git:** Jamás expongas términos como `HEAD`, `staging area`, `rebase`, `cherry-pick`, `commit SHA` o `detached HEAD` (salvo que el usuario pregunte explícitamente cómo funciona por dentro).
2. **Traducción semántica obligatoria:**
   - `commit` -> **Punto de guardado**
   - `branch` -> **Borrador paralelo** (o versión alternativa)
   - `diff` / `log` -> **Resumen de cambios** / **Historial**
   - `merge` -> **Unir / incorporar cambios**
   - `revert` / `restore` -> **Volver a una versión anterior (con respaldo previo)**
3. **Transparencia antes y después de actuar:** Antes de hacer ediciones grandes, explica brevemente qué vas a cambiar. Al terminar, resume en lenguaje llano qué archivos cambiaron y confirma si se creó un punto de guardado.

---

## 2. Protocolo de Arranque Silencioso (Primer Turno)

En tu primera interacción dentro de una sesión nueva:

1. Ejecuta `sh .agents/scripts/boot-check.sh` para diagnosticar el estado del repositorio y asegurar que los Git Hooks (`.agents/hooks`) estén activos.
2. Si el resultado indica `GIT_INITIALIZED=false`, ejecuta `sh .agents/scripts/bootstrap.sh`.
3. Si `CONFLICT_STATE=true`, informa con calma que hay dos versiones pendientes de conciliar y carga [`.agents/skills/safe-versioning/SKILL.md`](./.agents/skills/safe-versioning/SKILL.md).
4. Si `ONBOARDING_STATUS=template`:
   - Si el usuario saluda o pide empezar, activa [`.agents/skills/onboarding/SKILL.md`](./.agents/skills/onboarding/SKILL.md).
   - Si el usuario pide una tarea urgente directa, atiéndela primero y sugiere personalizar el espacio al finalizar.

---

## 3. Mapa de Zonas y Fronteras Estrictas

| Ruta | Zona | Regla de operación |
| :--- | :--- | :--- |
| `workspace/` | **Zona Humana** | Archivos reales del usuario (`bandeja/`, `documentos/`, `datos/`, `entregables/`). Prohibido crear archivos de configuración técnica aquí. |
| `knowledge/` | **Memoria OKF** | Conocimiento duradero del proyecto/usuario en estándar Open Knowledge Format. Lee `knowledge/index.md` primero (carga progresiva) antes de abrir nodos individuales. |
| `.agents/` | **Motor del Agente** | Scripts deterministas (`scripts/`), validadores automáticos (`hooks/`), procedimientos (`skills/`) y pruebas (`tests/`). No modificar salvo mantenimiento explícito del sistema. |

---

## 4. Invariantes de Seguridad y Acciones Deterministas

**PROHIBIDO improvisar comandos destructivos de Git.** Nunca ejecutes directamente:
- `git reset --hard`, `git clean -fd`, `git checkout -- <archivo>`, `git restore .` (sin respaldo previo)
- `git push --force` o `git branch -D`
- `git commit --no-verify` (está estrictamente prohibido saltar `.agents/hooks/pre-commit`)

**USA SIEMPRE los scripts deterministas en POSIX `sh`:**

- **Diagnóstico de sesión:** `sh .agents/scripts/boot-check.sh`
- **Inicialización / auto-reparación:** `sh .agents/scripts/bootstrap.sh`
- **Validar memoria OKF:** `sh .agents/scripts/okf-lint.sh`
- **Operaciones seguras de Git (`git-ops.sh`):**
  - `sh .agents/scripts/git-ops.sh checkpoint "<nota clara en humano>"`
  - `sh .agents/scripts/git-ops.sh draft-create "<nombre-del-borrador>"`
  - `sh .agents/scripts/git-ops.sh draft-list`
  - `sh .agents/scripts/git-ops.sh draft-switch "<nombre-del-borrador|main>"`
  - `sh .agents/scripts/git-ops.sh merge-draft "<nombre-del-borrador>"`
  - `sh .agents/scripts/git-ops.sh undo-safe [referencia-opcional]` *(crea etiqueta `rescate/*` automática antes de restaurar)*
  - `sh .agents/scripts/git-ops.sh history-human [cantidad]`
  - `sh .agents/scripts/git-ops.sh conflict-check`

**Regla de edición masiva:** Antes de editar **3 o más archivos** en `workspace/`, o de reescribir más del **30%** de un documento existente, ejecuta primero `sh .agents/scripts/git-ops.sh checkpoint "Respaldo previo antes de edición masiva"` si existen cambios sin guardar.

---

## 5. Catálogo de Skills (Carga Progresiva)

No asumas los detalles de los flujos complejos. **Lee el `SKILL.md` correspondiente** cuando la tarea coincida:

1. **Personalización inicial (`onboarding`):** [`.agents/skills/onboarding/SKILL.md`](./.agents/skills/onboarding/SKILL.md)
   - Cuándo usar: El perfil en `knowledge/profile/context.md` sigue en estado `template` o el usuario pide reconfigurar el propósito de su proyecto.
2. **Máquina del tiempo y versiones (`safe-versioning`):** [`.agents/skills/safe-versioning/SKILL.md`](./.agents/skills/safe-versioning/SKILL.md)
   - Cuándo usar: Guardar hitos, crear o cambiar entre borradores paralelos, comparar versiones en lenguaje humano, deshacer cambios o resolver conflictos sin tecnicismos.
3. **Curaduría de memoria OKF (`okf-librarian`):** [`.agents/skills/okf-librarian/SKILL.md`](./.agents/skills/okf-librarian/SKILL.md)
   - Cuándo usar: Guardar decisiones, glosarios, reglas de negocio o contexto duradero en `knowledge/` cumpliendo el esquema YAML y enlaces de Open Knowledge Format.
4. **Asistente documental y de datos (`workspace-assistant`):** [`.agents/skills/workspace-assistant/SKILL.md`](./.agents/skills/workspace-assistant/SKILL.md)
   - Cuándo usar: Procesar elementos sueltos de `workspace/bandeja/`, realizar ediciones masivas auditadas en `workspace/documentos/`, limpiar/auditar CSVs en `workspace/datos/` o generar salidas en `workspace/entregables/`.
