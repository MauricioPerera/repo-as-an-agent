#!/bin/sh
# Lector Git privado para agent-eval check. No cargar configuración, hooks,
# filtros, reemplazos ni alternates del repositorio evaluado. No es aislamiento OS.
eval_git_reader() {
    [ -d .git ] && [ ! -L .git ] || fail "La evaluación requiere una copia autónoma con .git regular"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
        GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL \
        GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_SHALLOW_FILE GIT_REPLACE_REF_BASE \
        GIT_NAMESPACE GIT_DEFAULT_HASH GIT_TEMPLATE_DIR || true
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0
    export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT
    # No permitir que objetos, referencias o el índice salgan de la copia.
    for READER_PART in objects refs; do
        [ -d ".git/$READER_PART" ] && [ ! -L ".git/$READER_PART" ] || fail "Metadatos Git no regulares"
        find ".git/$READER_PART" ! -type d ! -type f -print > "$TMP/types" || fail "No se pudieron inspeccionar los metadatos"
        [ ! -s "$TMP/types" ] || fail "Los metadatos Git no pueden atravesar enlaces"
        find ".git/$READER_PART" -type f -links +1 -print > "$TMP/types" || fail "No se pudieron inspeccionar los metadatos"
        [ ! -s "$TMP/types" ] || fail "Los metadatos Git no pueden atravesar enlaces"
    done
    [ ! -e .git/objects/info/alternates ] && [ ! -L .git/objects/info/alternates ] || fail "No se admiten objetos externos mediante alternates"
    for READER_PART in HEAD index packed-refs shallow config; do
        [ ! -L ".git/$READER_PART" ] || fail "Los metadatos Git no pueden atravesar enlaces"
        [ ! -e ".git/$READER_PART" ] || [ -f ".git/$READER_PART" ] || fail "Metadatos Git no regulares"
        if [ -f ".git/$READER_PART" ]; then
            find ".git/$READER_PART" -links +1 -print > "$TMP/types" || fail "No se pudieron inspeccionar los metadatos"
            [ ! -s "$TMP/types" ] || fail "Los metadatos Git no pueden atravesar enlaces"
        fi
    done
    [ -f .git/HEAD ] && [ -f .git/index ] || fail "Faltan metadatos de la copia preparada"
    # El código evaluado no controla este directorio ni su configuración. Solo
    # se copian datos de objetos, referencias e índice; nunca config ni hooks.
    # Leer únicamente el formato como dato; --no-includes impide seguir archivos
    # externos. Nunca copiar ni aplicar esta configuración al lector.
    READER_FORMAT=sha1
    if [ -f .git/config ]; then
        if READER_VALUE=$(command git -C "$TMP" config --file "$TARGET/.git/config" --no-includes --get extensions.objectFormat); then
            case "$READER_VALUE" in sha1|sha256) READER_FORMAT=$READER_VALUE ;; *) fail "Formato de objetos no admitido" ;; esac
        else
            READER_CODE=$?
            [ "$READER_CODE" -eq 1 ] || fail "No se pudo inspeccionar el formato de objetos"
        fi
    fi
    if [ "$READER_FORMAT" = sha256 ]; then
        command git init --bare --template= --object-format=sha256 "$TMP/reader" >/dev/null 2>&1 || fail "No se pudo crear el lector SHA-256"
    else
        command git init --bare --template= "$TMP/reader" >/dev/null 2>&1 || fail "No se pudo crear el lector Git privado"
    fi
    cp -R .git/objects/. "$TMP/reader/objects/" || fail "No se pudieron capturar los objetos"
    cp -R .git/refs/. "$TMP/reader/refs/" || fail "No se pudieron capturar las referencias"
    for READER_PART in HEAD index packed-refs shallow; do
        [ ! -f ".git/$READER_PART" ] || cp ".git/$READER_PART" "$TMP/reader/$READER_PART" || fail "No se pudieron capturar los metadatos"
    done
    # Usar argumentos, que Git Bash convierte también en Windows; no rutas POSIX
    # en variables de entorno destinadas al ejecutable nativo.
    git() {
        command git --no-replace-objects --git-dir="$TMP/reader" --work-tree="$TARGET" \
            -c core.bare=false -c core.autocrlf=input -c core.fsmonitor=false -c core.hooksPath=/dev/null \
            -c core.attributesFile=/dev/null -c submodule.recurse=false "$@"
    }
}
