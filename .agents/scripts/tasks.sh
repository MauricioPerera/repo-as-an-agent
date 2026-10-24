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
    rm -f "$TMP/paths" "$TMP/log" "$TMP/selected" "$TMP/msg" "$TMP/artifacts" "$TMP/attempts" "$TMP/attempt-task"
    rmdir "$TMP"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
fail() { printf 'TASK_STATUS=FAIL\nERROR=%s\n' "$1"; exit 1; }
. "$SCRIPT_DIR/task-artifacts.sh"
. "$SCRIPT_DIR/task-attempts.sh"
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
    add_validate "$EDIT_FILE"
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
  agree ID ruta punto "qué se acordó y de dónde surge"
  deliver ID número ruta punto "qué se comprobó"
  attempt-start ID "agente" "acción prevista" "herramienta"
  attempt-finish ID I-000001 exito|fallo|interrumpido ruta punto "resultado observado"
  attempts ID
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
        if [ "$COMMAND" = verify ] && [ "$(field add)" = yes ]; then
            fail "En el piloto ADD usa deliver para vincular la evidencia al criterio y a su punto"
        fi
        NUMBER=$2
        case "$NUMBER" in ''|*[!0-9]*|0|0*) fail "Número de criterio inválido" ;; esac
        [ "${#NUMBER}" -le 6 ] && [ "$NUMBER" -le "$(field criteria)" ] || fail "No existe ese criterio"
        begin_edit
        TASK_EVIDENCE=${3:-} LC_ALL=C awk -v number="$NUMBER" -v action="$COMMAND" '
            /^## Evidencias de entrega$/ {delivery_section=1; delivery_skip=0}
            /^## / && $0 != "## Evidencias de entrega" {delivery_section=0; delivery_skip=0}
            delivery_section && /^### Criterio / {delivery_skip=(substr($0, 14) + 0 == number)}
            delivery_skip {next}
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
    agree)
        [ "$#" -eq 4 ] || fail "agree requiere ID, ruta, punto y el acuerdo observado"
        require_text "$2"; require_text "$3"; require_text "$4"
        lock_tasks
        load_task "$1"
        [ "$STATE" != terminada ] || fail "Reabre la tarea con un motivo antes de cambiar el acuerdo"
        add_artifact "$2" "$3"
        ADD_NEW=$(printf '%s\t%s\t%s' "$2" "$ADD_POINT" "$4")
        if [ "$(field agreement)" = "$ADD_NEW" ]; then
            printf 'TASK_STATUS=NO_CHANGES\nTASK_ID=%s\n' "$ID"
            exit 0
        fi
        begin_edit
        TASK_ARTIFACT=$2 TASK_POINT=$ADD_POINT TASK_NOTE=$4 LC_ALL=C awk '
            /^## / {
                skip=($0 == "## Referencia acordada" || $0 == "## Evidencias de entrega")
                criteria=($0 == "## Criterios de aceptación")
            }
            skip {next}
            criteria && /^- \[[ x]\] / {print "- [ ] " substr($0, 7); next}
            criteria && /^  Evidencia: / {next}
            {print}
            END {
                print "\n## Referencia acordada\nArchivo: " ENVIRON["TASK_ARTIFACT"]
                print "Punto: " ENVIRON["TASK_POINT"] "\nAcuerdo: " ENVIRON["TASK_NOTE"]
                print "\n## Evidencias de entrega\n"
            }
        ' "$FILE" > "$EDIT_FILE"
        finish_edit
        ;;
    deliver)
        [ "$#" -eq 5 ] || fail "deliver requiere ID, número de criterio, ruta, punto y observación"
        require_text "$3"; require_text "$4"; require_text "$5"
        lock_tasks
        load_task "$1"
        [ "$STATE" != terminada ] || fail "Reabre la tarea con un motivo antes de modificar sus entregas"
        [ "$(field add)" = yes ] || fail "Registra primero una referencia acordada con agree"
        NUMBER=$2
        case "$NUMBER" in ''|*[!0-9]*|0|0*) fail "Número de criterio inválido" ;; esac
        [ "${#NUMBER}" -le 6 ] && [ "$NUMBER" -le "$(field criteria)" ] || fail "No existe ese criterio"
        add_artifact "$3" "$4"
        begin_edit
        TASK_ARTIFACT=$3 TASK_POINT=$ADD_POINT TASK_NOTE=$5 LC_ALL=C awk -v number="$NUMBER" '
            function record() {
                print "### Criterio " number "\nArchivo: " ENVIRON["TASK_ARTIFACT"]
                print "Punto: " ENVIRON["TASK_POINT"] "\nObservación: " ENVIRON["TASK_NOTE"] "\n"
            }
            /^## / {
                delivery=($0 == "## Evidencias de entrega"); skip=0
                criteria=($0 == "## Criterios de aceptación"); criterion_skip=0
                if (delivery) {print; print ""; record(); next}
            }
            delivery && /^### Criterio / {skip=(substr($0, 14) + 0 == number)}
            skip {next}
            criteria && /^- \[[ x]\] / {
                n++; criterion_skip=(n == number)
                if (criterion_skip) {print "- [x] " substr($0, 7); print "  Evidencia: " ENVIRON["TASK_NOTE"]; next}
            }
            criteria && criterion_skip && /^  Evidencia: / {next}
            {print}
        ' "$FILE" > "$EDIT_FILE"
        finish_edit
        ;;
    attempt-start)
        [ "$#" -eq 4 ] || fail "attempt-start requiere ID, agente, acción y herramienta"
        require_text "$2"; require_text "$3"; require_text "$4"
        lock_tasks
        load_task "$1"
        [ "$STATE" != terminada ] || fail "Reabre la tarea antes de iniciar otro intento"
        [ -z "$(field attempt-open-id)" ] || fail "Termina o interrumpe el intento abierto antes de iniciar otro"
        add_point HEAD
        AT_BASE=$ADD_POINT
        attempt_saved_task "$AT_BASE"
        [ "$(git hash-object -- "$FILE")" = "$(git hash-object -- "$TMP/attempt-task")" ] ||
            fail "Guarda la tarea actual antes de iniciar el intento para conservar su contexto"
        AT_COUNT=$(field attempt-count)
        [ "$AT_COUNT" -lt 999999 ] || fail "Se alcanzó el límite de intentos de esta tarea"
        AT_ID=$(printf 'I-%06d' "$((AT_COUNT + 1))")
        begin_edit
        AT_ID=$AT_ID AT_AGENT=$2 AT_ACTION=$3 AT_TOOL=$4 AT_BASE=$AT_BASE AT_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ') \
            LC_ALL=C awk -v action=start -f "$SCRIPT_DIR/task-attempt-edit.awk" "$FILE" > "$EDIT_FILE"
        finish_edit
        printf 'ATTEMPT_ID=%s\nATTEMPT_OUTCOME=abierto\n' "$AT_ID"
        ;;
    attempt-finish)
        [ "$#" -eq 6 ] || fail "attempt-finish requiere ID, intento, desenlace, ruta, punto y observación"
        require_text "$4"; require_text "$5"; require_text "$6"
        case "$3" in exito|fallo|interrumpido) ;; *) fail "Desenlace desconocido" ;; esac
        lock_tasks
        load_task "$1"
        [ -n "$2" ] && [ "$2" = "$(field attempt-open-id)" ] || fail "Ese intento no está abierto en esta tarea"
        AT_ID=$2
        add_artifact "$4" "$5"
        begin_edit
        AT_ID=$AT_ID AT_OUTCOME=$3 AT_PATH=$4 AT_POINT=$ADD_POINT AT_NOTE=$6 AT_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ') \
            LC_ALL=C awk -v action=finish -f "$SCRIPT_DIR/task-attempt-edit.awk" "$FILE" > "$EDIT_FILE"
        finish_edit
        printf 'ATTEMPT_ID=%s\nATTEMPT_OUTCOME=%s\n' "$AT_ID" "$3"
        ;;
    attempts)
        [ "$#" -eq 1 ] || fail "attempts requiere un ID"
        load_task "$1"
        printf 'ATTEMPT_LIST_STATUS=OK\nTASK_ID=%s\n' "$ID"
        LC_ALL=C awk '/^## / {show=($0 == "## Intentos de ejecución")} show {print}' "$FILE"
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
            FILE=$TASK_DIR/$ID.md
            if [ -f "$FILE" ] && [ ! -L "$FILE" ]; then
                if LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -v field=artifacts -f "$SCRIPT_DIR/task-format.awk" "$FILE" > "$TMP/artifacts"; then
                    LC_ALL=C awk -F '\t' '{print $3}' "$TMP/artifacts" >> "$TMP/paths"
                fi
            fi
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
