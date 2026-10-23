#!/bin/sh
# Casos ADD del gestor, ejecutados por run-task-tests.sh en su copia temporal.
ADD_CREATE=$(tasks create 'Piloto de entrega Ñandú' 'Contrastar la entrega con lo acordado' 'Cifras revisadas' 'Acuerdos contrastados')
ADD_ID=$(printf '%s\n' "$ADD_CREATE" | sed -n 's/^TASK_ID=//p')
ADD_FILE=workspace/documentos/tareas/$ADD_ID.md
reject 'ADD: entregar requiere un acuerdo previo' tasks deliver "$ADD_ID" 1 workspace/documentos/avance.md HEAD observación
tasks verify "$ADD_ID" 1 'Revisión anterior al acuerdo' >/dev/null
printf '\n## Notas\nConservar notas libres del usuario.\n' >> "$ADD_FILE"
ADD_OLD=$(git rev-parse HEAD)
mkdir -p 'workspace/documentos/referencias' 'workspace/entregables/pruebas'
ADD_REFERENCE='workspace/documentos/referencias/propuesta (Ñandú).md'
ADD_PROOF='workspace/entregables/pruebas/informe de cifras.md'
ADD_SECOND='workspace/entregables/pruebas/informe de acuerdos.md'
printf 'Esquema y muestra acordados con el pedido.\n' > "$ADD_REFERENCE"
reject 'ADD: un archivo todavía sin guardar no sirve como referencia' tasks agree "$ADD_ID" "$ADD_REFERENCE" HEAD 'Pedido del usuario'
printf '' > workspace/documentos/referencias/vacío.md
printf 'contenido de un enlace\n' > workspace/documentos/referencias/enlace.md
ADD_LINK=$(git hash-object -w -- workspace/documentos/referencias/enlace.md)
ADD_SYMLINKS=$(git config --get core.symlinks || printf true)
git config core.symlinks false
git update-index --add --cacheinfo "120000,$ADD_LINK,workspace/documentos/referencias/enlace.md"
checkpoint 'Guardar la referencia de ejemplo' >/dev/null
git config core.symlinks "$ADD_SYMLINKS"
ADD_BASE=$(git rev-parse HEAD)
reject 'ADD: rechaza referencias vacías' tasks agree "$ADD_ID" workspace/documentos/referencias/vacío.md "$ADD_BASE" acuerdo
reject 'ADD: rechaza carpetas como artefactos' tasks agree "$ADD_ID" workspace/documentos/referencias "$ADD_BASE" acuerdo
reject 'ADD: rechaza enlaces simbólicos guardados como artefactos' tasks agree "$ADD_ID" workspace/documentos/referencias/enlace.md "$ADD_BASE" acuerdo
reject 'ADD: rechaza rutas fuera de workspace' tasks agree "$ADD_ID" AGENTS.md "$ADD_BASE" acuerdo
reject 'ADD: rechaza rutas con recorrido a otra carpeta' tasks agree "$ADD_ID" workspace/documentos/../documentos/avance.md "$ADD_BASE" acuerdo
reject 'ADD: rechaza rutas absolutas de Windows' tasks agree "$ADD_ID" 'C:\notas\referencia.md' "$ADD_BASE" acuerdo
reject 'ADD: rechaza la propia tarea como artefacto' tasks agree "$ADD_ID" "$ADD_FILE" "$ADD_BASE" acuerdo
reject 'ADD: rechaza opciones como referencia de punto' tasks agree "$ADD_ID" "$ADD_REFERENCE" --help acuerdo
reject 'ADD: rechaza puntos inexistentes' tasks agree "$ADD_ID" "$ADD_REFERENCE" 0000000000000000000000000000000000000000 acuerdo
ADD_TREE=$(git rev-parse 'HEAD^{tree}')
ADD_UNRELATED=$(printf 'Punto de otra historia\n' | git commit-tree "$ADD_TREE")
reject 'ADD: rechaza puntos ajenos al historial actual' tasks agree "$ADD_ID" "$ADD_REFERENCE" "$ADD_UNRELATED" acuerdo
tasks agree "$ADD_ID" "$ADD_REFERENCE" HEAD 'Pedido: conservar $literal y C:\notas\nuevo' >/dev/null
grep -q '^Estado: pendiente$' "$ADD_FILE" || die 'ADD modificó el estado'
grep -Fq "Punto: $ADD_BASE" "$ADD_FILE" || die 'ADD guardó un punto móvil'
grep -Fq 'Acuerdo: Pedido: conservar $literal y C:\notas\nuevo' "$ADD_FILE" || die 'ADD alteró el acuerdo literal'
if grep -q '^- \[x\]' "$ADD_FILE"; then die 'ADD no retiró las verificaciones antiguas'; fi
ok 'ADD: acuerda una referencia inmutable y reinicia criterios conservando estado y texto literal'
reject 'ADD: verificar solo con texto no sustituye una entrega' tasks verify "$ADD_ID" 1 'Ya funciona'
tasks status "$ADD_ID" bloqueada 'Esperar la revisión del cliente' >/dev/null
tasks status "$ADD_ID" 'en curso' >/dev/null
tasks checkpoint "$ADD_ID" 'Guardar el acuerdo antes de ejecutar' >/dev/null
ADD_AGREED=$(git rev-parse HEAD)
reject 'ADD: una entrega anterior al punto de referencia se rechaza' tasks deliver "$ADD_ID" 1 workspace/documentos/avance.md "$ADD_OLD" 'Informe anterior'
printf 'Cifras contrastadas: total 125, diferencia 0.\n' > "$ADD_PROOF"
printf 'Acuerdos contrastados contra el acta del cliente.\n' > "$ADD_SECOND"
checkpoint 'Guardar informes de entrega sin asociación explícita' >/dev/null
ADD_DELIVERED=$(git rev-parse HEAD)
reject 'ADD: exige un número de criterio válido' tasks deliver "$ADD_ID" 01 "$ADD_PROOF" HEAD observación
reject 'ADD: rechaza criterios inexistentes' tasks deliver "$ADD_ID" 3 "$ADD_PROOF" HEAD observación
cp "$ADD_FILE" "$SANDBOX/add-before"
reject 'ADD: rechaza evidencias inexistentes en el punto' tasks deliver "$ADD_ID" 1 workspace/entregables/ausente.md HEAD observación
cmp -s "$ADD_FILE" "$SANDBOX/add-before" || die 'ADD alteró la tarea tras un rechazo'
ok 'ADD: una operación rechazada no modifica la tarea'
tasks deliver "$ADD_ID" 1 "$ADD_PROOF" HEAD 'Total 125 contrastado; diferencia 0' >/dev/null
tasks history "$ADD_ID" | grep -q "PUNTO=$(git rev-parse --short "$ADD_DELIVERED")" || die 'ADD no encuentra el punto de prueba'
ok 'ADD: el historial incluye puntos de artefactos sin Task-ID ni cambios en la tarea'
reject 'ADD: un criterio sin entrega impide cerrar' tasks status "$ADD_ID" terminada 'Entrega incompleta'
tasks deliver "$ADD_ID" 2 "$ADD_SECOND" "$ADD_DELIVERED" 'Acta contrastada con los acuerdos' >/dev/null
tasks deliver "$ADD_ID" 1 "$ADD_PROOF" "$ADD_DELIVERED" 'Revisión final: $literal y C:\datos' >/dev/null
[ "$(grep -c '^### Criterio 1$' "$ADD_FILE")" -eq 1 ] || die 'ADD duplicó una entrega'
grep -Fq 'Observación: Revisión final: $literal y C:\datos' "$ADD_FILE" || die 'ADD alteró la observación'
ok 'ADD: sustituir una entrega conserva un solo registro y la observación literal'
cp "$ADD_FILE" "$SANDBOX/add-valid-open"
tasks agree "$ADD_ID" "$ADD_REFERENCE" "$ADD_BASE" 'Pedido: conservar $literal y C:\notas\nuevo' | grep -q 'TASK_STATUS=NO_CHANGES' || die 'ADD perdió la idempotencia'
cmp -s "$ADD_FILE" "$SANDBOX/add-valid-open" || die 'ADD reinició un acuerdo idéntico'
ok 'ADD: repetir el mismo acuerdo conserva las evidencias'
reject 'ADD: exige resultado escrito al cerrar' tasks status "$ADD_ID" terminada
tasks status "$ADD_ID" terminada 'Entrega contrastada con la referencia acordada' >/dev/null
ok 'ADD: cierra con referencia, evidencia por criterio y resultado, usando los cuatro estados'
reject 'ADD: cambiar el acuerdo requiere reabrir una tarea terminada' tasks agree "$ADD_ID" "$ADD_REFERENCE" "$ADD_BASE" 'Nuevo pedido'
reject 'ADD: cambiar una entrega requiere reabrir una tarea terminada' tasks deliver "$ADD_ID" 1 "$ADD_PROOF" HEAD 'Otro resultado'
cp "$ADD_FILE" "$SANDBOX/add-valid-closed"
# Los artefactos se leen del punto histórico, no del archivo que haya hoy en disco.
mv "$ADD_PROOF" "$SANDBOX/add-proof"
printf 'Una edición local aún no acordada.\n' > "$ADD_REFERENCE"
tasks lint >/dev/null || die 'ADD confundió la copia actual con el punto acordado'
git show "$ADD_DELIVERED:$ADD_PROOF" | grep -q 'diferencia 0' || die 'ADD no conserva la evidencia histórica'
mv "$SANDBOX/add-proof" "$ADD_PROOF"
git show "$ADD_BASE:$ADD_REFERENCE" > "$ADD_REFERENCE"
ok 'ADD: conserva referencias y pruebas históricas aunque cambie la copia de trabajo'
sed "s/^Punto: .*/Punto: 0000000000000000000000000000000000000000/" "$SANDBOX/add-valid-closed" > "$SANDBOX/add-invalid-point"
cp "$SANDBOX/add-invalid-point" "$ADD_FILE"
git add -- "$ADD_FILE"
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
reject 'ADD: el control rechaza puntos preparados inválidos aunque el archivo local sea válido' sh .agents/hooks/pre-commit
git add -- "$ADD_FILE"
cp "$SANDBOX/add-invalid-point" "$ADD_FILE"
sh .agents/hooks/pre-commit || die 'ADD leyó la copia local en vez de la preparada'
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
ok 'ADD: el control valida los artefactos de la versión preparada'
sed "s|^Archivo: $ADD_PROOF$|Archivo: workspace/entregables/ausente.md|" "$SANDBOX/add-valid-closed" > "$ADD_FILE"
reject 'ADD: la edición manual no puede introducir un archivo inexistente' tasks lint
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
awk '/^## Evidencias de entrega$/ {print; exit} {print}' "$ADD_FILE" > "$SANDBOX/add-no-proofs"
cp "$SANDBOX/add-no-proofs" "$ADD_FILE"
reject 'ADD: el cierre manual no puede omitir las evidencias estructuradas' tasks lint
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
sed 's/^  Evidencia: .*/  Evidencia: Otra observación/' "$SANDBOX/add-valid-closed" > "$ADD_FILE"
reject 'ADD: rechaza observaciones distintas de la evidencia del criterio' tasks lint
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
printf '\n### Criterio 1\nArchivo: %s\nPunto: %s\nObservación: Duplicado\n' "$ADD_PROOF" "$ADD_DELIVERED" >> "$ADD_FILE"
reject 'ADD: rechaza evidencias duplicadas para un criterio' tasks lint
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
printf '\n## Referencia acordada\n' >> "$ADD_FILE"
reject 'ADD: rechaza referencias duplicadas' tasks lint
cp "$SANDBOX/add-valid-closed" "$ADD_FILE"
tasks status "$ADD_ID" 'en curso' 'Solicitaron otra revisión' >/dev/null
tasks unverify "$ADD_ID" 1 >/dev/null
if grep -q '^### Criterio 1$' "$ADD_FILE"; then die 'ADD conservó la entrega retirada'; fi
grep -q '^### Criterio 2$' "$ADD_FILE" || die 'ADD retiró otras entregas'
ok 'ADD: retirar una verificación elimina solo su entrega'
reject 'ADD: retirar una evidencia vuelve a impedir el cierre' tasks status "$ADD_ID" terminada resultado
tasks deliver "$ADD_ID" 1 "$ADD_PROOF" "$ADD_DELIVERED" 'Nueva comprobación realizada' >/dev/null
tasks status "$ADD_ID" terminada 'Segunda revisión completada' >/dev/null
tasks checkpoint "$ADD_ID" 'Guardar el piloto terminado' >/dev/null
ADD_CLOSED=$(git rev-parse HEAD)
tasks status "$ADD_ID" 'en curso' 'Cambió el alcance' >/dev/null
tasks agree "$ADD_ID" "$ADD_REFERENCE" "$ADD_AGREED" 'El usuario pidió otro alcance' >/dev/null
if grep -Eq '^- \[x\]|^### Criterio ' "$ADD_FILE"; then die 'ADD conservó pruebas del acuerdo anterior'; fi
grep -q 'Conservar notas libres del usuario.' "$ADD_FILE" || die 'ADD perdió notas del usuario'
ok 'ADD: cambiar el acuerdo retira las verificaciones y entregas, conservando notas'
tasks checkpoint "$ADD_ID" 'Guardar un nuevo acuerdo pendiente' >/dev/null
ADD_RESTORE=$(sh .agents/scripts/git-ops.sh undo-safe "$ADD_CLOSED")
ADD_RESCUE=$(printf '%s\n' "$ADD_RESTORE" | sed -n 's/^RESCUE_TAG=//p')
grep -q '^Estado: terminada$' "$ADD_FILE" || die 'ADD no restauró el cierre'
git show "$ADD_RESCUE:$ADD_FILE" | grep -q 'El usuario pidió otro alcance' || die 'ADD no respaldó el acuerdo descartado'
tasks lint >/dev/null || die 'ADD inválido después de restaurar'
ok 'ADD: restauración con respaldo de acuerdos y entregas'
git worktree add -b prueba-add "$SANDBOX/borrador ADD" >/dev/null 2>&1
(
    cd "$SANDBOX/borrador ADD"
    sh .agents/scripts/tasks.sh status "$ADD_ID" 'en curso' 'Probar otra entrega' >/dev/null
    sh .agents/scripts/tasks.sh unverify "$ADD_ID" 1 >/dev/null
    sh .agents/scripts/tasks.sh deliver "$ADD_ID" 1 "$ADD_PROOF" "$ADD_DELIVERED" 'Comprobado en otro borrador' >/dev/null
    sh .agents/scripts/tasks.sh checkpoint "$ADD_ID" 'Guardar entrega alternativa ADD' >/dev/null
) || die 'ADD falló en un worktree'
grep -q '^Estado: terminada$' "$ADD_FILE" || die 'ADD alteró el borrador principal'
ok 'ADD: los acuerdos y las entregas funcionan en borradores paralelos'
