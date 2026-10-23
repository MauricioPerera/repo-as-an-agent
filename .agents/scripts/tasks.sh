#!/bin/sh
# Gestor local de tareas Markdown. Git y herramientas incluidas en Git Bash/macOS/Linux.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
cd "$ROOT"
TASK_DIR=workspace/documentos/tareas
EDIT_FILE=
LOCK=
TMP=$(mktemp -d "${TMPDIR:-/tmp}/agty-tasks.XXXXXX")
cleanup() {
    [ -z "$EDIT_FILE" ] || rm -f "$EDIT_FILE"
    [ -z "$LOCK" ] || rmdir "$LOCK"
    rm -f "$TMP/paths" "$TMP/log" "$TMP/selected" "$TMP/msg"
    rmdir "$TMP"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
fail() { printf 'TASK_STATUS=FAIL\nERROR=%s\n' "$1"; exit 1; }
valid_id() { printf '%s\n' "$1" | LC_ALL=C grep -Eq '^T-[0-9a-f]{12}$'; }
require_text() {
    case "$1" in *'
'*) fail "El texto debe ocupar una sola línea" ;; esac
    if ! printf '%s\n' "$1" | LC_ALL=C awk '/[[:cntrl:]]/ {exit 1} /[^[:space:]]/ && $0 != "-" {ok=1} END {if (!ok) exit 1}'; then
        fail "Se requiere texto no vacío, sin caracteres de control"
    fi
}
field() { LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -v field="$1" -f "$SCRIPT_DIR/task-format.awk" "$FILE"; }
load_task() {
    ID=$1
    valid_id "$ID" || fail "ID inválido"
    FILE=$TASK_DIR/$ID.md
    [ -f "$FILE" ] && [ ! -L "$FILE" ] || fail "No existe la tarea $ID"
    STATE=$(field state)
}
lock_tasks() {
    LOCK_PATH=$(git rev-parse --git-path task-manager.lock)
    if ! mkdir "$LOCK_PATH" 2>/dev/null; then fail "Existe otra operación de tareas o un bloqueo pendiente: $LOCK_PATH"; fi
    LOCK=$LOCK_PATH
}
begin_edit() {
    BEFORE=$(git hash-object -- "$FILE")
    EDIT_FILE=$(mktemp "$TASK_DIR/.task-XXXXXX")
}
finish_edit() {
    LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -f "$SCRIPT_DIR/task-format.awk" "$EDIT_FILE" || fail "La operación no cumple las reglas de la tarea"
    [ "$(git hash-object -- "$FILE")" = "$BEFORE" ] || fail "La tarea cambió mientras se editaba; se conserva la versión más reciente"
    mv "$EDIT_FILE" "$FILE"
    EDIT_FILE=
    printf 'TASK_STATUS=UPDATED\nTASK_ID=%s\nTASK_FILE=%s\n' "$ID" "$FILE"
}
usage() {
    cat <<'EOF'
Uso: sh .agents/scripts/tasks.sh <operación>
  create "título" "objetivo" "criterio" ["otro criterio" ...]
  list [pendiente|"en curso"|bloqueada|terminada]
  show ID
  status ID pendiente|"en curso"|bloqueada|terminada ["motivo o resultado"]
  verify ID número "evidencia observada"
  unverify ID número
  checkpoint ID "nota del punto de guardado"
  history ID [límite]
  lint
Los cambios quedan sin guardar hasta crear un punto de guardado.
EOF
}
COMMAND=${1:-help}
[ "$#" -eq 0 ] || shift
case "$COMMAND" in help|--help) usage; exit 0 ;; esac
[ -e .git ] || fail "Ejecuta primero el diagnóstico e inicializa el repositorio"
case "$COMMAND" in
    history|lint) ;; # Historial y diagnósticos siguen disponibles con tareas locales inválidas.
    *) sh "$SCRIPT_DIR/tasks-lint.sh" >/dev/null || fail "Hay tareas inválidas; ejecuta tasks.sh lint" ;;
esac
case "$COMMAND" in
    create)
        [ "$#" -ge 3 ] || fail "create requiere título, objetivo y al menos un criterio"
        for TEXT in "$@"; do require_text "$TEXT"; done
        lock_tasks
        mkdir -p "$TASK_DIR"
        NONCE=0
        while :; do
            HASH=$(printf '%s\n' "$@" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$$" "$NONCE" "$(git var GIT_AUTHOR_IDENT)" | git hash-object --stdin)
            ID=T-$(printf '%s' "$HASH" | cut -c 1-12)
            FILE=$TASK_DIR/$ID.md
            [ -e "$FILE" ] || [ -L "$FILE" ] || break
            NONCE=$((NONCE + 1))
        done
        EDIT_FILE=$(mktemp "$TASK_DIR/.task-XXXXXX")
        TITLE=$1 OBJECTIVE=$2
        shift 2
        {
            printf '# %s\n\nID: %s\nEstado: pendiente\n\n## Objetivo\n%s\n\n## Criterios de aceptación\n' "$TITLE" "$ID" "$OBJECTIVE"
            for CRITERION in "$@"; do printf '%s\n' "- [ ] $CRITERION"; done
            printf '\n## Resultado\n\n## Motivo del estado\n'
        } > "$EDIT_FILE"
        LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -f "$SCRIPT_DIR/task-format.awk" "$EDIT_FILE" || fail "Tarea inválida"
        mv "$EDIT_FILE" "$FILE"
        EDIT_FILE=
        printf 'TASK_STATUS=CREATED\nTASK_ID=%s\nTASK_FILE=%s\n' "$ID" "$FILE"
        ;;
    list)
        [ "$#" -le 1 ] || fail "list admite solo un filtro de estado"
        FILTER=${1:-}
        case "$FILTER" in ''|pendiente|'en curso'|bloqueada|terminada) ;; *) fail "Estado desconocido" ;; esac
        printf 'TASK_LIST_STATUS=OK\n'
        for FILE in "$TASK_DIR"/T-*.md; do
            [ -f "$FILE" ] || continue
            NAME=${FILE##*/}; ID=${NAME%.md}
            STATE=$(field state)
            [ -z "$FILTER" ] || [ "$STATE" = "$FILTER" ] || continue
            printf '\nTASK_ID=%s\nESTADO=%s\nTITULO=%s\n' "$ID" "$STATE" "$(field title)"
        done
        ;;
    show)
        [ "$#" -eq 1 ] || fail "show requiere un ID"
        load_task "$1"
        cat "$FILE"
        ;;
    status)
        [ "$#" -ge 2 ] && [ "$#" -le 3 ] || fail "status requiere ID, estado y, si corresponde, motivo o resultado"
        lock_tasks
        load_task "$1"
        NEXT=$2 NOTE=${3:-}
        case "$NEXT" in pendiente|'en curso'|bloqueada|terminada) ;; *) fail "Estado desconocido" ;; esac
        if [ "$NEXT" = bloqueada ] || [ "$NEXT" = terminada ] || [ "$STATE" = terminada ]; then require_text "$NOTE"; fi
        [ -z "$NOTE" ] || require_text "$NOTE"
        begin_edit
        TASK_NEXT=$NEXT TASK_NOTE=$NOTE LC_ALL=C awk '
            BEGIN {state=ENVIRON["TASK_NEXT"]; note=ENVIRON["TASK_NOTE"]}
            /^Estado: / && !body {print "Estado: " state; next}
            /^## / {
                body=1; skip=0
                if ($0 == "## Resultado" && state == "terminada") {print; print note; print ""; skip=1; next}
                if ($0 == "## Motivo del estado") {print; if (state != "terminada") print note; print ""; skip=1; next}
            }
            !skip {print}
        ' "$FILE" > "$EDIT_FILE"
        finish_edit
        ;;
    verify|unverify)
        if [ "$COMMAND" = verify ]; then [ "$#" -eq 3 ] || fail "verify requiere ID, número y evidencia"; require_text "$3"
        else [ "$#" -eq 2 ] || fail "unverify requiere ID y número"; fi
        lock_tasks
        load_task "$1"
        [ "$STATE" != terminada ] || fail "Reabre la tarea con un motivo antes de modificar sus criterios"
        NUMBER=$2
        case "$NUMBER" in ''|*[!0-9]*|0|0*) fail "Número de criterio inválido" ;; esac
        [ "${#NUMBER}" -le 6 ] && [ "$NUMBER" -le "$(field criteria)" ] || fail "No existe ese criterio"
        begin_edit
        TASK_EVIDENCE=${3:-} LC_ALL=C awk -v number="$NUMBER" -v action="$COMMAND" '
            /^## / {criteria=($0 == "## Criterios de aceptación"); skip=0}
            criteria && /^- \[[ x]\] / {
                n++; skip=(n == number)
                if (skip) {
                    print "- [" (action == "verify" ? "x" : " ") "] " substr($0, 7)
                    if (action == "verify") print "  Evidencia: " ENVIRON["TASK_EVIDENCE"]
                    next
                }
            }
            criteria && skip && /^  Evidencia: / {next}
            {print}
        ' "$FILE" > "$EDIT_FILE"
        finish_edit
        ;;
    checkpoint)
        [ "$#" -eq 2 ] || fail "checkpoint requiere ID y una nota"
        load_task "$1"
        sh "$SCRIPT_DIR/git-ops.sh" checkpoint "$2" --task "$ID"
        ;;
    history)
        [ "$#" -ge 1 ] && [ "$#" -le 2 ] || fail "history requiere ID y un límite opcional"
        ID=$1 LIMIT=${2:-10}
        valid_id "$ID" || fail "ID inválido"
        case "$LIMIT" in ''|*[!0-9]*|0|0*) fail "Límite inválido" ;; esac
        [ "${#LIMIT}" -le 6 ] || fail "Límite demasiado grande"
        printf 'TASK_HISTORY_STATUS=OK\nTASK_ID=%s\n' "$ID"
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            git log --format='%H' -- "$TASK_DIR/$ID.md" > "$TMP/paths"
            git log --format='%H%x09%(trailers:key=Task-ID,valueonly,separator=%x2c)' > "$TMP/log"
            LC_ALL=C awk -F '\t' -v id="$ID" -v limit="$LIMIT" '
                FILENAME == ARGV[1] {paths[$0]=1; next}
                {
                    found=($1 in paths); n=split($2, ids, ",")
                    for (i=1; i<=n; i++) if (ids[i] == id) found=1
                    if (found && count++ < limit) print $1
                }
            ' "$TMP/paths" "$TMP/log" > "$TMP/selected"
            while IFS= read -r REF; do
                git show -s --date=format:'%Y-%m-%d %H:%M' --format='PUNTO=%h | %ad | %s' "$REF"
            done < "$TMP/selected"
        fi
        ;;
    lint)
        [ "$#" -eq 0 ] || fail "lint no admite argumentos"
        sh "$SCRIPT_DIR/tasks-lint.sh"
        ;;
    *) usage; fail "Operación desconocida: $COMMAND" ;;
esac
