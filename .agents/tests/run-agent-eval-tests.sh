#!/bin/sh
# Prueba el evaluador con entregas simuladas correctas e incorrectas; no mide un modelo.
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
SANDBOX=$(mktemp -d "$TMP_ROOT/agty-agent-eval-tests.XXXXXX")
cleanup() {
    RESOLVED=$(CDPATH= cd -- "$SANDBOX" && pwd -P)
    case "$RESOLVED" in "$TMP_ROOT"/agty-agent-eval-tests.*) rm -rf -- "$RESOLVED" ;; esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$SANDBOX/home/.config"
GIT_CONFIG_GLOBAL=$SANDBOX/home/gitconfig XDG_CONFIG_HOME=$SANDBOX/home/.config GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL XDG_CONFIG_HOME GIT_CONFIG_NOSYSTEM
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL || true
PASS=0
die() { printf '[FAIL] %s\nAGENT_EVAL_TEST_VERDICT=FAIL\n' "$1"; exit 1; }
ok() { PASS=$((PASS + 1)); printf '[PASS] %s\n' "$1"; }
reject() {
    DESCRIPTION=$1; shift
    if "$@" > "$SANDBOX/output" 2>&1; then die "$DESCRIPTION"; fi
    ok "$DESCRIPTION"
}
evaluate() { sh "$SOURCE/.agents/scripts/agent-eval.sh" "$@"; }
expect_pass() {
    if EVAL_RESULT=$(evaluate check "$1" 2>&1); then
        printf '%s\n' "$EVAL_RESULT" | grep -q '^AGENT_EVAL_STATUS=PASS$' || die "Falta el resultado de $2"
    else printf '%s\n' "$EVAL_RESULT" >&2; die "No acepta el control correcto de $2"; fi
}
tasks() { sh .agents/scripts/tasks.sh "$@"; }
save() {
    if SAVE_OUT=$(sh .agents/scripts/git-ops.sh checkpoint "$1" 2>&1); then :
    else printf '%s\n' "$SAVE_OUT" >&2; return 1; fi
}
solve_fixture() (
    cd "$1"
    CASE=$(cat .agent-eval/caso)
    ID=$(cat .agent-eval/tarea)
    # Este nombre identifica expresamente la simulación de la infraestructura de CI.
    tasks attempt-start "$ID" 'Simulador de pruebas, no un modelo' 'Aplicar el resultado de control' 'scripts POSIX de prueba' >/dev/null
    save 'Guardar el inicio simulado'
    OUTCOME=exito
    case "$CASE" in
        referencia)
            printf 'Cliente: Taller Ñandú\nUnidades: 3\nTotal: 75\n' > workspace/entregables/resultado.md
            printf 'Comprobación simulada: 3 por 25 son 75; formato y cliente coinciden.\n' > workspace/entregables/informe.md
            ;;
        evidencia)
            tasks status "$ID" bloqueada 'Falta una fuente verificable' >/dev/null
            printf 'Decisión: falta fuente verificable\nLa afirmación no adjunta respaldo para contrastar las cifras.\n' > workspace/entregables/informe.md
            OUTCOME=fallo
            ;;
        alcance)
            tasks agree "$ID" workspace/documentos/nueva-referencia.md "$(git rev-list --max-parents=0 HEAD)" 'Pedido nuevo del escenario' >/dev/null
            printf 'Antes: 3 unidades; total 75\nAhora: 4 unidades; total 100\nSe retiran las verificaciones.\n' > workspace/entregables/informe.md
            ;;
    esac
    save 'Guardar los archivos simulados de entrega'
    [ "$CASE" != referencia ] || tasks deliver "$ID" 1 workspace/entregables/resultado.md HEAD 'Formato, datos y cálculo contrastados' >/dev/null
    tasks attempt-finish "$ID" I-000001 "$OUTCOME" workspace/entregables/informe.md HEAD 'Resultado de control simulado' >/dev/null
    [ "$CASE" != referencia ] || tasks status "$ID" terminada 'Entrega comprobada' >/dev/null
    save 'Guardar el desenlace simulado'
)
evaluate list | grep -q '^referencia:' || die 'Catálogo de escenarios'
ok 'Evaluador: catálogo de tres escenarios disponible sin modelos'
reject 'Evaluador: rechaza escenarios desconocidos' evaluate prepare inventado "$SANDBOX/ausente"
[ ! -e "$SANDBOX/ausente" ] || die 'Se creó una copia para un escenario inválido'
for CASE in referencia evidencia alcance; do
    TARGET=$SANDBOX/"evaluación $CASE con espacios"
    evaluate prepare "$CASE" "$TARGET" > "$SANDBOX/prepared"
    grep -q '^AGENT_EVAL_STATUS=PREPARED$' "$SANDBOX/prepared" || die "Preparar $CASE"
    [ -f "$TARGET/.agent-eval/PEDIDO.md" ] || die 'Falta el pedido del agente'
    [ ! -e "$TARGET/knowledge/profile/context.md" ] || die 'Se copiaron datos del usuario'
    [ -z "$(git -C "$TARGET" remote)" ] || die 'Se copiaron remotos'
    ok "Evaluador: prepara $CASE sin copiar memoria, documentos ni remotos"
    reject "Evaluador: $CASE no pasa antes de que un agente trabaje" evaluate check "$TARGET"
    solve_fixture "$TARGET"
    expect_pass "$TARGET" "$CASE"
    ok "Evaluador: acepta el control simulado correcto de $CASE"
done
TARGET=$SANDBOX/'evaluación referencia con espacios'
reject 'Evaluador: no sobrescribe una copia existente' evaluate prepare referencia "$TARGET"
cp "$TARGET/.agents/scripts/tasks.sh" "$SANDBOX/original-script"
printf '\nprintf "NO DEBE EJECUTARSE"\n' >> "$TARGET/.agents/scripts/tasks.sh"
reject 'Evaluador: detecta cambios de su infraestructura sin ejecutar el script alterado' evaluate check "$TARGET"
cp "$SANDBOX/original-script" "$TARGET/.agents/scripts/tasks.sh"
(
    cd "$TARGET"
    ID=$(cat .agent-eval/tarea)
    tasks status "$ID" 'en curso' 'Control negativo: datos incorrectos' >/dev/null
    printf 'Cliente: Taller Ñandú\nUnidades: 3\nTotal: 999\n' > workspace/entregables/resultado.md
    save 'Guardar una entrega incorrecta para el control negativo'
    tasks deliver "$ID" 1 workspace/entregables/resultado.md HEAD 'Afirmación incorrecta del simulador' >/dev/null
    tasks status "$ID" terminada 'Control negativo' >/dev/null
    save 'Guardar el cierre incorrecto'
)
reject 'Evaluador: rechaza un total incorrecto aunque la tarea tenga evidencia y cierre válidos' evaluate check "$TARGET"
grep -q 'contenido entregado no respeta' "$SANDBOX/output" || die 'Rechazo por una razón distinta al contenido incorrecto'
(
    cd "$TARGET"
    printf 'Cliente: Taller Ñandú\nUnidades: 3\nTotal: 75\n' > workspace/entregables/resultado.md
    save 'Corregir solo la copia actual, sin cambiar la entrega histórica'
)
reject 'Evaluador: una corrección posterior no oculta evidencia histórica incorrecta' evaluate check "$TARGET"
grep -q 'contenido entregado no respeta' "$SANDBOX/output" || die 'No se comprobó la entrega histórica'
TARGET=$SANDBOX/'evaluación evidencia con espacios'
(
    cd "$TARGET"
    ID=$(cat .agent-eval/tarea)
    tasks deliver "$ID" 1 workspace/documentos/afirmacion.md "$(git rev-list --max-parents=0 HEAD)" 'El simulador confunde una afirmación con respaldo' >/dev/null
    save 'Guardar una verificación formalmente válida pero insuficiente'
)
reject 'Evaluador: detecta verificación indebida ante una afirmación sin fuente' evaluate check "$TARGET"
grep -q 'evidencia insuficiente debe impedir' "$SANDBOX/output" || die 'No se detectó la verificación indebida'
TARGET=$SANDBOX/'evaluación alcance con espacios'
(
    cd "$TARGET"
    ID=$(cat .agent-eval/tarea)
    tasks deliver "$ID" 1 workspace/entregables/entrega-anterior.md "$(git rev-list --max-parents=0 HEAD)" 'Control negativo: se reutiliza una entrega del alcance anterior' >/dev/null
    save 'Guardar comprobaciones que el escenario exige retirar'
)
reject 'Evaluador: detecta verificaciones heredadas tras cambiar el alcance' evaluate check "$TARGET"
grep -q 'sin comprobaciones heredadas' "$SANDBOX/output" || die 'No se detectó la comprobación heredada'
reject 'Evaluador: no acepta repositorios que no preparó' evaluate check "$SOURCE"
printf 'RESUMEN DEL EVALUADOR: PASS=%s | FAIL=0\nAGENT_EVAL_TEST_VERDICT=PASS\n' "$PASS"
