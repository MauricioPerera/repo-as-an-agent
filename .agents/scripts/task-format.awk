# Formato Markdown del gestor: validación compartida por CLI y control de guardado.
function error(message) {
    print "TASK_FORMAT_ERROR: " display ": " message
    failed = 1
}
function text(value) { return value ~ /[^[:space:]]/ && value != "-" }
function metadata_value(line) { sub(/^[^:]+: /, "", line); return line }
function point(value) { return value ~ /^[0-9a-f]+$/ && (length(value) == 40 || length(value) == 64) }
function timestamp(value, year, month, day, days) {
    if (value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) return 0
    year=substr(value, 1, 4)+0; month=substr(value, 6, 2)+0; day=substr(value, 9, 2)+0
    days=31
    if (month == 4 || month == 6 || month == 9 || month == 11) days=30
    if (month == 2) days=28+(year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))
    return month >= 1 && month <= 12 && day >= 1 && day <= days &&
        substr(value, 12, 2)+0 <= 23 && substr(value, 15, 2)+0 <= 59 && substr(value, 18, 2)+0 <= 59
}
function attempt_context(n) {
    return av[n, "Base"] "\t" av[n, "Agente"] "\t" av[n, "Acción"] "\t" av[n, "Herramienta"] "\t" av[n, "Inicio"]
}
BEGIN { section = "header" }
{
    sub(/\r$/, "")
    if ($0 ~ /[\001-\010\013\014\016-\037\177]/) error("carácter de control no admitido")
    if (NR == 1) {
        if ($0 !~ /^# .+/) error("falta el título Markdown")
        title = substr($0, 3)
        next
    }
    if ($0 ~ /^## /) {
        section = $0
        headings[section]++
        next
    }
    if (section == "header") {
        if ($0 ~ /^ID: /) { id = substr($0, 5); id_count++ }
        else if ($0 ~ /^Estado: /) { state = substr($0, 9); state_count++ }
        else if (text($0)) error("cabecera inesperada")
        next
    }
    if (section == "## Objetivo" && text($0)) objective++
    if (section == "## Resultado" && text($0)) result++
    if (section == "## Motivo del estado" && text($0)) reason++
    if (section == "## Intentos de ejecución" && text($0)) {
        if ($0 ~ /\t/) error("los campos de intento no admiten tabuladores")
        if ($0 ~ /^### Intento I-[0-9]+$/ && length($3) == 8) {
            attempts++
            attempt_ids[attempts] = $3
            if (substr($3, 3) + 0 != attempts) error("los intentos deben numerarse consecutivamente desde I-000001")
        } else if (attempts && $0 ~ /^(Agente|Acción|Herramienta|Inicio|Base|Fin|Desenlace|Archivo|Punto|Observación): /) {
            key = $0; sub(/: .*/, "", key)
            av[attempts, key] = metadata_value($0); ac[attempts, key]++
        } else error("intento de ejecución con formato inválido")
    }
    if (section == "## Referencia acordada" && text($0)) {
        if ($0 ~ /^Archivo: /) { agreement_path = metadata_value($0); agreement_paths++ }
        else if ($0 ~ /^Punto: /) { agreement_point = metadata_value($0); agreement_points++ }
        else if ($0 ~ /^Acuerdo: /) { agreement_note = metadata_value($0); agreement_notes++ }
        else error("referencia acordada con formato inválido")
    }
    if (section == "## Evidencias de entrega" && text($0)) {
        if ($0 ~ /^### Criterio [1-9][0-9]*$/) {
            delivery = substr($0, 14) + 0
            deliveries[delivery]++
        } else if (delivery && $0 ~ /^Archivo: /) { delivery_path[delivery] = metadata_value($0); delivery_paths[delivery]++ }
        else if (delivery && $0 ~ /^Punto: /) { delivery_point[delivery] = metadata_value($0); delivery_points[delivery]++ }
        else if (delivery && $0 ~ /^Observación: /) { delivery_note[delivery] = metadata_value($0); delivery_notes[delivery]++ }
        else error("evidencia de entrega con formato inválido")
    }
    if (section == "## Criterios de aceptación") {
        if ($0 ~ /^- \[[ x]\] / && text(substr($0, 7))) {
            criteria++
            checked[criteria] = (substr($0, 4, 1) == "x")
        } else if ($0 ~ /^  Evidencia: / && criteria > 0 && text(substr($0, 14))) {
            evidence[criteria]++
            evidence_text[criteria] = metadata_value($0)
            if (!checked[criteria]) error("un criterio pendiente no puede tener evidencia verificada")
        } else if (text($0)) error("criterio o evidencia con formato inválido")
    }
}
END {
    if (!text(title)) error("el título está vacío")
    if (id_count != 1 || id != expected_id) error("el ID debe coincidir con el nombre del archivo")
    if (state_count != 1 || (state != "pendiente" && state != "en curso" && state != "bloqueada" && state != "terminada")) error("estado desconocido o repetido")
    if (headings["## Objetivo"] != 1 || !objective) error("falta un objetivo no vacío")
    if (headings["## Criterios de aceptación"] != 1 || !criteria) error("se requiere al menos un criterio")
    if (headings["## Resultado"] != 1 || headings["## Motivo del estado"] != 1) error("faltan secciones de resultado o motivo, o están repetidas")
    for (i = 1; i <= criteria; i++) {
        if (evidence[i] > 1 || (checked[i] && evidence[i] != 1)) error("cada criterio verificado requiere una evidencia")
        if (state == "terminada" && !checked[i]) error("hay criterios pendientes: no se puede terminar")
    }
    if (state == "terminada" && !result) error("una tarea terminada requiere resultado")
    if (state == "bloqueada" && !reason) error("una tarea bloqueada requiere motivo")
    if (headings["## Intentos de ejecución"] > 1) error("la sección de intentos debe ser única")
    keys_count = split("Agente|Acción|Herramienta|Inicio|Base|Fin|Desenlace|Archivo|Punto|Observación", keys, "[|]")
    for (n = 1; n <= attempts; n++) {
        for (k = 1; k <= keys_count; k++)
            if (ac[n, keys[k]] != 1) error("campo de intento ausente o repetido: " keys[k])
        if (!text(av[n, "Agente"]) || !text(av[n, "Acción"]) || !text(av[n, "Herramienta"]) ||
            !timestamp(av[n, "Inicio"]) || !point(av[n, "Base"])) error("inicio de intento incompleto")
        outcome = av[n, "Desenlace"]
        if (outcome == "abierto") {
            open_attempts++
            if (n != attempts || av[n, "Fin"] != "-" || av[n, "Archivo"] != "-" ||
                av[n, "Punto"] != "-" || av[n, "Observación"] != "-") error("intento abierto con datos de cierre")
        } else {
            if (outcome != "exito" && outcome != "fallo" && outcome != "interrumpido") error("desenlace de intento desconocido")
            if (!timestamp(av[n, "Fin"]) || av[n, "Fin"] < av[n, "Inicio"] || !text(av[n, "Archivo"]) ||
                !point(av[n, "Punto"]) || !text(av[n, "Observación"])) error("cierre de intento incompleto")
        }
    }
    if (open_attempts > 1 || (state == "terminada" && open_attempts)) error("hay un intento abierto: no se puede terminar")
    add = headings["## Referencia acordada"] || headings["## Evidencias de entrega"]
    if (add) {
        if (headings["## Referencia acordada"] != 1 || headings["## Evidencias de entrega"] != 1)
            error("el piloto ADD requiere una referencia y una sección de entregas únicas")
        if (agreement_paths != 1 || !text(agreement_path) || agreement_points != 1 || !point(agreement_point) ||
            agreement_notes != 1 || !text(agreement_note)) error("referencia acordada incompleta o punto inválido")
        for (i in deliveries) {
            if (i > criteria || !checked[i] || deliveries[i] != 1 || delivery_paths[i] != 1 || !text(delivery_path[i]) ||
                delivery_points[i] != 1 || !point(delivery_point[i]) || delivery_notes[i] != 1 || !text(delivery_note[i]))
                error("entrega incompleta, duplicada o sin criterio verificado")
        }
        for (i = 1; i <= criteria; i++) {
            if (checked[i] && !deliveries[i]) error("cada criterio verificado del piloto ADD requiere una entrega")
            if (deliveries[i] && evidence_text[i] != delivery_note[i]) error("la observación de entrega debe coincidir con la evidencia del criterio")
        }
    }
    if (failed) exit 1
    if (field == "state") print state
    else if (field == "title") print title
    else if (field == "criteria") print criteria
    else if (field == "verified") { total=0; for (i=1; i<=criteria; i++) if (checked[i]) total++; print total }
    else if (field == "add") print add ? "yes" : "no"
    else if (field == "agreement" && add) print agreement_path "\t" agreement_point "\t" agreement_note
    else if (field == "attempt-count") print attempts + 0
    else if (field == "attempt-open-id") { if (open_attempts) print attempt_ids[attempts] }
    else if (field == "attempt-context" || field == "attempt-open-context") {
        for (n = 1; n <= attempts; n++)
            if (attempt_ids[n] == attempt_id && (field == "attempt-context" || av[n, "Desenlace"] == "abierto")) print attempt_context(n)
    }
    else if (field == "attempts") {
        for (n = 1; n <= attempts; n++)
            print attempt_ids[n] "\t" av[n, "Base"] "\t" av[n, "Desenlace"] "\t" av[n, "Archivo"] "\t" av[n, "Punto"]
    }
    else if (field == "artifacts") {
        if (add) {
        print "agreement\t" agreement_path "\t" agreement_point
        for (i = 1; i <= criteria; i++)
            if (deliveries[i]) print i "\t" delivery_path[i] "\t" delivery_point[i]
        }
        for (n = 1; n <= attempts; n++) {
            print "attempt-base\t" expected_id "\t" av[n, "Base"]
            if (av[n, "Desenlace"] != "abierto") print "attempt-proof\t" av[n, "Archivo"] "\t" av[n, "Punto"]
        }
    }
}
