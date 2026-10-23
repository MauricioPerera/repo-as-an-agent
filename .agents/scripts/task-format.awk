# Formato Markdown del gestor: validación compartida por CLI y control de guardado.
function error(message) {
    print "TASK_FORMAT_ERROR: " display ": " message
    failed = 1
}
function text(value) { return value ~ /[^[:space:]]/ && value != "-" }
function metadata_value(line) { sub(/^[^:]+: /, "", line); return line }
function point(value) { return value ~ /^[0-9a-f]+$/ && (length(value) == 40 || length(value) == 64) }
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
    else if (field == "add") print add ? "yes" : "no"
    else if (field == "agreement" && add) print agreement_path "\t" agreement_point "\t" agreement_note
    else if (field == "artifacts" && add) {
        print "agreement\t" agreement_path "\t" agreement_point
        for (i = 1; i <= criteria; i++)
            if (deliveries[i]) print i "\t" delivery_path[i] "\t" delivery_point[i]
    }
}
