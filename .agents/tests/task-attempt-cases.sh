#!/bin/sh
# Regresiones del registro, dentro de la copia temporal de run-task-tests.sh.
AT_CREATE=$(tasks create 'Intentos Ñandú' 'Conservar los intentos sin cambiar el estado' 'Comprobar el informe')
AT_TASK=$(printf '%s\n' "$AT_CREATE" | sed -n 's/^TASK_ID=//p')
AT_FILE=workspace/documentos/tareas/$AT_TASK.md
reject 'Intentos: requieren una tarea guardada' tasks attempt-start "$AT_TASK" Codex revisar sh
tasks checkpoint "$AT_TASK" 'Guardar el contexto para los intentos' >/dev/null
AT_BASE=$(git rev-parse HEAD)
reject 'Intentos: rechazan saltos de línea en el agente' tasks attempt-start "$AT_TASK" "$(printf 'agente\nEstado: terminada')" revisar sh
reject 'Intentos: requieren herramienta no vacía' tasks attempt-start "$AT_TASK" Codex revisar ''
AT_START=$(tasks attempt-start "$AT_TASK" 'Agente Ñandú' 'Revisar $literal y C:\notas' 'sh $(touch no-debe-ejecutarse)')
printf '%s\n' "$AT_START" | grep -q '^ATTEMPT_ID=I-000001$' || die 'ID inicial de intento'
grep -Fq "Base: $AT_BASE" "$AT_FILE" || die 'Base móvil'
grep -Fq 'Acción: Revisar $literal y C:\notas' "$AT_FILE" || die 'Texto del intento alterado'
[ ! -e no-debe-ejecutarse ] || die 'Se ejecutó un metadato'
grep -q '^Estado: pendiente$' "$AT_FILE" || die 'El intento cambió el estado'
tasks attempts "$AT_TASK" | grep -q '^Desenlace: abierto$' || die 'Falta listado'
ok 'Intentos: registran contexto, texto literal y listado sin cambiar el estado'
cp "$AT_FILE" "$SANDBOX/attempt-open"
reject 'Intentos: solo uno abierto por tarea' tasks attempt-start "$AT_TASK" Otro revisar sh
cmp -s "$AT_FILE" "$SANDBOX/attempt-open" || die 'El rechazo alteró el intento'
ok 'Intentos: un rechazo conserva el registro anterior'
reject 'Intentos: rechazan evidencia anterior al inicio guardado' tasks attempt-finish "$AT_TASK" I-000001 exito "$ADD_PROOF" HEAD observado
reject 'Intentos: rechazan desenlaces desconocidos' tasks attempt-finish "$AT_TASK" I-000001 terminado "$ADD_PROOF" HEAD observado
reject 'Intentos: rechazan otro identificador' tasks attempt-finish "$AT_TASK" I-999999 exito "$ADD_PROOF" HEAD observado
tasks verify "$AT_TASK" 1 'Prueba de regla de cierre' >/dev/null
reject 'Intentos: un intento abierto impide terminar aunque los criterios estén verificados' tasks status "$AT_TASK" terminada 'Cierre prematuro'
tasks unverify "$AT_TASK" 1 >/dev/null
printf '\n## Notas\nConservar la nota después de los intentos.\n' >> "$AT_FILE"
tasks checkpoint "$AT_TASK" 'Guardar el inicio antes de ejecutar' >/dev/null
printf 'Informe observado: comando probado y resultado contrastado.\n' > 'workspace/entregables/informe intento (Ñandú).md'
AT_PROOF='workspace/entregables/informe intento (Ñandú).md'
checkpoint 'Guardar la evidencia sin asociación explícita' >/dev/null
AT_POINT=$(git rev-parse HEAD)
reject 'Intentos: rechazan archivos inexistentes' tasks attempt-finish "$AT_TASK" I-000001 exito workspace/entregables/ausente.md HEAD observado
tasks attempt-finish "$AT_TASK" I-000001 exito "$AT_PROOF" HEAD 'Resultado $literal y C:\datos' >/dev/null
grep -Fq 'Observación: Resultado $literal y C:\datos' "$AT_FILE" || die 'Observación alterada'
grep -q '^- \[ \]' "$AT_FILE" || die 'El intento verificó un criterio'
grep -q '^Estado: pendiente$' "$AT_FILE" || die 'El intento cerró la tarea'
grep -q 'Conservar la nota después de los intentos.' "$AT_FILE" || die 'Se perdieron las notas'
ok 'Intentos: éxito con evidencia histórica conserva notas, criterios y estado'
tasks history "$AT_TASK" | grep -q "PUNTO=$(git rev-parse --short "$AT_POINT")" || die 'Falta punto del intento en historial'
ok 'Intentos: el historial encuentra evidencia sin asociación explícita'
reject 'Intentos: no se reescribe un intento finalizado' tasks attempt-finish "$AT_TASK" I-000001 fallo "$AT_PROOF" HEAD otra
reject 'Intentos: antes del siguiente se guarda el contexto actualizado' tasks attempt-start "$AT_TASK" Codex reintentar sh
tasks checkpoint "$AT_TASK" 'Guardar el primer desenlace' >/dev/null
AT_FIRST=$(LC_ALL=C awk '/^### Intento I-000001$/ {s=1} /^## Notas$/ {s=0} s {print}' "$AT_FILE")
tasks attempt-start "$AT_TASK" Codex 'Intentar otra comprobación' 'herramienta de prueba' >/dev/null
tasks checkpoint "$AT_TASK" 'Guardar el segundo inicio' >/dev/null
tasks attempt-finish "$AT_TASK" I-000002 fallo "$AT_PROOF" HEAD 'La herramienta no pudo completar la comprobación' >/dev/null
grep -q '^Estado: pendiente$' "$AT_FILE" || die 'El fallo bloqueó automáticamente la tarea'
ok 'Intentos: un fallo se conserva sin imponer un estado de tarea'
tasks checkpoint "$AT_TASK" 'Guardar el fallo observado' >/dev/null
tasks attempt-start "$AT_TASK" 'Otro agente' 'Retomar después de interrupción' sh >/dev/null
tasks checkpoint "$AT_TASK" 'Guardar un intento que será interrumpido' >/dev/null
AT_OPEN_POINT=$(git rev-parse HEAD)
tasks attempt-finish "$AT_TASK" I-000003 interrumpido "$AT_PROOF" HEAD 'El usuario pidió detener esta ejecución' >/dev/null
[ "$(grep -c '^### Intento ' "$AT_FILE")" -eq 3 ] || die 'Se perdieron intentos'
AT_STILL_FIRST=$(LC_ALL=C awk '/^### Intento I-000001$/ {s=1} /^### Intento I-000002$/ {s=0} s {print}' "$AT_FILE")
[ "$AT_FIRST" = "$AT_STILL_FIRST" ] || die 'Se alteró el primer intento'
ok 'Intentos: interrupciones y reintentos conservan los registros anteriores'
cp "$AT_FILE" "$SANDBOX/attempt-valid"
sed 's/^Fin: .*/Fin: 2000-01-01T00:00:00Z/' "$AT_FILE" > "$SANDBOX/attempt-invalid"
cp "$SANDBOX/attempt-invalid" "$AT_FILE"
reject 'Intentos: el fin no puede preceder al inicio' tasks lint
cp "$SANDBOX/attempt-valid" "$AT_FILE"
sed 's/^Fin: .*/Fin: 2026-02-30T00:00:00Z/' "$AT_FILE" > "$SANDBOX/attempt-invalid-date"
cp "$SANDBOX/attempt-invalid-date" "$AT_FILE"
reject 'Intentos: rechazan fechas imposibles' tasks lint
cp "$SANDBOX/attempt-valid" "$AT_FILE"
sed 's/^Agente: .*/Agente: Cambiado a mano/' "$AT_FILE" > "$SANDBOX/attempt-wrong-context"
cp "$SANDBOX/attempt-wrong-context" "$AT_FILE"
reject 'Intentos: el contexto final debe coincidir con el inicio histórico' tasks lint
cp "$SANDBOX/attempt-valid" "$AT_FILE"
sed 's/^### Intento I-000002$/### Intento I-000001/' "$AT_FILE" > "$SANDBOX/attempt-duplicate"
cp "$SANDBOX/attempt-duplicate" "$AT_FILE"
reject 'Intentos: rechazan identificadores duplicados y fuera de secuencia' tasks lint
cp "$SANDBOX/attempt-valid" "$AT_FILE"
git add -- "$AT_FILE"
cp "$SANDBOX/attempt-invalid" "$AT_FILE"
sh .agents/hooks/pre-commit || die 'El control leyó el intento local en vez del preparado'
ok 'Intentos: acepta registros preparados válidos aunque la copia local esté rota'
git add -- "$AT_FILE"
cp "$SANDBOX/attempt-valid" "$AT_FILE"
reject 'Intentos: rechaza registros preparados inválidos aunque la copia local esté corregida' sh .agents/hooks/pre-commit
git add -- "$AT_FILE"
AT_PROOF_CONTENT=$(cat "$AT_PROOF")
printf 'Edición posterior no comprobada.\n' > "$AT_PROOF"
tasks lint >/dev/null || die 'Se usó la copia actual como evidencia de un intento anterior'
printf '%s\n' "$AT_PROOF_CONTENT" > "$AT_PROOF"
ok 'Intentos: las evidencias guardadas sobreviven a cambios locales del informe'
tasks agree "$AT_TASK" "$ADD_REFERENCE" "$ADD_BASE" 'Nuevo acuerdo con intentos previos' >/dev/null
[ "$(grep -c '^### Intento ' "$AT_FILE")" -eq 3 ] || die 'El acuerdo borró el historial de intentos'
ok 'Intentos: cambiar el acuerdo conserva el historial y sus bases originales'
tasks checkpoint "$AT_TASK" 'Guardar el registro con un acuerdo nuevo' >/dev/null
AT_CLOSED_POINT=$(git rev-parse HEAD)
AT_RESTORE=$(sh .agents/scripts/git-ops.sh undo-safe "$AT_OPEN_POINT")
AT_RESCUE=$(printf '%s\n' "$AT_RESTORE" | sed -n 's/^RESCUE_TAG=//p')
grep -q '^Desenlace: abierto$' "$AT_FILE" || die 'No se restauró el intento abierto'
git show "$AT_RESCUE:$AT_FILE" | grep -q '^Desenlace: interrumpido$' || die 'Se perdió el respaldo del desenlace'
tasks lint >/dev/null || die 'Restauración inválida de intentos'
ok 'Intentos: restauración con respaldo de sus desenlaces'
tasks attempt-finish "$AT_TASK" I-000003 interrumpido "$AT_PROOF" HEAD 'Retomado desde una versión anterior' >/dev/null
tasks checkpoint "$AT_TASK" 'Guardar interrupción tras restaurar' >/dev/null
git worktree add -b prueba-intentos "$SANDBOX/borrador intentos" >/dev/null 2>&1
(
    cd "$SANDBOX/borrador intentos"
    sh .agents/scripts/tasks.sh attempt-start "$AT_TASK" Codex 'Probar otra alternativa' sh >/dev/null
    sh .agents/scripts/tasks.sh checkpoint "$AT_TASK" 'Guardar intento del borrador' >/dev/null
    sh .agents/scripts/tasks.sh attempt-finish "$AT_TASK" I-000004 interrumpido "$AT_PROOF" HEAD 'Alternativa registrada' >/dev/null
    sh .agents/scripts/tasks.sh checkpoint "$AT_TASK" 'Guardar desenlace del borrador' >/dev/null
) || die 'Intentos en borrador paralelo'
[ "$(grep -c '^### Intento ' "$AT_FILE")" -eq 3 ] || die 'El borrador alteró el registro principal'
ok 'Intentos: funcionan en borradores paralelos sin alterar otro registro'
tasks verify "$AT_TASK" 1 'Informe comprobado' >/dev/null
tasks status "$AT_TASK" terminada 'Trabajo revisado' >/dev/null
reject 'Intentos: una tarea terminada requiere reapertura para otro intento' tasks attempt-start "$AT_TASK" Codex revisar sh
