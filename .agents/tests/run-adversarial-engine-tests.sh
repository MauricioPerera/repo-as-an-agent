#!/bin/sh
# Fase 2 priorizada: ataques deterministas contra una copia confiable del motor.
# Los informes son privados. No ejecuta agentes, conectores ni campañas de modelos.
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
CASES='REC-06 ENT-01 ENT-03 ENT-06 TAR-06 EVA-02 EVA-04'
exec 3>&1
error() {
    REPORTED=yes
    [ -z "${WORK:-}" ] || [ ! -d "$WORK/semilla" ] || KEEP=yes
    printf 'ENGINE_STATUS=ERROR\nREASON=%s\n' "$1" >&3
    exit 2
}
text_path() {
    case "$1" in ''|*'
'*) return 1 ;; esac
    printf '%s\n' "$1" | LC_ALL=C awk '/[[:cntrl:]]/ {exit 1}'
}
manifest() (
    cd "$1" || exit 1
    # Solo archivos regulares, nombres sin controles y ninguna ruta enlazada.
    find . ! -type d ! -type f -print > "$2/types" || exit 1
    [ ! -s "$2/types" ] || exit 1
    find . -type f -links +1 -print > "$2/types" || exit 1
    [ ! -s "$2/types" ] || exit 1
    find . -exec sh -c 'for p do case "$p" in *[[:cntrl:]]*) exit 1;; esac; done' sh {} + || exit 1
    find . -type f ! -path './huellas.tsv' -print > "$2/unsorted" || exit 1
    LC_ALL=C sort "$2/unsorted" > "$2/paths" || exit 1
    while IFS= read -r FILE; do
        DIGEST=$(git hash-object --no-filters -- "$FILE") || exit 1
        printf '%s\n' "$DIGEST" | LC_ALL=C grep -Eq '^[0-9a-f]{40}$' || exit 1
        printf '%s\t%s\n' "$DIGEST" "$FILE"
    done < "$2/paths"
)
COMMAND=${1:-run}
[ "$#" -eq 0 ] || shift
case "$COMMAND" in
    list)
        [ "$#" -eq 0 ] || error ARGUMENTS
        printf 'REC-06 P0: fallos de guardado y publicación de una escritura\nENT-01 P0: argumentos literales, sin ejecución\nENT-03 P0: credenciales ficticias preparadas\nENT-06 P1: fallos de lectura, cierre por defecto\nTAR-06 P0: bloqueo ajeno y edición concurrente\nEVA-02 P0: código, filtros y configuración Git no ejecutados\nEVA-04 P0: contrato fijado y sustitución de historial\n'
        exit 0 ;;
    help|--help)
        printf 'Uso: sh .agents/tests/run-adversarial-engine-tests.sh list\n     sh .agents/tests/run-adversarial-engine-tests.sh run [carpeta-evidencia-nueva]\n     sh .agents/tests/run-adversarial-engine-tests.sh verify carpeta-evidencia HUELLA\n'
        exit 0 ;;
    run|verify) ;;
    *) error UNKNOWN_COMMAND ;;
esac
# Aislar también el entorno Git heredado. Nunca se cambia HOME ni configuración real.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG_PARAMETERS GIT_CONFIG_SYSTEM \
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
    GIT_DEFAULT_HASH GIT_TEMPLATE_DIR || true
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=0
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT
for TOOL in git sh awk find sort cp cmp mktemp ln uname; do command -v "$TOOL" >/dev/null 2>&1 || error MISSING_TOOL; done
WORK_PARENT=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
if [ "$COMMAND" = verify ]; then
    [ "$#" -eq 2 ] && text_path "$1" || error ARGUMENTS
    [ -d "$1" ] && [ ! -L "$1" ] || error EVIDENCE_DIRECTORY_INVALID
    EVIDENCE=$(CDPATH= cd -- "$1" && pwd -P)
    case "$WORK_PARENT/" in "$EVIDENCE/"*) error TEMP_DIRECTORY_OVERLAP ;; esac
fi
WORK=$(mktemp -d "$WORK_PARENT/agty-engine-work.XXXXXX") || error TEMP_DIRECTORY_ERROR
WORK=$(CDPATH= cd -- "$WORK" && pwd -P)
KEEP=no
REPORTED=no
cleanup() {
    CODE=$?
    trap - EXIT
    set +e
    if [ "$CODE" -ne 0 ] && [ "$REPORTED" = no ]; then
        printf 'ENGINE_STATUS=ERROR\nREASON=UNEXPECTED_FAILURE\n'
        KEEP=yes
        CODE=2
    fi
    if [ "$KEEP" = yes ]; then printf 'PRIVATE_FIXTURES=%s\n' "$WORK"
    else
        RESOLVED=$(CDPATH= cd -- "$WORK" && pwd -P)
        case "$RESOLVED" in "$WORK_PARENT"/agty-engine-work.*) rm -rf -- "$RESOLVED" ;; esac
    fi
    exit "$CODE"
}
trap cleanup EXIT
trap 'exit 2' HUP INT TERM
if [ "$COMMAND" = verify ]; then
    [ "$#" -eq 2 ] && text_path "$1" || error ARGUMENTS
    printf '%s\n' "$2" | LC_ALL=C grep -Eq '^[0-9a-f]{40}$' || error ARGUMENTS
    [ -d "$1" ] && [ ! -L "$1" ] || error EVIDENCE_DIRECTORY_INVALID
    EVIDENCE=$(CDPATH= cd -- "$1" && pwd -P)
    manifest "$EVIDENCE" "$WORK" > "$WORK/manifest" || error EVIDENCE_READ_ERROR
    [ -f "$EVIDENCE/huellas.tsv" ] && cmp -s "$WORK/manifest" "$EVIDENCE/huellas.tsv" || error EVIDENCE_INTEGRITY_ERROR
    [ "$(git hash-object --no-filters -- "$WORK/manifest")" = "$2" ] || error EVIDENCE_INTEGRITY_ERROR
    REPORTED=yes
    printf 'ENGINE_EVIDENCE_STATUS=PASS\nSCOPE=integridad, no aprobación de campaña\n'
    exit 0
fi
[ "$#" -le 1 ] || error ARGUMENTS
if [ "$#" -eq 0 ]; then
    mkdir -p "$SOURCE/.tmp-test"
    EVIDENCE=$(mktemp -d "$SOURCE/.tmp-test/fase2.XXXXXX") || error EVIDENCE_DIRECTORY_ERROR
else
    text_path "$1" && [ ! -e "$1" ] && [ ! -L "$1" ] || error DESTINATION_EXISTS_OR_INVALID
    PARENT=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd -P) || error DESTINATION_PARENT_INVALID
    NAME=$(basename -- "$1")
    case "$NAME" in ''|.|..|.git) error DESTINATION_INVALID ;; esac
    EVIDENCE=$PARENT/$NAME
    # No escribir infraestructura dentro de las zonas de la persona o del motor.
    LOWER=$(printf '%s/' "$EVIDENCE" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    LOWER_SOURCE=$(printf '%s' "$SOURCE" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    case "$LOWER" in "$LOWER_SOURCE/workspace/"*|"$LOWER_SOURCE/knowledge/"*|"$LOWER_SOURCE/.agents/"*) error USER_ZONE_DESTINATION ;; esac
    mkdir -- "$EVIDENCE" || error EVIDENCE_DIRECTORY_ERROR
fi
EVIDENCE=$(CDPATH= cd -- "$EVIDENCE" && pwd -P)
printf '*\n' > "$EVIDENCE/.gitignore"
printf '*\n' > "$WORK/.gitignore"
SEED=$WORK/semilla
mkdir -p "$SEED/.agents" "$SEED/docs" "$SEED/knowledge" "$SEED/.agents/skills"
for PART in scripts hooks evals; do cp -R "$SOURCE/.agents/$PART" "$SEED/.agents/$PART"; done
cp "$SOURCE/.agents/tests/adversarial-engine-cases.sh" "$WORK/casos.sh"
cp "$SOURCE/.gitattributes" "$SOURCE/.gitignore" "$SEED/"
printf '# Instrucciones ficticias del ensayo\n' > "$SEED/AGENTS.md"
printf '# Índice ficticio\n' > "$SEED/knowledge/index.md"
printf '# Bitácora ficticia\n' > "$SEED/knowledge/log.md"
for DOC in piloto-add.md evaluaciones-e-intentos.md; do printf '# Guía ficticia\n' > "$SEED/docs/$DOC"; done
sh "$SEED/.agents/scripts/bootstrap.sh" > "$EVIDENCE/preparacion.txt" 2>&1 || error SEED_PREPARATION_ERROR
sh "$SEED/.agents/scripts/git-ops.sh" checkpoint 'Base ficticia de fase 2' >> "$EVIDENCE/preparacion.txt" 2>&1 || error SEED_CHECKPOINT_ERROR
BASE_POINT=$(git -C "$SOURCE" rev-parse --verify HEAD) || error BASE_POINT_ERROR
{
    printf '# Fase 2: controles deterministas priorizados\n\n'
    printf 'Inicio UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'Punto del motor: %s\n' "$BASE_POINT"
    printf 'Git: %s\nSistema: %s\n' "$(git --version)" "$(uname -s)"
    printf 'Modalidad: simulaciones deterministas; sin modelos ni aislamiento OS acreditado\n'
    printf 'Catálogo: siete escenarios seleccionados; no acredita los 60 ni todas sus variantes\n'
} > "$EVIDENCE/informe.md"
# Las huellas incluyen los bytes probados aunque haya cambios aún sin guardar.
{
    for FILE in "$SEED/.agents/scripts/"*.sh "$SEED/.agents/scripts/"*.awk "$SEED/.agents/hooks/"*; do
        DIGEST=$(git hash-object --no-filters -- "$FILE") || error MOTOR_HASH_ERROR
        printf '%s\t%s\n' "$DIGEST" "${FILE#"$SEED/"}"
    done
    DIGEST=$(git hash-object --no-filters -- "$WORK/casos.sh") || error MOTOR_HASH_ERROR
    printf '%s\t.agents/tests/adversarial-engine-cases.sh\n' "$DIGEST"
    DIGEST=$(git hash-object --no-filters -- "$SOURCE/.agents/tests/run-adversarial-engine-tests.sh") || error MOTOR_HASH_ERROR
    printf '%s\t.agents/tests/run-adversarial-engine-tests.sh\n' "$DIGEST"
} > "$EVIDENCE/motor.tsv"
printf 'escenario\tresultado\tcodigo\tinicio_utc\tfin_utc\n' > "$EVIDENCE/resultados.tsv"
PASS=0 FAIL=0 ERRORS=0 SUBVARIANT_SKIPS=0
for ID in $CASES; do
    mkdir "$EVIDENCE/$ID"
    CASE_START=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    if sh "$WORK/casos.sh" "$ID" "$SEED" "$WORK/$ID" "$EVIDENCE/$ID" "$SEED" > "$EVIDENCE/$ID/ejecucion.txt" 2>&1; then CODE=0; else CODE=$?; fi
    case "$CODE" in
        0) RESULT=PASS; PASS=$((PASS + 1)) ;;
        1) RESULT=FAIL; FAIL=$((FAIL + 1)); KEEP=yes ;;
        *) RESULT=ERROR; ERRORS=$((ERRORS + 1)); KEEP=yes ;;
    esac
    CASE_SKIPS=$(grep -c '^SUBVARIANT_SKIP=' "$EVIDENCE/$ID/ejecucion.txt" || :)
    SUBVARIANT_SKIPS=$((SUBVARIANT_SKIPS + CASE_SKIPS))
    printf '%s\t%s\t%s\t%s\t%s\n' "$ID" "$RESULT" "$CODE" "$CASE_START" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$EVIDENCE/resultados.tsv"
    printf '[%s] %s\n' "$RESULT" "$ID"
done
printf '\nFin UTC: %s\nPASS=%s FAIL=%s ERROR=%s SKIP=0 PREVISTOS=7 SUBVARIANT_SKIP=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$PASS" "$FAIL" "$ERRORS" "$SUBVARIANT_SKIPS" >> "$EVIDENCE/informe.md"
manifest "$EVIDENCE" "$WORK" > "$WORK/manifest" || error EVIDENCE_READ_ERROR
cp "$WORK/manifest" "$EVIDENCE/huellas.tsv"
SEAL=$(git hash-object --no-filters -- "$WORK/manifest") || error EVIDENCE_HASH_ERROR
STATUS=PASS CODE=0
if [ "$ERRORS" -ne 0 ]; then STATUS=ERROR CODE=2
elif [ "$FAIL" -ne 0 ]; then STATUS=FAIL CODE=1; fi
printf 'ENGINE_STATUS=%s\nPASS=%s\nFAIL=%s\nERROR=%s\nSKIP=0\nPLANNED=7\nSUBVARIANT_SKIP=%s\nEVIDENCE=%s\nEVIDENCE_SEAL=%s\nOS_ISOLATION=not_attested\n' "$STATUS" "$PASS" "$FAIL" "$ERRORS" "$SUBVARIANT_SKIPS" "$EVIDENCE" "$SEAL"
REPORTED=yes
exit "$CODE"
