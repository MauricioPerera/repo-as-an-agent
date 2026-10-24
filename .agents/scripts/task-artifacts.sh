#!/bin/sh
# Funciones compartidas del piloto ADD. Solo Git y utilidades POSIX.
# El llamador ya está en la raíz y aporta fail(). Nunca se ejecutan los artefactos.
add_path() {
    case "$1" in
        workspace/*) ;;
        *) fail "El artefacto debe estar dentro de workspace/" ;;
    esac
    case "/$1/" in
        */../*|*/./*|*//*|*\\*|*:*|*/.git/*|*/documentos/tareas/*)
            fail "Ruta de artefacto no portable o reservada: $1" ;;
    esac
}

add_point() {
    # --end-of-options impide interpretar el texto recibido como opciones de Git.
    ADD_POINT=$(git rev-parse --verify --end-of-options "$1^{commit}" 2>/dev/null) || fail "No existe ese punto de guardado en el historial local"
    git merge-base --is-ancestor "$ADD_POINT" HEAD 2>/dev/null || fail "El punto debe pertenecer al historial del borrador actual"
}

add_artifact() {
    add_path "$1"
    add_point "$2"
    ADD_ENTRY=$(git ls-tree "$ADD_POINT" -- ":(literal)$1")
    case "$ADD_ENTRY" in
        '100644 blob '*|'100755 blob '*) ;;
        *) fail "El punto no contiene un archivo regular para el artefacto: $1" ;;
    esac
    ADD_SIZE=$(git cat-file -s "$ADD_POINT:$1") || fail "No se pudo leer el artefacto"
    [ "$ADD_SIZE" -gt 0 ] || fail "El artefacto está vacío: $1"
}

add_validate() {
    # El formato ya fue comprobado; las rutas no pueden contener tabuladores.
    LC_ALL=C awk -v expected_id="$ID" -v display="$FILE" -v field=artifacts -f "$SCRIPT_DIR/task-format.awk" "$1" > "$TMP/artifacts"
    ADD_TAB=$(printf '\t')
    while IFS="$ADD_TAB" read -r ADD_KIND ADD_PATH ADD_REF; do
        case "$ADD_KIND" in attempt-*) continue ;; esac
        add_artifact "$ADD_PATH" "$ADD_REF"
        if [ "$ADD_KIND" != agreement ]; then
            git merge-base --is-ancestor "$ADD_AGREEMENT_POINT" "$ADD_REF" 2>/dev/null || fail "La evidencia debe ser del punto acordado o de uno posterior de su historial"
        else
            ADD_AGREEMENT_POINT=$ADD_REF
        fi
    done < "$TMP/artifacts"
    attempt_validate "$1"
}
