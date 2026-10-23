#!/bin/sh
# git-ops.sh — Operaciones seguras y deterministas de Git para flujos no técnicos.
# Compatible con POSIX sh (Git for Windows, macOS, Linux) y Git Worktrees.
# Subcomandos disponibles:
#   checkpoint "<mensaje>"       -> Crea un punto de guardado validado (o cierra una conciliación limpia)
#   draft-create "<nombre>"      -> Crea y activa un borrador paralelo (borrador/<slug>)
#   draft-list                   -> Lista el borrador activo, otros borradores y etiquetas de rescate
#   draft-switch "<nombre|main>" -> Cambia de borrador guardando cambios pendientes primero
#   merge-draft "<nombre>"       -> Incorpora un borrador paralelo en la versión actual
#   undo-safe [working|last|ref] -> Deshace cambios creando SIEMPRE una etiqueta rescate/* previa
#   history-human [limite]       -> Muestra el historial reciente con archivos afectados
#   conflict-check               -> Detecta conflictos activos o marcadores sin resolver

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
cd "$REPO_ROOT"

MAX_BYTES=52428800 # 50 MB

TMP_STATUS="${TMPDIR:-/tmp}/agty_wt_$$.txt"
TMP_MARKERS="${TMPDIR:-/tmp}/agty_markers_$$.txt"
TMP_IGNORED="${TMPDIR:-/tmp}/agty_ignored_$$.txt"
TMP_RESTORE_PATHS="${TMPDIR:-/tmp}/agty_restore_paths_$$.txt"
TMP_IDX=""

cleanup_git_ops() {
    rm -f "$TMP_STATUS" "$TMP_MARKERS" "$TMP_IGNORED" "$TMP_RESTORE_PATHS" 2>/dev/null || true
    if [ -n "$TMP_IDX" ]; then
        rm -f "$TMP_IDX" 2>/dev/null || true
    fi
}
trap cleanup_git_ops EXIT INT TERM

ensure_repo() {
    if [ ! -e ".git" ]; then
        sh ".agents/scripts/bootstrap.sh" >/dev/null
    fi
    if [ "$(git config --get core.hooksPath || true)" != ".agents/hooks" ]; then
        git config core.hooksPath .agents/hooks
    fi
    git config core.quotepath false
    if [ -z "$(git config --get user.name || true)" ]; then
        git config user.name "Usuario del Espacio"
    fi
    if [ -z "$(git config --get user.email || true)" ]; then
        git config user.email "usuario@espacio-local.git"
    fi
}

slugify() {
    printf '%s' "$1" | awk '
        {
            s = $0
            gsub(/Á|À|Ä|Â|á|à|ä|â/, "a", s)
            gsub(/É|È|Ë|Ê|é|è|ë|ê/, "e", s)
            gsub(/Í|Ì|Ï|Î|í|ì|ï|î/, "i", s)
            gsub(/Ó|Ò|Ö|Ô|ó|ò|ö|ô/, "o", s)
            gsub(/Ú|Ù|Ü|Û|ú|ù|ü|û/, "u", s)
            gsub(/Ñ|ñ/, "n", s)
            gsub(/Ç|ç/, "c", s)
            print s
        }
    ' | LC_ALL=C tr '[:upper:]' '[:lower:]' \
      | LC_ALL=C sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

is_merge_in_progress() {
    MERGE_HEAD_PATH=$(git rev-parse --git-path MERGE_HEAD 2>/dev/null || echo ".git/MERGE_HEAD")
    [ -f "$MERGE_HEAD_PATH" ]
}

has_conflicts() {
    if is_merge_in_progress; then
        return 0
    fi
    if [ -n "$(git ls-files -u 2>/dev/null)" ]; then
        return 0
    fi
    return 1
}

find_marker_files() {
    : > "$TMP_MARKERS"
    # Incluir tanto archivos unmerged de Git como archivos en workspace/ y knowledge/
    {
        git diff --name-only --diff-filter=U 2>/dev/null || true
        find workspace knowledge -type f 2>/dev/null || true
    } | sort -u > "$TMP_MARKERS"

    while IFS= read -r F || [ -n "$F" ]; do
        [ -z "$F" ] && continue
        if [ -f "$F" ] && awk '/^<<<<<<< / || /^>>>>>>> / { found=1; exit } END { exit !found }' "$F" 2>/dev/null; then
            printf '%s\n' "$F"
        fi
    done < "$TMP_MARKERS"
}

check_working_sizes() {
    git status --porcelain -uall | sed 's/^...//' > "$TMP_STATUS"
    OVERSIZED=0
    while IFS= read -r ITEM || [ -n "$ITEM" ]; do
        [ -z "$ITEM" ] && continue
        CLEAN_ITEM="${ITEM##* -> }"
        CLEAN_ITEM=$(printf '%s' "$CLEAN_ITEM" | sed 's/^"//; s/"$//')
        if [ -f "$CLEAN_ITEM" ]; then
            SIZE=$(wc -c < "$CLEAN_ITEM" | tr -d ' ')
            if [ "$SIZE" -gt "$MAX_BYTES" ]; then
                echo "ERROR_OVERSIZED_FILE=$CLEAN_ITEM ($SIZE bytes > 50 MB)"
                OVERSIZED=1
            fi
        fi
    done < "$TMP_STATUS"
    if [ "$OVERSIZED" -eq 1 ]; then
        return 1
    fi
    return 0
}

check_ignored_restore_paths() {
    # Los archivos ignorados pueden contener secretos: no forzarlos al respaldo.
    # Bloquear antes de modificar nada si una restauración pudiera sobrescribirlos,
    # incluso cuando un archivo sustituya a una carpeta (o viceversa).
    git ls-files --others --ignored --exclude-standard > "$TMP_IGNORED"
    git ls-tree -r --name-only HEAD > "$TMP_RESTORE_PATHS"
    git ls-tree -r --name-only "$1" -- workspace knowledge >> "$TMP_RESTORE_PATHS"
    IGNORE_CASE=$(git config --bool core.ignorecase || echo false)
    COLLISIONS=$(awk -v fold_case="$IGNORE_CASE" '
        FILENAME == ARGV[1] {
            path = fold_case == "true" ? tolower($0) : $0
            targets[path] = 1
            next
        }
        {
            path = fold_case == "true" ? tolower($0) : $0
            for (target in targets) {
                if (path == target || index(path, target "/") == 1 || index(target, path "/") == 1) {
                    print $0
                    break
                }
            }
        }
    ' "$TMP_RESTORE_PATHS" "$TMP_IGNORED")
    if [ -n "$COLLISIONS" ]; then
        echo "UNDO_STATUS=BLOCKED_IGNORED_FILES"
        echo "ERROR=La restauración podría sobrescribir archivos locales excluidos del respaldo. Muévelos fuera del repositorio antes de volver a intentar."
        printf '%s\n' "$COLLISIONS"
        return 1
    fi
}

create_rescue_snapshot() {
    LABEL_REASON="${1:-Respaldo automatico}"
    REAL_IDX=$(git rev-parse --git-path index)
    TMP_IDX=$(git rev-parse --git-path "agty-rescue-index-$$")
    rm -f "$TMP_IDX"
    if [ -f "$REAL_IDX" ]; then
        cp "$REAL_IDX" "$TMP_IDX"
    fi
    GIT_INDEX_FILE="$TMP_IDX" git add -A
    RESCUE_TREE=$(GIT_INDEX_FILE="$TMP_IDX" git write-tree)
    rm -f "$TMP_IDX"
    TMP_IDX=""

    if git rev-parse --verify HEAD >/dev/null 2>&1; then
        HEAD_SHA=$(git rev-parse HEAD)
        RESCUE_COMMIT=$(printf '%s\n' "$LABEL_REASON" | git commit-tree "$RESCUE_TREE" -p "$HEAD_SHA")
    else
        RESCUE_COMMIT=$(printf '%s\n' "$LABEL_REASON" | git commit-tree "$RESCUE_TREE")
    fi

    STAMP=$(date +%Y%m%d-%H%M%S)
    RESCUE_TAG="rescate/${STAMP}-$$"
    git tag "$RESCUE_TAG" "$RESCUE_COMMIT"
    printf '%s' "$RESCUE_TAG"
}

SUBCMD="${1:-help}"
shift || true

case "$SUBCMD" in
    checkpoint)
        ensure_repo
        MSG="${1:-}"
        if [ -z "$MSG" ]; then
            echo "CHECKPOINT_STATUS=FAIL"
            echo "ERROR=Debes proporcionar una nota descriptiva para el punto de guardado."
            exit 1
        fi

        # Verificar si aún quedan marcadores <<<<<<< / >>>>>>> en disco antes de permitir guardar/cerrar un merge
        ACTIVE_MARKERS=$(find_marker_files)
        if [ -n "$ACTIVE_MARKERS" ]; then
            echo "CHECKPOINT_STATUS=FAIL"
            echo "ERROR=Existen marcadores de conflicto sin resolver en los siguientes archivos:"
            printf '%s\n' "$ACTIVE_MARKERS"
            exit 1
        fi

        if ! check_working_sizes; then
            echo "CHECKPOINT_STATUS=FAIL"
            echo "ERROR=Se detectaron archivos mayores a 50 MB. Muévelos fuera del repositorio antes de guardar."
            exit 1
        fi

        MERGE_ACTIVE="false"
        if is_merge_in_progress; then
            MERGE_ACTIVE="true"
        fi

        git add -A

        # Si NO estamos cerrando un merge y no hay diferencias contra HEAD, no crear commit vacío
        if [ "$MERGE_ACTIVE" = "false" ] && git diff --cached --quiet; then
            echo "CHECKPOINT_STATUS=NO_CHANGES"
            echo "CURRENT_DRAFT=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
            exit 0
        fi

        if ! COMMIT_OUT=$(git commit -m "$MSG" 2>&1); then
            if [ "$MERGE_ACTIVE" = "false" ]; then
                if git rev-parse --verify HEAD >/dev/null 2>&1; then
                    git reset -q HEAD -- . 2>/dev/null || true
                else
                    git rm -rf --cached -q . 2>/dev/null || true
                fi
            fi
            echo "CHECKPOINT_STATUS=BLOCKED"
            echo "$COMMIT_OUT"
            exit 1
        fi

        SHORT_SHA=$(git rev-parse --short HEAD)
        CUR_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
        COMMIT_DATE=$(git log -1 --date=format:'%Y-%m-%d %H:%M:%S' --pretty=format:'%ad')
        echo "CHECKPOINT_STATUS=SAVED"
        echo "CHECKPOINT_REF=$SHORT_SHA"
        echo "CHECKPOINT_DRAFT=$CUR_BRANCH"
        echo "CHECKPOINT_DATE=$COMMIT_DATE"
        echo "CHECKPOINT_MSG=$MSG"
        ;;

    draft-create)
        ensure_repo
        RAW_NAME="${1:-}"
        if [ -z "$RAW_NAME" ]; then
            echo "DRAFT_STATUS=FAIL"
            echo "ERROR=Indica un nombre para el borrador paralelo."
            exit 1
        fi
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "DRAFT_STATUS=FAIL"
            echo "ERROR=Crea primero un punto de guardado inicial antes de abrir borradores paralelos."
            exit 1
        fi
        if has_conflicts; then
            echo "DRAFT_STATUS=FAIL"
            echo "ERROR=Concilia primero los conflictos activos antes de crear un nuevo borrador."
            exit 1
        fi
        CLEAN_SLUG=$(slugify "$RAW_NAME")
        CLEAN_SLUG="${CLEAN_SLUG#borrador-}"
        if [ -z "$CLEAN_SLUG" ]; then
            echo "DRAFT_STATUS=FAIL"
            echo "ERROR=El nombre '$RAW_NAME' no contiene letras o números válidos."
            exit 1
        fi
        BRANCH_NAME="borrador/$CLEAN_SLUG"
        if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
            echo "DRAFT_STATUS=EXISTS"
            echo "ERROR=El borrador '$BRANCH_NAME' ya existe. Usa draft-switch para cambiar a él."
            exit 1
        fi
        git checkout -q -b "$BRANCH_NAME"
        echo "DRAFT_STATUS=CREATED"
        echo "CURRENT_DRAFT=$BRANCH_NAME"
        ;;

    draft-list)
        ensure_repo
        CUR_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
        echo "CURRENT_DRAFT=$CUR_BRANCH"
        echo "--- DRAFTS ---"
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            git for-each-ref --sort=-committerdate refs/heads/ \
                --format='%(refname:short) | %(committerdate:short) | %(subject)'
        else
            echo "(Sin puntos de guardado todavía)"
        fi
        echo "--- RESCUE_TAGS ---"
        TAGS=$(git tag -l 'rescate/*' | sort -r)
        if [ -n "$TAGS" ]; then
            printf '%s\n' "$TAGS"
        else
            echo "(Ninguno)"
        fi
        ;;

    draft-switch)
        ensure_repo
        TARGET="${1:-}"
        if [ -z "$TARGET" ]; then
            echo "DRAFT_SWITCH_STATUS=FAIL"
            echo "ERROR=Indica a qué borrador deseas cambiar (ej. 'main' o el nombre del borrador)."
            exit 1
        fi
        if has_conflicts; then
            echo "DRAFT_SWITCH_STATUS=FAIL"
            echo "ERROR=No se puede cambiar de borrador mientras haya conflictos pendientes."
            exit 1
        fi

        RESOLVED=""
        if [ "$TARGET" = "principal" ] || [ "$TARGET" = "main" ]; then
            RESOLVED="main"
        elif git show-ref --verify --quiet "refs/heads/$TARGET"; then
            RESOLVED="$TARGET"
        else
            SLUG=$(slugify "$TARGET")
            SLUG="${SLUG#borrador-}"
            if git show-ref --verify --quiet "refs/heads/borrador/$SLUG"; then
                RESOLVED="borrador/$SLUG"
            fi
        fi

        if [ -z "$RESOLVED" ] || ! git show-ref --verify --quiet "refs/heads/$RESOLVED"; then
            echo "DRAFT_SWITCH_STATUS=FAIL"
            echo "ERROR=No existe el borrador '$TARGET'."
            exit 1
        fi

        # Si hay cambios sin guardar, crear un punto de guardado automático para no perder nada
        if [ -n "$(git status --porcelain)" ]; then
            if ! sh ".agents/scripts/git-ops.sh" checkpoint "Guardado automático antes de cambiar a $RESOLVED"; then
                echo "DRAFT_SWITCH_STATUS=FAIL"
                echo "ERROR=No se pudieron guardar automáticamente los cambios actuales antes de cambiar de borrador."
                exit 1
            fi
        fi

        git checkout -q "$RESOLVED"
        echo "DRAFT_SWITCH_STATUS=OK"
        echo "CURRENT_DRAFT=$RESOLVED"
        ;;

    merge-draft)
        ensure_repo
        SOURCE="${1:-}"
        if [ -z "$SOURCE" ]; then
            echo "MERGE_STATUS=FAIL"
            echo "ERROR=Indica qué borrador deseas incorporar."
            exit 1
        fi
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "MERGE_STATUS=FAIL"
            echo "ERROR=No existe ningún punto de guardado base en el historial."
            exit 1
        fi
        if has_conflicts; then
            echo "MERGE_STATUS=FAIL"
            echo "ERROR=Ya existe una conciliación en curso. Resuélvela primero."
            exit 1
        fi

        RESOLVED_SRC=""
        if git show-ref --verify --quiet "refs/heads/$SOURCE"; then
            RESOLVED_SRC="$SOURCE"
        else
            SLUG=$(slugify "$SOURCE")
            SLUG="${SLUG#borrador-}"
            if git show-ref --verify --quiet "refs/heads/borrador/$SLUG"; then
                RESOLVED_SRC="borrador/$SLUG"
            fi
        fi

        if [ -z "$RESOLVED_SRC" ]; then
            echo "MERGE_STATUS=FAIL"
            echo "ERROR=No se encontró el borrador '$SOURCE'."
            exit 1
        fi

        if [ -n "$(git status --porcelain)" ]; then
            echo "MERGE_STATUS=FAIL"
            echo "ERROR=Guarda un punto de control antes de incorporar otro borrador."
            exit 1
        fi

        if git merge-base --is-ancestor "$RESOLVED_SRC" HEAD; then
            echo "MERGE_STATUS=ALREADY_UP_TO_DATE"
            echo "MERGED_FROM=$RESOLVED_SRC"
            echo "CHECKPOINT_REF=$(git rev-parse --short HEAD)"
            exit 0
        fi

        PRE_MERGE_SHA=$(git rev-parse HEAD)
        if MERGE_OUT=$(git merge --no-ff -m "Incorporar cambios desde $RESOLVED_SRC" "$RESOLVED_SRC" 2>&1); then
            # Validar OKF post-merge incluso en versiones de Git < 2.24 sin pre-merge-commit
            if [ -d "knowledge" ] && ! OKF_POST=$(sh ".agents/scripts/okf-lint.sh" "knowledge" 2>&1); then
                git reset --merge "$PRE_MERGE_SHA" 2>/dev/null || true
                echo "MERGE_STATUS=OKF_INVALID"
                echo "MERGED_FROM=$RESOLVED_SRC"
                echo "$OKF_POST"
                exit 1
            fi
            echo "MERGE_STATUS=CLEAN"
            echo "MERGED_FROM=$RESOLVED_SRC"
            echo "CHECKPOINT_REF=$(git rev-parse --short HEAD)"
        else
            CONFLICT_LIST=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
            if [ -n "$CONFLICT_LIST" ]; then
                echo "MERGE_STATUS=CONFLICT"
                echo "MERGED_FROM=$RESOLVED_SRC"
                echo "--- CONFLICTING_FILES ---"
                printf '%s\n' "$CONFLICT_LIST"
                exit 1
            else
                echo "MERGE_STATUS=FAIL"
                echo "MERGED_FROM=$RESOLVED_SRC"
                echo "$MERGE_OUT"
                exit 1
            fi
        fi
        ;;

    undo-safe)
        ensure_repo
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "UNDO_STATUS=FAIL"
            echo "ERROR=Aún no existen puntos de guardado en el historial."
            exit 1
        fi
        if has_conflicts; then
            check_ignored_restore_paths HEAD || exit 1
            RESCUE_TAG=$(create_rescue_snapshot "Respaldo antes de cancelar conflicto")
            git merge --abort 2>/dev/null || true
            echo "UNDO_STATUS=CONFLICT_ABORTED"
            echo "RESCUE_TAG=$RESCUE_TAG"
            exit 0
        fi

        MODE="${1:-auto}"
        IS_DIRTY="false"
        if [ -n "$(git status --porcelain)" ]; then
            IS_DIRTY="true"
        fi

        if [ "$MODE" = "auto" ]; then
            if [ "$IS_DIRTY" = "true" ]; then
                MODE="working"
            else
                MODE="last"
            fi
        fi

        TARGET_REF="$MODE"
        if [ "$MODE" = "working" ]; then
            TARGET_REF="HEAD"
        elif [ "$MODE" = "last" ]; then
            if ! git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
                echo "UNDO_STATUS=FAIL"
                echo "ERROR=Solo existe un punto de guardado en el historial; no hay una versión anterior a la cual retroceder."
                exit 1
            fi
            TARGET_REF="HEAD~1"
        fi

        if ! TARGET_REF=$(git rev-parse --verify "${TARGET_REF}^{commit}" 2>/dev/null); then
            echo "UNDO_STATUS=FAIL"
            echo "ERROR=La referencia '$MODE' no existe en el historial."
            exit 1
        fi

        check_ignored_restore_paths "$TARGET_REF" || exit 1

        # Crear el respaldo solo después de verificar que la operación es segura.
        RESCUE_TAG=$(create_rescue_snapshot "Respaldo automatico antes de undo-safe ($MODE)")

        if [ "$MODE" = "working" ]; then
            git reset -q HEAD -- .
            git checkout -q -- .
            git clean -fd -q -- workspace knowledge 2>/dev/null || true
            echo "UNDO_STATUS=RESTORED_WORKING_TREE"
            echo "RESTORED_TO=$(git rev-parse --short HEAD)"
            echo "RESCUE_TAG=$RESCUE_TAG"
            exit 0
        fi

        SHORT_TARGET=$(git rev-parse --short "${TARGET_REF}^{commit}")

        # Limpiar estado actual (ya respaldado en RESCUE_TAG)
        git reset -q HEAD -- .
        git checkout -q -- .
        git clean -fd -q -- workspace knowledge 2>/dev/null || true

        # Restaurar exclusivamente las zonas de usuario y memoria al estado exacto de TARGET_REF sin borrar .agents/
        git rm -rf -q -- workspace knowledge 2>/dev/null || true
        if [ -n "$(git ls-tree "$TARGET_REF" workspace 2>/dev/null)" ]; then
            git checkout "$TARGET_REF" -- workspace
        fi
        if [ -n "$(git ls-tree "$TARGET_REF" knowledge 2>/dev/null)" ]; then
            git checkout "$TARGET_REF" -- knowledge
        fi
        mkdir -p workspace/bandeja workspace/documentos workspace/datos workspace/entregables

        git add -A -- workspace knowledge
        if git diff --cached --quiet; then
            echo "UNDO_STATUS=NO_CHANGES_NEEDED"
            echo "RESTORED_TO=$SHORT_TARGET"
            echo "RESCUE_TAG=$RESCUE_TAG"
            exit 0
        fi

        if ! RESTORE_OUT=$(git commit -m "Restaurar versión $SHORT_TARGET (respaldo previo en $RESCUE_TAG)" 2>&1); then
            git reset -q HEAD -- . 2>/dev/null || true
            echo "UNDO_STATUS=RESTORED_UNCOMMITTED_NEEDS_FIX"
            echo "RESTORED_FROM_REF=$SHORT_TARGET"
            echo "RESCUE_TAG=$RESCUE_TAG"
            echo "$RESTORE_OUT"
            exit 1
        fi

        echo "UNDO_STATUS=RESTORED_COMMIT_CREATED"
        echo "RESTORED_FROM_REF=$SHORT_TARGET"
        echo "NEW_CHECKPOINT_REF=$(git rev-parse --short HEAD)"
        echo "RESCUE_TAG=$RESCUE_TAG"
        ;;

    history-human)
        ensure_repo
        LIMIT="${1:-10}"
        case "$LIMIT" in
            ''|*[!0-9]*|0)
                echo "HISTORY_STATUS=FAIL"
                echo "ERROR=El límite '$LIMIT' debe ser un número entero positivo."
                exit 1
                ;;
        esac
        if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "HISTORY_STATUS=EMPTY"
            exit 0
        fi
        echo "HISTORY_STATUS=OK"
        echo "CURRENT_DRAFT=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
        git log -n "$LIMIT" --date=format:'%Y-%m-%d %H:%M' \
            --pretty=format:'=== CHECKPOINT %h | %ad | %s ===' --name-status
        echo ""
        ;;

    conflict-check)
        ensure_repo
        MERGE_IN_PROG="false"
        if is_merge_in_progress; then
            MERGE_IN_PROG="true"
        fi

        echo "--- MERGE_STATE ---"
        echo "MERGE_IN_PROGRESS=$MERGE_IN_PROG"

        UNMERGED=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
        if [ -n "$UNMERGED" ]; then
            echo "--- UNMERGED_FILES ---"
            printf '%s\n' "$UNMERGED"
        fi

        MARKER_FILES=$(find_marker_files)
        if [ -n "$MARKER_FILES" ]; then
            echo "--- FILES_WITH_CONFLICT_MARKERS ---"
            printf '%s\n' "$MARKER_FILES"
            echo "UNRESOLVED_MARKERS=true"
            echo "CONFLICT_STATE=true"
        elif [ "$MERGE_IN_PROG" = "true" ] || [ -n "$UNMERGED" ]; then
            echo "UNRESOLVED_MARKERS=false"
            echo "CONFLICT_STATE=ready_to_checkpoint"
        else
            echo "UNRESOLVED_MARKERS=false"
            echo "CONFLICT_STATE=false"
        fi
        ;;

    *)
        echo "Uso: sh .agents/scripts/git-ops.sh {checkpoint|draft-create|draft-list|draft-switch|merge-draft|undo-safe|history-human|conflict-check}"
        exit 1
        ;;
esac
