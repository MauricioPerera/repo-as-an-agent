#!/bin/sh
# Valida las tareas locales o los blobs exactos preparados para guardar.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
cd "$ROOT"
TASK_DIR=workspace/documentos/tareas
TMP=$(mktemp -d "${TMPDIR:-/tmp}/agty-tasks-lint.XXXXXX")
trap 'rm -f "$TMP/list" "$TMP/blob"; rmdir "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
fail() { printf 'TASK_LINT_STATUS=FAIL\nERROR=%s\n' "$1"; exit 1; }
MODE=${1:-}
[ "$#" -le 1 ] || fail "Uso: tasks-lint.sh [--staged]"
case "$MODE" in ''|--staged) ;; *) fail "Opción desconocida: $MODE" ;; esac
TREE=
if [ "$MODE" = --staged ]; then
    TREE=$(git write-tree)
    for P in workspace workspace/documentos "$TASK_DIR"; do
        ENTRY=$(git ls-tree "$TREE" -- "$P")
        case "$ENTRY" in ''|'040000 tree '*) ;; *) fail "La zona de tareas no puede atravesar enlaces o archivos: $P" ;; esac
    done
    git -c core.quotepath=false ls-tree -r --name-only "$TREE" -- "$TASK_DIR" > "$TMP/list"
else
    for P in workspace workspace/documentos "$TASK_DIR"; do
        [ ! -L "$P" ] || fail "La zona de tareas no puede atravesar enlaces: $P"
        [ ! -e "$P" ] || [ -d "$P" ] || fail "Se esperaba una carpeta: $P"
    done
    : > "$TMP/list"
    if [ -d "$TASK_DIR" ]; then
        find "$TASK_DIR" -name '*.md' -print | LC_ALL=C sort > "$TMP/list"
    fi
fi
COUNT=0
while IFS= read -r FILE || [ -n "$FILE" ]; do
    case "$FILE" in '"'*) fail "Nombre de archivo escapado no admitido: $FILE" ;; esac
    case "$FILE" in *.md) ;; *) continue ;; esac
    NAME=${FILE##*/}
    ID=${NAME%.md}
    if ! printf '%s\n' "$ID" | LC_ALL=C grep -Eq '^T-[0-9a-f]{12}$' || [ "$FILE" != "$TASK_DIR/$ID.md" ]; then
        fail "Nombre de tarea inválido: $FILE"
    fi
    SOURCE=$FILE
    if [ "$MODE" = --staged ]; then
        ENTRY=$(git ls-tree "$TREE" -- "$FILE")
        case "$ENTRY" in '100644 blob '*|'100755 blob '*) ;; *) fail "La tarea debe ser un archivo regular: $FILE" ;; esac
        git cat-file blob "$TREE:$FILE" > "$TMP/blob"
        SOURCE=$TMP/blob
    else
        [ ! -L "$FILE" ] && [ -f "$FILE" ] || fail "La tarea debe ser un archivo regular: $FILE"
    fi
    if ! LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -f "$SCRIPT_DIR/task-format.awk" "$SOURCE"; then
        fail "Revisa el formato de $FILE"
    fi
    COUNT=$((COUNT + 1))
done < "$TMP/list"
printf 'TASK_LINT_STATUS=PASS\nTASK_COUNT=%s\n' "$COUNT"
