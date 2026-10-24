#!/bin/sh
# Funciones del registro de intentos. Se cargan desde el gestor y su validador.
attempt_field() {
    LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -v field="$2" -v attempt_id="${3:-}" \
        -f "$SCRIPT_DIR/task-format.awk" "$1"
}

attempt_saved_task() {
    AT_ENTRY=$(git ls-tree "$1" -- ":(literal)$FILE")
    case "$AT_ENTRY" in
        '100644 blob '*|'100755 blob '*) ;;
        *) fail "El punto del intento debe contener la tarea como archivo regular" ;;
    esac
    git cat-file blob "$1:$FILE" > "$TMP/attempt-task" || fail "No se pudo leer la tarea del intento"
}

attempt_validate() {
    AV_SOURCE=$1
    attempt_field "$AV_SOURCE" attempts > "$TMP/attempts"
    AV_TAB=$(printf '\t')
    while IFS="$AV_TAB" read -r AV_ID AV_BASE AV_OUTCOME AV_PATH AV_POINT; do
        add_point "$AV_BASE"
        attempt_saved_task "$AV_BASE"
        AV_PREVIOUS=$(attempt_field "$TMP/attempt-task" attempt-count)
        AV_NUMBER=$(printf '%s' "$AV_ID" | sed 's/^I-0*//')
        [ "$AV_PREVIOUS" -eq "$((AV_NUMBER - 1))" ] &&
            [ -z "$(attempt_field "$TMP/attempt-task" attempt-open-id)" ] &&
            [ "$(attempt_field "$TMP/attempt-task" state)" != terminada ] || fail "La base no corresponde al inicio de ese intento"
        if [ "$AV_OUTCOME" != abierto ]; then
            add_artifact "$AV_PATH" "$AV_POINT"
            git merge-base --is-ancestor "$AV_BASE" "$AV_POINT" 2>/dev/null || fail "La evidencia del intento debe ser posterior a su base"
            attempt_saved_task "$AV_POINT"
            AV_ORIGINAL=$(attempt_field "$TMP/attempt-task" attempt-open-context "$AV_ID")
            [ -n "$AV_ORIGINAL" ] && [ "$AV_ORIGINAL" = "$(attempt_field "$AV_SOURCE" attempt-context "$AV_ID")" ] ||
                fail "Guarda el inicio del intento antes de vincular su evidencia; su contexto debe coincidir"
        fi
    done < "$TMP/attempts"
}
