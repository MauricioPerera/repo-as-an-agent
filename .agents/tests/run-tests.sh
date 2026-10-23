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
for F in .agents/scripts/*.sh .agents/scripts/*.awk .agents/hooks/* .agents/tests/*.sh; do
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

# ------------------------------------------------------------------
# TEST 15: No sobrescribir archivos ignorados ni incorporarlos al rescate
# ------------------------------------------------------------------
sh .agents/scripts/git-ops.sh checkpoint "Base para regresiones de seguridad" >/dev/null
printf 'Versión anterior del respaldo.\n' > "workspace/documentos/Respaldo Local.bak"
git add -f "workspace/documentos/Respaldo Local.bak"
sh .agents/scripts/git-ops.sh checkpoint "Guardar respaldo de prueba" >/dev/null
BACKUP_REF=$(git rev-parse HEAD)
git rm -q -- "workspace/documentos/Respaldo Local.bak"
sh .agents/scripts/git-ops.sh checkpoint "Retirar respaldo de prueba" >/dev/null
printf 'Contenido local valioso e ignorado.\n' > "workspace/documentos/Respaldo Local.bak"
printf 'Cambio pendiente que debe conservarse.\n' > workspace/bandeja/pendiente.md
git add workspace/bandeja/pendiente.md
BEFORE_HEAD=$(git rev-parse HEAD)
BEFORE_TREE=$(git write-tree)
BEFORE_TAGS=$(git tag -l 'rescate/*')
if IGNORED_OUT=$(sh .agents/scripts/git-ops.sh undo-safe "$BACKUP_REF" 2>&1); then
    assert_fail "Test 15a: Debía bloquearse la colisión con un archivo ignorado" "$IGNORED_OUT"
elif printf '%s\n' "$IGNORED_OUT" | grep -q 'UNDO_STATUS=BLOCKED_IGNORED_FILES' \
    && grep -q 'Contenido local valioso e ignorado.' "workspace/documentos/Respaldo Local.bak" \
    && [ "$(git rev-parse HEAD)" = "$BEFORE_HEAD" ] \
    && [ "$(git write-tree)" = "$BEFORE_TREE" ] \
    && [ "$(git tag -l 'rescate/*')" = "$BEFORE_TAGS" ]; then
    assert_pass "Test 15a: Restauración bloqueada sin alterar archivo ignorado, historial, índice ni rescates"
else
    assert_fail "Test 15a: La restauración alteró el estado o falló por otra causa" "$IGNORED_OUT"
fi
rm -f "workspace/documentos/Respaldo Local.bak"

# Un ignorado sin colisión debe permanecer local y no terminar en el rescate.
printf 'Secreto local que no debe guardarse.\n' > workspace/documentos/.env
if SAFE_UNDO=$(sh .agents/scripts/git-ops.sh undo-safe working 2>&1); then
    SAFE_TAG=$(printf '%s\n' "$SAFE_UNDO" | awk -F= '/^RESCUE_TAG=/ {print $2}')
    if [ -n "$SAFE_TAG" ] && [ -f workspace/documentos/.env ] \
        && ! git cat-file -e "$SAFE_TAG:workspace/documentos/.env" 2>/dev/null \
        && git show "$SAFE_TAG:workspace/bandeja/pendiente.md" | grep -q 'Cambio pendiente'; then
        assert_pass "Test 15b: Ignorados sin colisión se conservan y no se guardan secretos en el rescate"
    else
        assert_fail "Test 15b: Respaldo o conservación incorrecta de ignorados" "$SAFE_UNDO"
    fi
else
    assert_fail "Test 15b: Ignorados ajenos no deben bloquear la restauración" "$SAFE_UNDO"
fi
rm -f workspace/documentos/.env

# Una carpeta local ignorada también puede colisionar con un archivo antiguo.
mkdir -p "workspace/documentos/Respaldo Local.bak"
printf 'Contenido de carpeta que debe conservarse.\n' > "workspace/documentos/Respaldo Local.bak/local.md"
if DIR_UNDO=$(sh .agents/scripts/git-ops.sh undo-safe "$BACKUP_REF" 2>&1); then
    assert_fail "Test 15c: Debía bloquearse la colisión archivo/carpeta ignorada" "$DIR_UNDO"
elif printf '%s\n' "$DIR_UNDO" | grep -q 'UNDO_STATUS=BLOCKED_IGNORED_FILES' \
    && grep -q 'Contenido de carpeta' "workspace/documentos/Respaldo Local.bak/local.md"; then
    assert_pass "Test 15c: Colisiones entre archivos y carpetas ignoradas se bloquean sin pérdida de datos"
else
    assert_fail "Test 15c: No se conservó la carpeta ignorada" "$DIR_UNDO"
fi
rm -f "workspace/documentos/Respaldo Local.bak/local.md"
rmdir "workspace/documentos/Respaldo Local.bak"

mkdir -p workspace/documentos/carpeta.tmp
printf 'Documento anterior en una carpeta.\n' > workspace/documentos/carpeta.tmp/anterior.md
git add -f workspace/documentos/carpeta.tmp/anterior.md
sh .agents/scripts/git-ops.sh checkpoint "Guardar carpeta de prueba" >/dev/null
DIRECTORY_REF=$(git rev-parse HEAD)
git rm -r -q -- workspace/documentos/carpeta.tmp
sh .agents/scripts/git-ops.sh checkpoint "Retirar carpeta de prueba" >/dev/null
printf 'Archivo local que no puede reemplazarse por una carpeta.\n' > workspace/documentos/carpeta.tmp
if FILE_UNDO=$(sh .agents/scripts/git-ops.sh undo-safe "$DIRECTORY_REF" 2>&1); then
    assert_fail "Test 15d: Debía bloquearse la sustitución de un ignorado por una carpeta" "$FILE_UNDO"
elif printf '%s\n' "$FILE_UNDO" | grep -q 'UNDO_STATUS=BLOCKED_IGNORED_FILES' \
    && grep -q 'Archivo local que no puede reemplazarse' workspace/documentos/carpeta.tmp; then
    assert_pass "Test 15d: Un archivo ignorado no puede reemplazarse por una carpeta antigua"
else
    assert_fail "Test 15d: No se conservó el archivo ignorado" "$FILE_UNDO"
fi
rm -f workspace/documentos/carpeta.tmp

# ------------------------------------------------------------------
# TEST 16: Validar exactamente la memoria y los enlaces que se guardarán
# ------------------------------------------------------------------
cat > knowledge/profile/memoria-preparada.md << 'EOF'
---
title: 'Nodo sin type preparado'
description: 'La versión preparada es inválida.'
---
Contenido.
EOF
git add knowledge/profile/memoria-preparada.md
cp knowledge/profile/context.md knowledge/profile/memoria-preparada.md
BEFORE_HEAD=$(git rev-parse HEAD)
if STAGED_BAD=$(git commit -m "Intentar ocultar memoria inválida con una corrección en disco" 2>&1); then
    assert_fail "Test 16a: No debe guardarse memoria inválida corregida solo en disco" "$STAGED_BAD"
elif printf '%s\n' "$STAGED_BAD" | grep -q "no incluye el campo obligatorio OKF 'type:'" \
    && [ "$(git rev-parse HEAD)" = "$BEFORE_HEAD" ]; then
    assert_pass "Test 16a: Una corrección solo en disco no oculta memoria inválida preparada"
else
    assert_fail "Test 16a: Fallo por causa distinta a la memoria preparada" "$STAGED_BAD"
fi

# Caso inverso: los cambios sin preparar no deben bloquear una versión válida.
git add knowledge/profile/memoria-preparada.md
printf 'Cambios locales sin encabezado y sin preparar.\n' > knowledge/profile/memoria-preparada.md
if STAGED_GOOD=$(git commit -m "Guardar solo la memoria válida preparada" 2>&1) \
    && git show HEAD:knowledge/profile/memoria-preparada.md | grep -q '^type:' \
    && grep -q 'Cambios locales sin encabezado' knowledge/profile/memoria-preparada.md; then
    assert_pass "Test 16b: Memoria preparada válida se guarda aunque haya cambios locales inválidos"
else
    assert_fail "Test 16b: Se validó el disco en lugar del contenido preparado" "$STAGED_GOOD"
fi
# Restaurar únicamente este fixture a su contenido guardado antes de retirarlo.
git show HEAD:knowledge/profile/memoria-preparada.md > knowledge/profile/memoria-preparada.md
git rm -q knowledge/profile/memoria-preparada.md

printf '# Destino solo en disco\n' > "workspace/documentos/Destino preparado (1).md"
cat > knowledge/profile/enlace-preparado.md << 'EOF'
---
type: 'Document Reference'
title: 'Enlaces preparados'
description: 'Ambos enlaces deben resolverse contra el contenido preparado.'
---
[Relativo](<../../workspace/documentos/Destino preparado (1).md>)
[Desde raíz](</workspace/documentos/Destino preparado%20(1).md>)
EOF
git add knowledge/profile/enlace-preparado.md
if LINK_BAD=$(git commit -m "Intentar guardar enlace a un archivo solo local" 2>&1); then
    assert_fail "Test 16c: Un destino solo en disco no debe validar un enlace preparado" "$LINK_BAD"
elif printf '%s\n' "$LINK_BAD" | grep -q 'tiene un enlace roto hacia'; then
    assert_pass "Test 16c: Los enlaces preparados rechazan destinos que solo existen en disco"
else
    assert_fail "Test 16c: Fallo por motivo distinto a destino ausente" "$LINK_BAD"
fi
git add "workspace/documentos/Destino preparado (1).md"
rm "workspace/documentos/Destino preparado (1).md"
if LINK_GOOD=$(git commit -m "Guardar enlaces con su destino preparado" 2>&1); then
    assert_pass "Test 16d: Enlaces relativos y desde raíz aceptan destinos preparados aunque no estén en disco"
else
    assert_fail "Test 16d: Los enlaces se comprobaron contra el disco" "$LINK_GOOD"
fi
git show "HEAD:workspace/documentos/Destino preparado (1).md" > "workspace/documentos/Destino preparado (1).md"
git rm -q knowledge/profile/enlace-preparado.md "workspace/documentos/Destino preparado (1).md"
sh .agents/scripts/git-ops.sh checkpoint "Retirar fixtures de memoria preparada" >/dev/null

git rm -q knowledge/index.md
git show HEAD:knowledge/index.md > knowledge/index.md
BEFORE_HEAD=$(git rev-parse HEAD)
if DELETED_INDEX=$(git commit -m "Intentar eliminar el índice aunque exista en disco" 2>&1); then
    assert_fail "Test 16e: La eliminación preparada del índice debía bloquearse" "$DELETED_INDEX"
elif printf '%s\n' "$DELETED_INDEX" | grep -q 'Falta archivo estructural obligatorio: knowledge/index.md' \
    && [ "$(git rev-parse HEAD)" = "$BEFORE_HEAD" ]; then
    assert_pass "Test 16e: Detecta archivos estructurales eliminados aunque sigan presentes en disco"
else
    assert_fail "Test 16e: No se validó la eliminación preparada del índice" "$DELETED_INDEX"
fi
git add knowledge/index.md

# ------------------------------------------------------------------
# TEST 17: Perfil YAML explícito y sintácticamente válido
# ------------------------------------------------------------------
check_invalid_yaml() {
    YAML_CASE="$1"
    EXPECTED_ERROR="${2:-YAML inválido}"
    cat > knowledge/profile/yaml-regression.md
    if YAML_OUT=$(sh .agents/scripts/okf-lint.sh 2>&1); then
        assert_fail "Test 17: Debía rechazarse $YAML_CASE" "$YAML_OUT"
    elif printf '%s\n' "$YAML_OUT" | grep -q "$EXPECTED_ERROR"; then
        assert_pass "Test 17: Rechaza $YAML_CASE"
    else
        assert_fail "Test 17: Diagnóstico incorrecto para $YAML_CASE" "$YAML_OUT"
    fi
    rm -f knowledge/profile/yaml-regression.md
}

check_invalid_yaml 'comillas simples sin cerrar' << 'EOF'
---
type: 'Decision Record'
title: 'Sin cerrar
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'comillas dobles sin cerrar' << 'EOF'
---
type: 'Decision Record'
title: "Sin cerrar
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'listas sin cerrar' << 'EOF'
---
type: 'Decision Record'
title: 'Título válido'
description: 'Descripción válida'
tags: ['sin-cierre'
---
Contenido.
EOF
check_invalid_yaml 'indicadores de mapa dentro de una lista de escalares' << 'EOF'
---
type: 'Decision Record'
title: 'Título válido'
description: 'Descripción válida'
tags: [:valor]
---
Contenido.
EOF
printf '%s\n' '---' "type: 'Decision Record'" "title: 'Título válido'" "description: 'Descripción válida'" > "$SANDBOX_BASE/yaml-control.md"
printf 'opcional: "control\001inválido"\n---\nContenido.\n' >> "$SANDBOX_BASE/yaml-control.md"
check_invalid_yaml 'caracteres de control en YAML' < "$SANDBOX_BASE/yaml-control.md"
check_invalid_yaml 'escape inválido en comillas dobles' << 'EOF'
---
type: 'Decision Record'
title: "Escape \q inválido"
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'dos puntos sin comillas dentro de un escalar' << 'EOF'
---
type: 'Decision Record'
title: Título: sin comillas
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'claves duplicadas' << 'EOF'
---
type: 'Decision Record'
type: 'Glossary'
title: 'Título válido'
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'campos obligatorios nulos' "no incluye el campo obligatorio OKF 'type:'" << 'EOF'
---
type: null
title: 'Título válido'
description: 'Descripción válida'
---
Contenido.
EOF
check_invalid_yaml 'estructuras anidadas fuera del perfil' << 'EOF'
---
type: 'Decision Record'
title: 'Título válido'
description: 'Descripción válida'
metadata:
  autor: 'Anidado'
---
Contenido.
EOF

cat > knowledge/profile/yaml-regression.md << 'EOF'
---
type: Decision Record # Comentario de escalar plano
title: 'Un título con ''comillas'' y dos puntos: aquí'
description: "Texto con \"comillas\", barra \\ y Unicode \u00f1" # Comentario
tags: ['con, coma', "con ] corchete", simple,] # Lista válida
timestamp: '2026-10-22T22:45:00-06:00'
opcional: # Valor nulo permitido en campos opcionales
---
Contenido.
EOF
if YAML_GOOD=$(sh .agents/scripts/okf-lint.sh 2>&1); then
    assert_pass "Test 17: Acepta comillas escapadas, listas, comentarios y campos opcionales válidos"
else
    assert_fail "Test 17: Rechazó un encabezado válido del perfil YAML" "$YAML_GOOD"
fi

# Comprobar que la sintaxis también se exige al guardar y en archivos estructurales.
awk 'NR == 2 { print "tags: [sin cerrar" } { print }' knowledge/profile/yaml-regression.md > "$SANDBOX_BASE/yaml-bad.md"
cp "$SANDBOX_BASE/yaml-bad.md" knowledge/profile/yaml-regression.md
if YAML_COMMIT=$(sh .agents/scripts/git-ops.sh checkpoint "Intentar guardar YAML mal formado" 2>&1); then
    assert_fail "Test 17: El guardado debía bloquear YAML mal formado" "$YAML_COMMIT"
elif printf '%s\n' "$YAML_COMMIT" | grep -q 'YAML inválido'; then
    assert_pass "Test 17: El control de guardado bloquea YAML mal formado"
else
    assert_fail "Test 17: Guardado bloqueado por otro motivo" "$YAML_COMMIT"
fi
rm -f knowledge/profile/yaml-regression.md
cp knowledge/index.md "$SANDBOX_BASE/index-before-yaml.md"
printf '%s\n' '---' 'title: "Sin cerrar' '---' '# Índice' > knowledge/index.md
if STRUCT_YAML=$(sh .agents/scripts/okf-lint.sh 2>&1); then
    assert_fail "Test 17: El encabezado estructural mal formado debía rechazarse" "$STRUCT_YAML"
elif printf '%s\n' "$STRUCT_YAML" | grep -q 'YAML inválido'; then
    assert_pass "Test 17: También valida la sintaxis YAML de archivos estructurales"
else
    assert_fail "Test 17: Diagnóstico incorrecto en el encabezado estructural" "$STRUCT_YAML"
fi
cp "$SANDBOX_BASE/index-before-yaml.md" knowledge/index.md

echo "================================================="
echo "RESUMEN DE PRUEBAS: PASS=$PASS_COUNT | FAIL=$FAIL_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "TEST_SUITE_VERDICT=FAIL"
    exit 1
fi

echo "TEST_SUITE_VERDICT=PASS"
exit 0
