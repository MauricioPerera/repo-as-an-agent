#!/bin/sh
# run-tests.sh — Suite automatizada determinista (PASS/FAIL binario) para la plantilla Repo-as-an-Agent.
# Se ejecuta en un directorio temporal completamente aislado sin tocar el workspace real.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

SANDBOX_BASE="${TMPDIR:-/tmp}/agty-test-suite-$$"
SANDBOX_HOME="$SANDBOX_BASE/fake-home"
SANDBOX_REPO="$SANDBOX_BASE/repo"

cleanup() {
    rm -rf "$SANDBOX_BASE" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$SANDBOX_HOME/.config" "$SANDBOX_REPO"

PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
    DESC="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] $DESC"
}

assert_fail() {
    DESC="$1"
    DETAIL="${2:-}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] $DESC"
    if [ -n "$DETAIL" ]; then
        echo "       Detalle: $DETAIL"
    fi
}

echo "=== INICIANDO SUITE DE VALIDACIÓN DETERMINISTA ==="

# Copia 100% POSIX (sin depender de flags no-POSIX de tar) excluyendo .git y .tmp-test
(
    cd "$SOURCE_ROOT"
    find . -type f ! -path './.git/*' ! -path './.git' ! -path './.tmp-test/*' | while IFS= read -r REL; do
        DEST_DIR="$SANDBOX_REPO/$(dirname -- "$REL")"
        mkdir -p "$DEST_DIR"
        cp "$REL" "$SANDBOX_REPO/$REL"
    done
)

# Aislar configuración global/XDG de Git para simular una computadora virgen de usuario no técnico
export HOME="$SANDBOX_HOME"
export XDG_CONFIG_HOME="$SANDBOX_HOME/.config"
export GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL || true

cd "$SANDBOX_REPO"

# ------------------------------------------------------------------
# TEST 1: Inmunidad CRLF en todos los scripts POSIX y hooks
# ------------------------------------------------------------------
CRLF_FOUND=0
for F in .agents/scripts/*.sh .agents/hooks/* .agents/tests/*.sh; do
    if awk '/\r$/ { found=1; exit } END { exit !found }' "$F"; then
        CRLF_FOUND=1
        assert_fail "Test 1: Finales de línea LF en $F" "Se detectó retorno de carro CRLF (\\r)"
    fi
done
if [ "$CRLF_FOUND" -eq 0 ]; then
    assert_pass "Test 1: Todos los scripts POSIX y hooks usan saltos de línea LF puros"
fi

# ------------------------------------------------------------------
# TEST 2: Bootstrap en computadora virgen (sin identidad Git global)
# ------------------------------------------------------------------
BOOT_OUT=$(sh .agents/scripts/bootstrap.sh 2>&1) || true
if printf '%s\n' "$BOOT_OUT" | grep -q "BOOTSTRAP_STATUS=PASS" && [ -e ".git" ]; then
    HOOKS_CFG=$(git config --get core.hooksPath || true)
    LOCAL_USER=$(git config --get user.name || true)
    if [ "$HOOKS_CFG" = ".agents/hooks" ] && [ -n "$LOCAL_USER" ]; then
        assert_pass "Test 2: bootstrap.sh inicializa Git, hooksPath e identidad local en máquina virgen"
    else
        assert_fail "Test 2: Configuración post-bootstrap incompleta" "hooksPath=$HOOKS_CFG user=$LOCAL_USER"
    fi
else
    assert_fail "Test 2: Ejecución de bootstrap.sh" "$BOOT_OUT"
fi

# ------------------------------------------------------------------
# TEST 3: boot-check.sh detecta estado inicial y onboarding=template
# ------------------------------------------------------------------
CHECK_OUT=$(sh .agents/scripts/boot-check.sh 2>&1) || true
if printf '%s\n' "$CHECK_OUT" | grep -q "BOOT_STATUS=READY" \
    && printf '%s\n' "$CHECK_OUT" | grep -q "ONBOARDING_STATUS=template"; then
    assert_pass "Test 3: boot-check.sh reporta BOOT_STATUS=READY y ONBOARDING_STATUS=template"
else
    assert_fail "Test 3: Salida inesperada en boot-check.sh" "$CHECK_OUT"
fi

# ------------------------------------------------------------------
# TEST 4: okf-lint.sh aprueba la semilla inicial (incluyendo ruta con barra final)
# ------------------------------------------------------------------
OKF_INIT_OUT=$(sh .agents/scripts/okf-lint.sh "knowledge/" 2>&1) || true
if printf '%s\n' "$OKF_INIT_OUT" | grep -q "OKF_LINT_STATUS=PASS"; then
    assert_pass "Test 4: okf-lint.sh valida correctamente la base de conocimiento semilla"
else
    assert_fail "Test 4: okf-lint.sh falló en la semilla inicial" "$OKF_INIT_OUT"
fi

# ------------------------------------------------------------------
# TEST 5: Primer punto de guardado con git-ops.sh checkpoint
# ------------------------------------------------------------------
CP1_OUT=$(sh .agents/scripts/git-ops.sh checkpoint "Punto de guardado inicial" 2>&1) || true
if printf '%s\n' "$CP1_OUT" | grep -q "CHECKPOINT_STATUS=SAVED"; then
    assert_pass "Test 5: git-ops.sh checkpoint guarda el estado base correctamente"
else
    assert_fail "Test 5: Falló el primer checkpoint" "$CP1_OUT"
fi

# ------------------------------------------------------------------
# TEST 6: pre-commit bloquea nodo OKF inválido (sin campo 'type:')
# ------------------------------------------------------------------
cat > knowledge/profile/nodo-invalido.md << 'EOF'
---
title: 'Nodo sin type'
description: 'Este nodo viola el esquema OKF.'
---

Contenido de prueba.
EOF

if BAD_CP_OUT=$(sh .agents/scripts/git-ops.sh checkpoint "Intentar guardar OKF roto" 2>&1); then
    assert_fail "Test 6: pre-commit debía bloquear un nodo OKF sin 'type:'" "$BAD_CP_OUT"
else
    if printf '%s\n' "$BAD_CP_OUT" | grep -q "no incluye el campo obligatorio OKF 'type:'"; then
        assert_pass "Test 6: Hook pre-commit bloquea determinísticamente nodos OKF sin 'type:'"
    else
        assert_fail "Test 6: Código de error recibido pero mensaje inesperado" "$BAD_CP_OUT"
    fi
fi
rm -f knowledge/profile/nodo-invalido.md

# ------------------------------------------------------------------
# TEST 7: okf-lint.sh y pre-commit bloquean enlaces relativos rotos
# ------------------------------------------------------------------
cp knowledge/index.md "$SANDBOX_BASE/index.bak"
printf '\n- [Enlace Roto](./no-existe/fantasma.md)\n' >> knowledge/index.md

if BROKEN_LINK_OUT=$(sh .agents/scripts/okf-lint.sh 2>&1); then
    assert_fail "Test 7: okf-lint.sh debía detectar enlace relativo roto" "$BROKEN_LINK_OUT"
else
    if printf '%s\n' "$BROKEN_LINK_OUT" | grep -q "tiene un enlace roto hacia"; then
        assert_pass "Test 7: okf-lint.sh detecta enlaces relativos rotos en knowledge/"
    else
        assert_fail "Test 7: Falló por motivo distinto a enlace roto" "$BROKEN_LINK_OUT"
    fi
fi
cp "$SANDBOX_BASE/index.bak" knowledge/index.md

# ------------------------------------------------------------------
# TEST 8: okf-lint.sh prohíbe 'type:' de concepto en archivos estructurales (index.md)
# ------------------------------------------------------------------
cat > knowledge/index.md << 'EOF'
---
type: 'Forbidden Concept On Index'
title: 'Indice mal usado'
description: 'No permitido por OKF.'
---
Texto.
EOF

if STRUCT_OUT=$(sh .agents/scripts/okf-lint.sh 2>&1); then
    assert_fail "Test 8: okf-lint.sh debía rechazar 'type:' dentro de index.md" "$STRUCT_OUT"
else
    if printf '%s\n' "$STRUCT_OUT" | grep -q "archivo estructural reservado en OKF"; then
        assert_pass "Test 8: okf-lint.sh protege la reserva estructural de index.md y log.md"
    else
        assert_fail "Test 8: Falló por motivo distinto a reserva estructural" "$STRUCT_OUT"
    fi
fi
cp "$SANDBOX_BASE/index.bak" knowledge/index.md

# ------------------------------------------------------------------
# TEST 9: pre-commit bloquea marcadores de conflicto, archivos movidos (R) y secretos (.env)
# ------------------------------------------------------------------
cp workspace/documentos/bienvenida.md "$SANDBOX_BASE/bienvenida.bak"
M_OPEN="<<<<<<""< HEAD"
M_MID="===""===="
M_CLOSE=">>>>>>""> borrador/experimental"
git mv workspace/documentos/bienvenida.md workspace/documentos/bienvenida-movida.md
printf '%s\n%s\n%s\n%s\n%s\n' "$M_OPEN" "Versión A" "$M_MID" "Versión B" "$M_CLOSE" >> workspace/documentos/bienvenida-movida.md

if CONFLICT_CP=$(sh .agents/scripts/git-ops.sh checkpoint "Guardar renombrado con conflicto" 2>&1); then
    assert_fail "Test 9a: pre-commit debía bloquear marcadores incluso en archivos movidos (R)" "$CONFLICT_CP"
else
    if printf '%s\n' "$CONFLICT_CP" | grep -q "bienvenida-movida.md"; then
        assert_pass "Test 9a: Detección de marcadores de conflicto incluso en archivos renombrados/movidos"
    else
        assert_fail "Test 9a: Falló por motivo distinto a marcadores en archivo movido" "$CONFLICT_CP"
    fi
fi
rm -f workspace/documentos/bienvenida-movida.md
cp "$SANDBOX_BASE/bienvenida.bak" workspace/documentos/bienvenida.md
git reset -q HEAD -- .
git checkout -q -- workspace/documentos/bienvenida.md

printf 'API_SECRET=12345\n' > .env
git add -f .env
if ENV_COMMIT=$(git commit -m "Forzar secreto" 2>&1); then
    assert_fail "Test 9b: pre-commit debía bloquear archivo .env forzado" "$ENV_COMMIT"
else
    if printf '%s\n' "$ENV_COMMIT" | grep -q "Archivo sensible detectado"; then
        assert_pass "Test 9b: Hook pre-commit bloquea subida accidental de secretos (.env)"
    else
        assert_fail "Test 9b: Falló por motivo distinto a archivo sensible" "$ENV_COMMIT"
    fi
fi
git rm -f --cached -q .env 2>/dev/null || true
rm -f .env

# ------------------------------------------------------------------
# TEST 10: Borradores con tildes/ñ (slugify UTF-8), autoguardado al cambiar y merge limpio
# ------------------------------------------------------------------
DRAFT_OUT=$(sh .agents/scripts/git-ops.sh draft-create "Versión Ñandú 2026!" 2>&1) || true
if printf '%s\n' "$DRAFT_OUT" | grep -q "CURRENT_DRAFT=borrador/version-nandu-2026"; then
    printf '\nSección formal añadida en borrador paralelo.\n' >> workspace/documentos/bienvenida.md
    SW_OUT=$(sh .agents/scripts/git-ops.sh draft-switch main 2>&1) || true
    MERGE_OUT=$(sh .agents/scripts/git-ops.sh merge-draft "Versión Ñandú 2026!" 2>&1) || true
    if printf '%s\n' "$SW_OUT" | grep -q "CURRENT_DRAFT=main" \
        && printf '%s\n' "$MERGE_OUT" | grep -q "MERGE_STATUS=CLEAN" \
        && grep -q "Sección formal añadida en borrador paralelo." workspace/documentos/bienvenida.md; then
        assert_pass "Test 10: Transliteración español (áéíóúñ) en borradores, autoguardado y merge limpio"
    else
        assert_fail "Test 10: Fallo en switch o merge de borrador" "$SW_OUT | $MERGE_OUT"
    fi
else
    assert_fail "Test 10: Fallo en transliteración de borrador con tildes/ñ" "$DRAFT_OUT"
fi

# ------------------------------------------------------------------
# TEST 11: undo-safe garantiza CERO pérdida de datos (incluso en archivos nuevos sin guardar)
# ------------------------------------------------------------------
printf 'Idea valiosa escrita sin hacer commit.\n' > workspace/bandeja/idea-rapida.md
printf '\nEdición temporal descartable.\n' >> workspace/documentos/bienvenida.md

UNDO_WT_OUT=$(sh .agents/scripts/git-ops.sh undo-safe working 2>&1) || true
RESCUE_TAG_WT=$(printf '%s\n' "$UNDO_WT_OUT" | awk -F= '/^RESCUE_TAG=/ {print $2}')

if [ ! -f workspace/bandeja/idea-rapida.md ] \
    && [ -n "$RESCUE_TAG_WT" ] \
    && git show "${RESCUE_TAG_WT}:workspace/bandeja/idea-rapida.md" 2>/dev/null | grep -q "Idea valiosa escrita sin hacer commit."; then
    assert_pass "Test 11a: undo-safe working limpia el árbol pero preserva archivos nuevos en $RESCUE_TAG_WT"
else
    assert_fail "Test 11a: undo-safe working no preservó el archivo nuevo en la etiqueta de rescate" "$UNDO_WT_OUT"
fi

UNDO_LAST_OUT=$(sh .agents/scripts/git-ops.sh undo-safe HEAD~1 2>&1) || true
if printf '%s\n' "$UNDO_LAST_OUT" | grep -q "UNDO_STATUS=RESTORED_COMMIT_CREATED" \
    && ! grep -q "Sección formal añadida en borrador paralelo." workspace/documentos/bienvenida.md; then
    assert_pass "Test 11b: undo-safe restaura versiones previas manteniendo historial lineal hacia adelante"
else
    assert_fail "Test 11b: undo-safe no restauró la versión previa esperada" "$UNDO_LAST_OUT"
fi

# ------------------------------------------------------------------
# TEST 12: Conciliación real de conflicto de fusión sin deadlock (incluso eligiendo Opción A = HEAD)
# ------------------------------------------------------------------
printf 'Precio acordado: 100 USD\n' > "workspace/documentos/Acuerdo Cliente.md"
sh .agents/scripts/git-ops.sh checkpoint "Base de acuerdo" >/dev/null
sh .agents/scripts/git-ops.sh draft-create "opcion-b" >/dev/null
printf 'Precio acordado: 150 USD\n' > "workspace/documentos/Acuerdo Cliente.md"
sh .agents/scripts/git-ops.sh checkpoint "Ajuste en borrador B" >/dev/null
sh .agents/scripts/git-ops.sh draft-switch main >/dev/null
printf 'Precio acordado: 120 USD\n' > "workspace/documentos/Acuerdo Cliente.md"
sh .agents/scripts/git-ops.sh checkpoint "Ajuste en versión principal" >/dev/null

if MERGE_CONFLICT_OUT=$(sh .agents/scripts/git-ops.sh merge-draft "opcion-b" 2>&1); then
    assert_fail "Test 12: merge-draft debía detectar conflicto real" "$MERGE_CONFLICT_OUT"
else
    # Elegir exactamente la Opción A (idéntica a HEAD = 120 USD) y cerrar con checkpoint
    printf 'Precio acordado: 120 USD\n' > "workspace/documentos/Acuerdo Cliente.md"
    CC_READY=$(sh .agents/scripts/git-ops.sh conflict-check 2>&1) || true
    RESOLVE_CP=$(sh .agents/scripts/git-ops.sh checkpoint "Conciliar acuerdo conservando 120 USD" 2>&1) || true
    CC_AFTER=$(sh .agents/scripts/git-ops.sh conflict-check 2>&1) || true

    if printf '%s\n' "$MERGE_CONFLICT_OUT" | grep -q "workspace/documentos/Acuerdo Cliente.md" \
        && printf '%s\n' "$CC_READY" | grep -q "CONFLICT_STATE=ready_to_checkpoint" \
        && printf '%s\n' "$RESOLVE_CP" | grep -q "CHECKPOINT_STATUS=SAVED" \
        && printf '%s\n' "$CC_AFTER" | grep -q "CONFLICT_STATE=false"; then
        assert_pass "Test 12: Resolución completa de conflicto de merge (con espacios en ruta y elección idéntica a HEAD)"
    else
        assert_fail "Test 12: Fallo al cerrar conciliación de conflicto" "$CC_READY | $RESOLVE_CP | $CC_AFTER"
    fi
fi

# ------------------------------------------------------------------
# TEST 13: Soporte de espacios, %20 y paréntesis en enlaces OKF hacia documentos
# ------------------------------------------------------------------
printf '# Anexo\n' > "workspace/documentos/Propuesta Final (1).md"
cat > knowledge/profile/referencia-espacios.md << 'EOF'
---
type: 'Document Reference'
title: 'Referencia con Espacios y Paréntesis'
description: 'Valida enlaces Markdown hacia archivos con espacios y paréntesis.'
---

- Enlace con brackets: [Propuesta A](<../../workspace/documentos/Propuesta Final (1).md>)
- Enlace con %20: [Propuesta B](../../workspace/documentos/Propuesta%20Final%20(1).md)
EOF

OKF_SPACES_OUT=$(sh .agents/scripts/okf-lint.sh 2>&1) || true
if printf '%s\n' "$OKF_SPACES_OUT" | grep -q "OKF_LINT_STATUS=PASS"; then
    assert_pass "Test 13: okf-lint.sh soporta archivos con espacios, %20 y paréntesis '(1)'"
else
    assert_fail "Test 13: okf-lint.sh falló con espacios o paréntesis" "$OKF_SPACES_OUT"
fi

# ------------------------------------------------------------------
# TEST 14: Auto-reparación tras git clone fresco (boot-check restaura core.hooksPath)
# ------------------------------------------------------------------
git config --unset core.hooksPath
sh .agents/scripts/boot-check.sh >/dev/null
RESTORED_HOOKS=$(git config --get core.hooksPath || true)
if [ "$RESTORED_HOOKS" = ".agents/hooks" ]; then
    assert_pass "Test 14: boot-check.sh auto-activa core.hooksPath tras un clonado fresco"
else
    assert_fail "Test 14: boot-check.sh no restauró core.hooksPath" "Actual: $RESTORED_HOOKS"
fi

echo "================================================="
echo "RESUMEN DE PRUEBAS: PASS=$PASS_COUNT | FAIL=$FAIL_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "TEST_SUITE_VERDICT=FAIL"
    exit 1
fi

echo "TEST_SUITE_VERDICT=PASS"
exit 0
