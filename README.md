# Repo-as-an-Agent

Plantilla universal **agnóstica de motor** (*Antigravity, Codex, Claude Code, OpenCode, Cursor*) que convierte un repositorio Git en un asistente documental y de memoria seguro para **personas no técnicas**.

> **¿No eres perfil técnico?** Abre directamente [**LEEME.md**](./LEEME.md) para ver cómo usar este espacio con palabras sencillas.

---

## Qué incluye esta plantilla

1. **Columna vertebral multi-agente (`AGENTS.md` + `CLAUDE.md`):**
   - Contrato de comunicación sin jerga técnica (habla de *puntos de guardado* y *borradores paralelos* en lugar de tecnicismos de Git).
   - Separación estricta entre **Zona Humana** (`workspace/`), **Memoria Estructurada** (`knowledge/`) y **Motor Determinista** (`.agents/`).
2. **Memoria viva en Open Knowledge Format (`knowledge/`):**
   - Nodos Markdown con YAML frontmatter validado, carga progresiva desde `knowledge/index.md` y bitácora en `knowledge/log.md`.
3. **Músculo determinista en POSIX `sh` (`.agents/scripts/` + `.agents/hooks/`):**
   - **Cero dependencias adicionales:** solo requiere tener **Git** instalado (compatible con *Git for Windows*, macOS, Linux y *Git Worktrees*).
   - `okf-lint.sh`: valida el esquema YAML y enlaces relativos (incluyendo espacios y paréntesis).
   - `git-ops.sh`: gestiona puntos de guardado, borradores paralelos, conciliaciones y reversiones sin pérdida de datos (`undo-safe` genera etiquetas inmutables `rescate/*` antes de restaurar cualquier versión).
   - Hooks `pre-commit` y `pre-merge-commit`: bloquean automáticamente secretos (`.env`, llaves privadas), archivos >50 MB, marcadores de conflicto y nodos OKF inválidos.
4. **Skills modulares (`.agents/skills/`):**
   - `onboarding`: entrevista breve de bienvenida para personalizar el espacio en la primera sesión.
   - `safe-versioning`: máquina del tiempo y borradores en lenguaje humano.
   - `okf-librarian`: curaduría y enlace de conocimiento duradero.
   - `workspace-assistant`: organización de bandeja de entrada, edición masiva segura y auditoría de tablas CSV.

---

## Cómo usar esta plantilla

1. Haz clic en el botón **`Use this template`** -> **`Create a new repository`** en GitHub (o clona este repositorio).
2. Abre la carpeta clonada con **Antigravity**, **Codex**, **Claude Code** o tu asistente de preferencia.
3. Escribe: *"Hola, configuremos este espacio para mi proyecto"*.
   - En el primer turno, `boot-check.sh` activará automáticamente los hooks locales de Git y detectará el modo plantilla para guiarte en la personalización inicial.

## Validación automatizada

Para ejecutar la suite de 16 pruebas deterministas en un entorno temporal aislado:

```sh
sh .agents/tests/run-tests.sh
```
