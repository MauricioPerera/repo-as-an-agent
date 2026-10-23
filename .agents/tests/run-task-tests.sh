#!/bin/sh
# Pruebas de comportamiento del gestor en un repositorio temporal con espacios.
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
SANDBOX=$(mktemp -d "$TMP_ROOT/agty-task-tests.XXXXXX")
cleanup() {
    RESOLVED=$(CDPATH= cd -- "$SANDBOX" && pwd -P)
    case "$RESOLVED" in "$TMP_ROOT"/agty-task-tests.*) rm -rf -- "$RESOLVED" ;; esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$SANDBOX/repo con espacios" "$SANDBOX/home/.config"
cp -R "$SOURCE/.agents" "$SANDBOX/repo con espacios/.agents"
cp -R "$SOURCE/knowledge" "$SANDBOX/repo con espacios/knowledge"
cp "$SOURCE/.gitattributes" "$SANDBOX/repo con espacios/.gitattributes"
cp "$SOURCE/.gitignore" "$SANDBOX/repo con espacios/.gitignore"
cp "$SOURCE/AGENTS.md" "$SANDBOX/repo con espacios/AGENTS.md"
cd "$SANDBOX/repo con espacios"
# Configuración aislada, sin credenciales ni preferencias de la máquina real.
GIT_CONFIG_GLOBAL=$SANDBOX/home/gitconfig
XDG_CONFIG_HOME=$SANDBOX/home/.config
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL XDG_CONFIG_HOME GIT_CONFIG_NOSYSTEM
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL || true
PASS=0
die() { printf '[FAIL] %s\nTASK_TEST_VERDICT=FAIL\n' "$1"; exit 1; }
ok() { PASS=$((PASS + 1)); printf '[PASS] %s\n' "$1"; }
reject() {
    DESCRIPTION=$1; shift
    if "$@" > "$SANDBOX/output" 2>&1; then die "$DESCRIPTION"; fi
    ok "$DESCRIPTION"
}
tasks() { sh .agents/scripts/tasks.sh "$@"; }
checkpoint() {
    if CHECK_OUT=$(sh .agents/scripts/git-ops.sh checkpoint "$@" 2>&1); then
        printf '%s\n' "$CHECK_OUT"
    else
        printf '%s\n' "$CHECK_OUT" >&2
        return 1
    fi
}
sh .agents/scripts/bootstrap.sh >/dev/null
tasks list | grep -q 'TASK_LIST_STATUS=OK' || die 'Lista vacía'
ok 'Lista vacía antes de crear tareas'
CREATE=$(tasks create 'Propuesta Ñandú' 'Conservar C:\notas\nuevo y $literal' 'Revisar cifras' 'Confirmar acuerdos')
ID=$(printf '%s\n' "$CREATE" | sed -n 's/^TASK_ID=//p')
FILE=workspace/documentos/tareas/$ID.md
grep -Fq 'Conservar C:\notas\nuevo y $literal' "$FILE" || die 'Texto literal'
grep -q '^Estado: pendiente$' "$FILE" || die 'Estado inicial'
ok 'Creación en Markdown con tildes y barras literales'
CREATE2=$(tasks create 'Propuesta Ñandú' 'Conservar C:\notas\nuevo y $literal' 'Revisar cifras' 'Confirmar acuerdos')
ID2=$(printf '%s\n' "$CREATE2" | sed -n 's/^TASK_ID=//p')
[ "$ID" != "$ID2" ] || die 'IDs repetidos'
ok 'Dos tareas idénticas reciben identificadores distintos'
reject 'Rechaza inyección de cabeceras por saltos de línea' tasks create "$(printf 'Título\nEstado: terminada')" objetivo criterio
reject 'Rechaza rutas en lugar de un ID' tasks show '../../LICENSE'
reject 'Rechaza estados desconocidos' tasks status "$ID" inventado
cp "$FILE" "$SANDBOX/task-before"
reject 'No termina con criterios pendientes' tasks status "$ID" terminada 'Resultado prematuro'
cmp -s "$FILE" "$SANDBOX/task-before" || die 'Un fallo alteró la tarea'
ok 'Las operaciones rechazadas conservan el archivo'
reject 'Un bloqueo requiere explicación' tasks status "$ID" bloqueada
tasks status "$ID" bloqueada 'Faltan cifras del cliente' >/dev/null
tasks list bloqueada | grep -q "$ID" || die 'Filtro por estado'
ok 'Estado bloqueada con motivo y listado filtrado'
tasks status "$ID" 'en curso' >/dev/null
reject 'La verificación requiere evidencia no vacía' tasks verify "$ID" 1 ''
reject 'Rechaza números de criterio inexistentes' tasks verify "$ID" 99 evidencia
printf '\n## Notas\nConservar esta anotación manual.\n' >> "$FILE"
tasks verify "$ID" 1 'C:\notas\nuevo: revisión realizada' >/dev/null
tasks verify "$ID" 2 'Acuerdos contrastados con el acta' >/dev/null
grep -Fq '  Evidencia: C:\notas\nuevo: revisión realizada' "$FILE" || die 'Evidencia literal'
ok 'Verificación numerada con evidencia literal'
reject 'No termina sin un resultado escrito' tasks status "$ID" terminada
tasks status "$ID" terminada 'Propuesta revisada y lista para enviar' >/dev/null
grep -q '^Estado: terminada$' "$FILE" || die 'Cierre válido'
grep -q 'Conservar esta anotación manual.' "$FILE" || die 'Notas borradas'
ok 'Cierre completo que conserva notas manuales'
reject 'No modifica criterios de una tarea terminada' tasks unverify "$ID" 1
reject 'Reabrir una tarea requiere un motivo' tasks status "$ID" pendiente
checkpoint 'Guardar cierre y nueva tarea' --task "$ID" --task "$ID2" --task "$ID" >/dev/null
CLOSED_REF=$(git rev-parse HEAD)
TRAILERS=$(git log -1 --format='%(trailers:key=Task-ID,valueonly)')
[ "$(printf '%s\n' "$TRAILERS" | grep -Fxc "$ID")" -eq 1 ] || die 'Asociación duplicada'
printf '%s\n' "$TRAILERS" | grep -Fxq "$ID2" || die 'Falta segunda asociación'
grep -q '^Estado: pendiente$' "workspace/documentos/tareas/$ID2.md" || die 'El guardado cerró otra tarea'
ok 'Un punto se asocia a varias tareas sin cerrarlas ni duplicar metadatos'
tasks checkpoint "$ID" 'Sin cambios que guardar' | grep -q 'CHECKPOINT_STATUS=NO_CHANGES' || die 'Punto vacío'
[ "$(git rev-parse HEAD)" = "$CLOSED_REF" ] || die 'El punto vacío alteró el historial'
ok 'Asociar una tarea sin cambios conserva el comportamiento de guardado vacío'
printf 'Avance de documentos\n' > workspace/documentos/avance.md
tasks checkpoint "$ID" 'Avanzar el documento sin cambiar el registro de tarea' >/dev/null
LINKED_REF=$(git rev-parse --short HEAD)
tasks history "$ID" | grep -q "PUNTO=$LINKED_REF" || die 'No encuentra asociación'
ok 'El historial encuentra avances que no modificaron el archivo de tarea'
printf 'Cambio sin asociación\n' >> workspace/documentos/avance.md
checkpoint "$(printf 'Nota de prueba\n\nTask-ID: %s\n\nEste párrafo es cuerpo, no metadatos.' "$ID")" >/dev/null
FALSE_REF=$(git rev-parse --short HEAD)
if tasks history "$ID" | grep -q "PUNTO=$FALSE_REF"; then die 'Metadato falso en cuerpo'; fi
ok 'El historial no confunde texto del mensaje con metadatos de tarea'
INDEX_BEFORE=$(git write-tree)
reject 'Asociar una tarea inexistente no prepara archivos' checkpoint prueba --task T-000000000000
[ "$(git write-tree)" = "$INDEX_BEFORE" ] || die 'Índice alterado'
ok 'El rechazo de asociación conserva la preparación de archivos'
tasks status "$ID" 'en curso' 'Solicitaron una segunda revisión' >/dev/null
tasks unverify "$ID" 1 >/dev/null
reject 'Un criterio reabierto vuelve a bloquear el cierre' tasks status "$ID" terminada 'Aún incompleto'
ok 'Reapertura explícita y retirada de verificación'
cp "$FILE" "$SANDBOX/valid-task"
sed 's/^Estado: en curso$/Estado: desconocido/' "$FILE" > "$SANDBOX/invalid-task"
cp "$SANDBOX/invalid-task" "$FILE"
git add -- "$FILE"
cp "$SANDBOX/valid-task" "$FILE"
reject 'El control detecta tarea preparada inválida aunque el archivo local esté corregido' sh .agents/hooks/pre-commit
git add -- "$FILE"
cp "$SANDBOX/invalid-task" "$FILE"
sh .agents/hooks/pre-commit || die 'El control leyó el archivo local en vez del preparado'
ok 'El control acepta tarea preparada válida aunque la copia local sea inválida'
cp "$SANDBOX/valid-task" "$FILE"
sed -e 's/^Estado: en curso$/Estado: terminada/' "$FILE" > "$SANDBOX/unfinished-task"
cp "$SANDBOX/unfinished-task" "$FILE"
git add -- "$FILE"
reject 'El control rechaza un cierre manual con criterios pendientes' sh .agents/hooks/pre-commit
cp "$SANDBOX/valid-task" "$FILE"
git add -- "$FILE"
SECOND_FILE=workspace/documentos/tareas/$ID2.md
cp "$SECOND_FILE" "$SANDBOX/second-task"
sed 's/^- \[ \] Revisar cifras$/- [x] Revisar cifras/' "$SECOND_FILE" > "$SANDBOX/no-evidence"
cp "$SANDBOX/no-evidence" "$SECOND_FILE"
git add -- "$SECOND_FILE"
reject 'El control rechaza criterios marcados sin evidencia' sh .agents/hooks/pre-commit
cp "$SANDBOX/second-task" "$SECOND_FILE"
git add -- "$SECOND_FILE"
LINK_BLOB=$(printf 'fuera-del-repositorio' | git hash-object -w --stdin)
git update-index --cacheinfo "120000,$LINK_BLOB,$FILE"
reject 'El control rechaza tareas preparadas como enlaces simbólicos' sh .agents/hooks/pre-commit
# Git para Windows con core.symlinks=false conserva el modo de enlace al hacer
# git add sobre un archivo regular; restaurar explícitamente el modo del fixture.
REGULAR_BLOB=$(git hash-object -w -- "$FILE")
git update-index --cacheinfo "100644,$REGULAR_BLOB,$FILE"
tasks verify "$ID" 1 'Segunda revisión completada' >/dev/null
checkpoint 'Guardar reapertura con revisión' --task "$ID" >/dev/null
RESTORE=$(sh .agents/scripts/git-ops.sh undo-safe "$CLOSED_REF")
RESCUE=$(printf '%s\n' "$RESTORE" | sed -n 's/^RESCUE_TAG=//p')
grep -q '^Estado: terminada$' "$FILE" || die 'Estado no restaurado'
git show "$RESCUE:$FILE" | grep -q '^Estado: en curso$' || die 'Falta respaldo de estado'
ok 'Restauración de tareas con respaldo del estado descartado'
git worktree add -b prueba-tareas "$SANDBOX/otro borrador" >/dev/null 2>&1
(
    cd "$SANDBOX/otro borrador"
    sh .agents/scripts/tasks.sh status "$ID" 'en curso' 'Trabajar una alternativa' >/dev/null
    sh .agents/scripts/tasks.sh checkpoint "$ID" 'Guardar tarea en otro borrador' >/dev/null
    sh .agents/scripts/tasks.sh history "$ID" | grep -q 'Guardar tarea en otro borrador'
) || die 'Gestor en borrador paralelo'
grep -q '^Estado: terminada$' "$FILE" || die 'El otro borrador alteró la tarea principal'
ok 'Las tareas funcionan en worktrees sin alterar otro borrador'
sh .agents/scripts/git-ops.sh merge-draft prueba-tareas >/dev/null || die 'Incorporar tareas del borrador'
grep -q '^Estado: en curso$' "$FILE" || die 'No se incorporó el estado'
ok 'Incorporar un borrador conserva tareas válidas y su estado'
rm -- "$SECOND_FILE"
checkpoint 'Retirar una tarea del listado actual' >/dev/null
REMOVED_REF=$(git rev-parse --short HEAD)
tasks history "$ID2" | grep -q "PUNTO=$REMOVED_REF" || die 'Historial de tarea eliminada'
ok 'El historial sigue disponible después de retirar el archivo de tarea'
printf 'RESUMEN DE TAREAS: PASS=%s | FAIL=0\nTASK_TEST_VERDICT=PASS\n' "$PASS"
