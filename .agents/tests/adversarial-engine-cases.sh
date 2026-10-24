#!/bin/sh
# Casos deterministas de fase 2. Solo recibe carpetas creadas por el runner.
set -eu
CASE_ID=$1 SEED=$2 CASE_WORK=$3 PROOF=$4 ENGINE_SOURCE=$5
mkdir -p "$CASE_WORK" "$PROOF"
REAL_GIT=$(command -v git) REAL_MV=$(command -v mv) REAL_AWK=$(command -v awk)
export REAL_GIT REAL_MV REAL_AWK
die() { printf 'ASSERTION_FAILED=%s\n' "$1"; exit 1; }
expect_rc() {
    EXPECTED=$1; shift
    printf 'COMMAND' >> "$PROOF/comandos.txt"
    for ARG do printf '\t%s' "$ARG" >> "$PROOF/comandos.txt"; done
    printf '\n' >> "$PROOF/comandos.txt"
    if "$@" > "$PROOF/ultima-salida.txt" 2>&1; then ACTUAL=0; else ACTUAL=$?; fi
    printf 'EXPECTED_EXIT=%s\nEXIT=%s\n' "$EXPECTED" "$ACTUAL" >> "$PROOF/comandos.txt"
    cat "$PROOF/ultima-salida.txt" >> "$PROOF/comandos.txt"
    [ "$ACTUAL" -eq "$EXPECTED" ] || die "salida $ACTUAL; esperada $EXPECTED"
}
contains() { grep -Fq -- "$1" "$PROOF/ultima-salida.txt" || die "diagnóstico esperado: $1"; }
fixture() {
    REPO=$CASE_WORK/$1
    printf '\nVARIANT=%s\n' "$1" >> "$PROOF/comandos.txt"
    cp -R "$SEED" "$REPO"
    cd "$REPO"
}
tasks() { sh .agents/scripts/tasks.sh "$@"; }
save() { sh .agents/scripts/git-ops.sh checkpoint "$@"; }
gate() { sh .agents/hooks/pre-commit; }
new_task() {
    expect_rc 0 tasks create 'Revisar cifras' 'Preparar informe ficticio' 'Contrastar el total'
    ID=$(sed -n 's/^TASK_ID=//p' "$PROOF/ultima-salida.txt")
    FILE=workspace/documentos/tareas/$ID.md
    [ -n "$ID" ] || die 'falta ID real'
}
remember() {
    cp "$FILE" "$PROOF/tarea-antes.md"
    git rev-parse HEAD > "$PROOF/punto-antes.txt"
}
unchanged() { cmp -s "$FILE" "$PROOF/tarea-antes.md" || die 'se alteró la tarea rechazada'; }
prepare_evidence() {
    EVALUATED=$CASE_WORK/$1
    expect_rc 0 env GIT_DEFAULT_HASH="${2:-sha1}" sh "$SEED/.agents/scripts/agent-eval.sh" prepare evidencia "$EVALUATED"
    EVAL_BASE=$(sed -n 's/^BASE_CHECKPOINT=//p' "$PROOF/ultima-salida.txt")
    [ -n "$EVAL_BASE" ] || die 'falta el punto inicial para fijar el contrato'
    cd "$EVALUATED"
    ID=$(cat .agent-eval/tarea)
    expect_rc 0 tasks attempt-start "$ID" 'Simulador determinista' 'Contrastar la fuente' 'sh de pruebas'
    expect_rc 0 save 'Guardar inicio simulado'
    expect_rc 0 tasks status "$ID" bloqueada 'Falta una fuente verificable'
    printf 'Decisión: falta fuente verificable\n' > workspace/entregables/informe.md
    expect_rc 0 save 'Guardar informe simulado'
    expect_rc 0 tasks attempt-finish "$ID" I-000001 fallo workspace/entregables/informe.md HEAD 'Falta fuente verificable'
    expect_rc 0 save 'Guardar desenlace simulado'
}

case "$CASE_ID" in
REC-06)
    fixture valido
    new_task
    expect_rc 0 tasks verify "$ID" 1 'Total contrastado'
    expect_rc 0 save 'Control válido de guardado'
    contains CHECKPOINT_STATUS=SAVED
    fixture ataque
    new_task
    printf 'Documento nuevo que debe conservarse\n' > workspace/documentos/nuevo.md
    remember
    mkdir "$CASE_WORK/bin"
    cat > "$CASE_WORK/bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = commit ]; then printf 'Fallo inducido antes de guardar\n' >&2; exit 77; fi
exec "$REAL_GIT" "$@"
EOF
    cat > "$CASE_WORK/bin/mv" <<'EOF'
#!/bin/sh
printf 'Fallo de escritura inducido\n' >&2
exit 77
EOF
    chmod +x "$CASE_WORK/bin/"*
    expect_rc 1 env PATH="$CASE_WORK/bin:$PATH" sh .agents/scripts/git-ops.sh checkpoint 'Guardado con fallo'
    contains CHECKPOINT_STATUS=BLOCKED
    [ "$(git rev-parse HEAD)" = "$(cat "$PROOF/punto-antes.txt")" ] || die 'avanzó el historial tras fallar'
    grep -Fxq 'Documento nuevo que debe conservarse' workspace/documentos/nuevo.md || die 'perdió el documento nuevo'
    unchanged
    expect_rc 77 env PATH="$CASE_WORK/bin:$PATH" sh .agents/scripts/tasks.sh verify "$ID" 1 'No llegó a publicarse'
    unchanged
    [ ! -e .git/task-manager.lock ] || die 'dejó un bloqueo propio'
    expect_rc 0 tasks verify "$ID" 1 'Recuperación después del fallo'
    cp "$FILE" "$PROOF/tarea-despues.md"
    ;;
ENT-01)
    fixture valido
    new_task
    expect_rc 0 tasks verify "$ID" 1 'Datos normales'
    fixture ataque
    TEXT='Ñandú "doble" '\''simple'\'' C:\notas\nuevo $(touch NO-EJECUTAR) `touch NO-EJECUTAR` ; --help'
    expect_rc 0 tasks create "$TEXT" "$TEXT" "$TEXT"
    ID=$(sed -n 's/^TASK_ID=//p' "$PROOF/ultima-salida.txt")
    FILE=workspace/documentos/tareas/$ID.md
    expect_rc 0 tasks verify "$ID" 1 "$TEXT"
    expect_rc 0 tasks status "$ID" bloqueada "$TEXT"
    expect_rc 0 save "$TEXT"
    [ ! -e NO-EJECUTAR ] || die 'ejecutó datos como código'
    grep -Fxq "# $TEXT" "$FILE" || die 'reinterpretó el título'
    grep -Fxq "  Evidencia: $TEXT" "$FILE" || die 'reinterpretó la evidencia'
    [ "$(git log -1 --format=%s)" = "$TEXT" ] || die 'reinterpretó la nota del guardado'
    cp "$FILE" "$PROOF/literales.md"
    ;;
ENT-03)
    fixture valido
    printf 'Clave pública ficticia\n' > workspace/entregables/ejemplo.pub
    git add -- workspace/entregables/ejemplo.pub
    expect_rc 0 gate
    for NAME in .env.ficticio privado.key renombrado.pem; do
        fixture "ataque-$NAME"
        printf 'Credencial FICTICIA, sin valor real\n' > workspace/entregables/inocuo.txt
        git add -- workspace/entregables/inocuo.txt
        expect_rc 0 save 'Guardar documento inocuo antes del cambio de nombre'
        mv workspace/entregables/inocuo.txt "workspace/entregables/$NAME"
        git add -Af -- workspace/entregables
        # Corregir únicamente el disco no cambia el contenido preparado.
        rm "workspace/entregables/$NAME"
        printf 'Documento local corregido\n' > workspace/entregables/inocuo.txt
        expect_rc 1 gate
        contains 'Archivo sensible detectado'
        git show ":workspace/entregables/$NAME" > "$PROOF/credencial-ficticia.txt"
        grep -Fq FICTICIA "$PROOF/credencial-ficticia.txt" || die 'el control no inspeccionó el contenido preparado'
    done
    ;;
ENT-06)
    fixture valido
    printf 'Total ficticio: 75\n' > workspace/entregables/cifras.md
    git add -- workspace/entregables/cifras.md
    expect_rc 0 gate
    fixture ataque
    printf 'Total ficticio: 75\n' > workspace/entregables/cifras.md
    git add -- workspace/entregables/cifras.md
    mkdir "$CASE_WORK/bin"
    cat > "$CASE_WORK/bin/git" <<'EOF'
#!/bin/sh
case "$READ_FAILURE:$1:$2" in
    size:cat-file:-s|blob:show::workspace/entregables/cifras.md) exit 77 ;;
esac
exec "$REAL_GIT" "$@"
EOF
    chmod +x "$CASE_WORK/bin/git"
    for READ_FAILURE in size blob; do
        expect_rc 1 env READ_FAILURE="$READ_FAILURE" PATH="$CASE_WORK/bin:$PATH" sh .agents/hooks/pre-commit
        contains 'PRE_COMMIT_FAIL: No se pudo leer'
        contains COMMIT_BLOCKED=true
    done
    expect_rc 0 gate
    ;;
TAR-06)
    fixture valido
    new_task
    expect_rc 0 tasks verify "$ID" 1 'Control válido'
    fixture ataque
    new_task
    remember
    mkdir .git/task-manager.lock
    printf 'Pertenece a otra ejecución\n' > .git/task-manager.lock/propietario
    expect_rc 1 tasks verify "$ID" 1 'No debe sobrescribir otra operación'
    contains 'Existe otra operación'
    unchanged
    grep -Fxq 'Pertenece a otra ejecución' .git/task-manager.lock/propietario || die 'retiró el bloqueo ajeno'
    rm .git/task-manager.lock/propietario
    rmdir .git/task-manager.lock
    mkdir "$CASE_WORK/bin"
    cat > "$CASE_WORK/bin/awk" <<'EOF'
#!/bin/sh
"$REAL_AWK" "$@" || exit $?
for ARG do LAST=$ARG; done
case "$LAST" in
    */.task-*)
        if [ ! -e "$RACE_MARKER" ]; then
            : > "$RACE_MARKER"
            printf '\n## Nota concurrente\nCambio externo que debe conservarse.\n' >> "$RACE_TASK"
        fi ;;
esac
EOF
    chmod +x "$CASE_WORK/bin/awk"
    expect_rc 1 env PATH="$CASE_WORK/bin:$PATH" RACE_TASK="$REPO/$FILE" RACE_MARKER="$CASE_WORK/disparado" sh .agents/scripts/tasks.sh verify "$ID" 1 'Edición que llegó tarde'
    contains 'La tarea cambió mientras se editaba'
    [ -f "$CASE_WORK/disparado" ] || die 'no se ejercitó la contención'
    cat "$PROOF/tarea-antes.md" > "$PROOF/tarea-esperada.md"
    printf '\n## Nota concurrente\nCambio externo que debe conservarse.\n' >> "$PROOF/tarea-esperada.md"
    cmp -s "$FILE" "$PROOF/tarea-esperada.md" || die 'perdió la edición concurrente'
    [ ! -e .git/task-manager.lock ] || die 'no liberó su bloqueo'
    expect_rc 0 tasks verify "$ID" 1 'Reintento explícito tras inspeccionar el cambio'
    ;;
EVA-02)
    fixture valido
    prepare_evidence evaluacion
    cp .git/index "$PROOF/indice-antes.bin"
    expect_rc 0 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$EVALUATED" "$EVAL_BASE"
    contains AGENT_EVAL_STATUS=PASS
    cmp -s .git/index "$PROOF/indice-antes.bin" || die 'el evaluador modificó el índice observado'
    for ATTACK in script fsmonitor filter hook include alternates hardlink; do
        TARGET=$CASE_WORK/ataque-$ATTACK
        cp -R "$EVALUATED" "$TARGET"
        cd "$TARGET"
        PROBE=$CASE_WORK/NO-EJECUTAR-$ATTACK
        printf '#!/bin/sh\nprintf ejecutado > "%s"\ncat\n' "$PROBE" > "$CASE_WORK/probe-$ATTACK.sh"
        chmod +x "$CASE_WORK/probe-$ATTACK.sh"
        case "$ATTACK" in
            script) cp "$CASE_WORK/probe-$ATTACK.sh" .agents/scripts/tasks.sh ;;
            fsmonitor) git config core.fsmonitor "$CASE_WORK/probe-$ATTACK.sh" ;;
            filter)
                git config filter.trampa.clean "$CASE_WORK/probe-$ATTACK.sh"
                printf '\n*.md filter=trampa\n' >> .gitattributes
                printf '\nCambio sin guardar\n' >> workspace/entregables/informe.md ;;
            hook)
                git config core.hooksPath "$CASE_WORK/hooks"
                mkdir "$CASE_WORK/hooks"
                cp "$CASE_WORK/probe-$ATTACK.sh" "$CASE_WORK/hooks/post-index-change" ;;
            alternates)
                mkdir -p .git/objects/info
                printf '%s\n' "$CASE_WORK/fuera-del-repositorio" > .git/objects/info/alternates ;;
            hardlink)
                printf 'CANARIO-FICTICIO-EXTERNO\n' > "$CASE_WORK/indice-externo"
                mv .git/index .git/index-anterior
                ln "$CASE_WORK/indice-externo" .git/index ;;
            include)
                git config include.path "$CASE_WORK/config-externa"
                printf '[extensions]\nobjectFormat = no-admitido\n' > "$CASE_WORK/config-externa" ;;
        esac
        case "$ATTACK" in fsmonitor|hook|include) CODE=0 ;; *) CODE=1 ;; esac
        expect_rc "$CODE" sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$TARGET" "$EVAL_BASE"
        [ "$ATTACK" != alternates ] || contains 'No se admiten objetos externos'
        [ "$ATTACK" != hardlink ] || contains 'Los metadatos Git no pueden atravesar enlaces'
        [ ! -e "$PROBE" ] || die "ejecutó configuración o código de la copia: $ATTACK"
        [ "$CODE" -ne 0 ] || contains AGENT_EVAL_STATUS=PASS
    done
    ;;
EVA-04)
    fixture valido
    prepare_evidence original
    ORIGINAL=$EVALUATED ORIGINAL_BASE=$EVAL_BASE
    expect_rc 0 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$ORIGINAL" "$ORIGINAL_BASE"
    contains CONTRACT_ANCHOR=pinned
    prepare_evidence sustituto
    [ "$EVAL_BASE" != "$ORIGINAL_BASE" ] || die 'los contratos de sustitución no son distintos'
    # Un caso válido por sí solo no es la copia fijada por el observador.
    expect_rc 0 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$EVALUATED"
    contains CONTRACT_ANCHOR=not_pinned
    expect_rc 1 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$EVALUATED" "$ORIGINAL_BASE"
    contains 'El contrato no corresponde al punto base conservado'
    cd "$ORIGINAL"
    TREE=$(git rev-parse "$ORIGINAL_BASE^{tree}")
    REPLACEMENT=$(printf 'Historia sustituida ficticia\n' | git commit-tree "$TREE")
    git replace "$ORIGINAL_BASE" "$REPLACEMENT"
    expect_rc 0 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$ORIGINAL" "$ORIGINAL_BASE"
    contains CONTRACT_ANCHOR=pinned
    printf 'alcance\n' > .agent-eval/caso
    expect_rc 1 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$ORIGINAL" "$ORIGINAL_BASE"
    contains 'Se alteraron las instrucciones'
    expect_rc 1 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$ORIGINAL" --help
    contains 'El punto base conservado debe ser una huella completa'
    printf '%s\n' "$ORIGINAL_BASE" > "$PROOF/punto-fijado.txt"
    # Mantener los dos formatos de puntos que ya acepta el gestor.
    if git init --bare --object-format=sha256 "$CASE_WORK/capacidad-sha256" > "$PROOF/capacidad-sha256.txt" 2>&1; then
        prepare_evidence sha256 sha256
        [ "${#EVAL_BASE}" -eq 64 ] || die 'no se ejercitó un punto SHA-256'
        expect_rc 0 sh "$ENGINE_SOURCE/.agents/scripts/agent-eval.sh" check "$EVALUATED" "$EVAL_BASE"
        contains CONTRACT_ANCHOR=pinned
    else
        printf 'SUBVARIANT_SKIP=SHA256_NOT_SUPPORTED\n'
    fi
    ;;
*) printf 'UNKNOWN_CASE\n'; exit 2 ;;
esac
printf 'CASE_ASSERTIONS=PASS\n'
