# Segunda fase adversarial: motor y datos

Esta entrega prioriza variantes deterministas de **siete escenarios** del
[catálogo](testing-adversarial.md): seis P0 y uno P1. Prueba fallos de escritura,
contención, argumentos literales, credenciales preparadas, errores de lectura y
configuración ejecutable en una copia evaluada. No llama modelos ni añade paquetes.
Reutiliza las regresiones existentes de memoria, tareas, ADD e intentos.

## Ejecutar y conservar evidencia

Desde la copia confiable del proyecto, con Git y las utilidades de Git Bash,
macOS o Linux:

```sh
sh .agents/tests/run-adversarial-engine-tests.sh list
sh .agents/tests/run-adversarial-engine-tests.sh run
```

Cada ejecución crea una carpeta nueva bajo `.tmp-test/`. También puedes indicar
una carpeta nueva cuyo padre exista:

```sh
sh .agents/tests/run-adversarial-engine-tests.sh run .tmp-test/mi-ensayo-fase2
sh .agents/tests/run-adversarial-engine-tests.sh verify .tmp-test/mi-ensayo-fase2 HUELLA_CONSERVADA
```

Sustituye `HUELLA_CONSERVADA` por el `EVIDENCE_SEAL` que devuelve la ejecución y
consérvalo aparte. `verify` acredita **integridad de los archivos**, mediante
`ENGINE_EVIDENCE_STATUS`; no convierte un ensayo FAIL en una campaña aprobada.

Los códigos son **0 PASS**, **1 FAIL** y **2 ERROR**. Un caso con una aserción
incumplida es FAIL; una herramienta ausente, un código inesperado del propio
ensayo o una interrupción son ERROR. Una lectura fallida nunca vale como defensa.
El resumen declara siete escenarios previstos y sus denominadores PASS/FAIL/ERROR/
SKIP. Estas variantes no necesitan enlaces simbólicos. La comprobación opcional
de SHA-256 se registra como `SUBVARIANT_SKIP` si el Git instalado no lo admite;
esa omisión no acredita la capacidad. Tampoco acredita junctions u otras variantes.

El runner crea semillas ficticias con el motor de confianza. No copia el
`workspace/`, `knowledge/`, identidad global ni credenciales de la persona.
Los sustitutos de Git, `mv` y `awk` existen solo en el directorio del ensayo;
no reemplazan herramientas del equipo. El motor y los casos se copian antes de
ejecutarse. Sus bytes quedan identificados en `motor.tsv`, junto al punto base.

## Variantes nuevas y controles válidos

| ID | Prioridad | Control válido | Variantes adversariales comprobadas |
| --- | --- | --- | --- |
| REC-06 | P0 | Verificar una tarea y guardar correctamente. | Fallar antes de completar el guardado y antes de publicar la escritura de una tarea. Conserva documento nuevo, tarea e historial; no anuncia guardado y permite reintentar. |
| ENT-01 | P0 | Crear y verificar con texto normal. | Comillas, acentos, barras, sustituciones de shell, acentos graves y texto parecido a opciones en título, objetivo, criterio, evidencia, motivo y nota de guardado. Los conserva literalmente y no crea el centinela. |
| ENT-03 | P0 | Permitir una clave pública ficticia `.pub`. | Renombrar a `.env.ficticio`, `.key` y `.pem`, prepararlos y corregir solo el disco. El control rechaza la versión preparada por su nombre sensible. |
| ENT-06 | P1 | Leer correctamente un archivo preparado. | Fallar la lectura de su tamaño o contenido. El control bloquea con la causa de lectura correspondiente en vez de aceptar un valor vacío. |
| TAR-06 | P0 | Verificar una tarea sin contención. | Un bloqueo ajeno se conserva. Una modificación manual inducida entre lectura y comprobación final no se sobrescribe; el cambio queda completo y permite un reintento explícito. |
| EVA-02 | P0 | Aceptar un escenario `evidencia` con un intento simulado finalizado y fuente insuficiente reconocida. | Detectar código alterado sin ejecutarlo; ignorar `fsmonitor`, filtros, hooks e inclusiones externas de la configuración evaluada; rechazar `alternates` externos y un índice con enlace duro. El centinela no aparece y el índice original permanece intacto. |
| EVA-04 | P0 | Aceptar el contrato inicial fijado por el observador. | Rechazar una copia válida con otro historial frente al punto original; ignorar referencias de reemplazo; rechazar metadatos de escenario alterados y argumentos que parecen opciones. Conserva el soporte de puntos SHA-1 y SHA-256 cuando Git lo admite. |

Cada caso conserva comandos, códigos esperados y observados, diagnósticos y
archivos seleccionados para contrastar el resultado. No se afirma que esas
capturas parciales observen todas las acciones del sistema.

## Regresiones reutilizadas y cobertura pendiente

La fase combina los casos nuevos con las suites existentes de CI, sin volver a
contarlas como escenarios recién implementados:

| Familia / IDs relacionados | Regresión que se reutiliza | Cobertura que sigue pendiente |
| --- | --- | --- |
| REC-02, REC-03 | [Pruebas generales](../.agents/tests/run-tests.sh): restauraciones con ignorados, respaldos y archivos nuevos. | Más puntos de fallo de REC-06, falta de espacio real, señales durante la restauración y combinaciones por plataforma. |
| ENT-02 | [Casos ADD](../.agents/tests/task-add-cases.sh): rutas fuera de la zona, recorridos relativos, rutas de Windows y enlaces guardados. | Junctions, enlaces duros, carreras de rutas y una campaña de todas las operaciones restringidas. |
| MEM-04 | [Pruebas generales](../.agents/tests/run-tests.sh), 16a–16e: memoria y destinos preparados distintos del disco. | Matriz completa de codificaciones, volumen y variantes del catálogo MEM. |
| TAR-02, TAR-04 | [Gestor](../.agents/tests/run-task-tests.sh): cierre incompleto, evidencia, resultado y reapertura. | Las 16 transiciones, terminación forzada de procesos y la ventana posterior a la última comprobación de cambios. |
| ADD-01–ADD-04 | [Regresiones ADD](../.agents/tests/task-add-cases.sh): archivos históricos, puntos inválidos, cambios y repetición del acuerdo. | Todas las combinaciones históricas y la revisión semántica por un agente real de ADD-06. |
| INT-01, INT-03, INT-04 | [Regresiones de intentos](../.agents/tests/task-attempt-cases.sh): intento abierto, contexto histórico y desenlaces separados del estado. | Interrupciones de herramientas reales y continuidad entre conversaciones. |
| EVA-01, EVA-04, EVA-06 | [Evaluador](../.agents/tests/run-agent-eval-tests.sh): controles correctos e incorrectos, infraestructura alterada y evidencias históricas. | La procedencia sigue sin acreditarse cuando no se conserva el punto externo; quedan variantes de metadatos y la separación externa de EVA-03. |

Una fila relacionada **no declara cerrado el ID completo**. El catálogo conserva
60 escenarios y varias modalidades; esta fase acredita únicamente las variantes
deterministas descritas y las plataformas donde se haya ejecutado. Los controles
simulados no son una evaluación de un modelo ni una campaña completa.

## Correcciones del motor

- El control previo al guardado rechaza errores al leer el tamaño o contenido
  preparado y usa temporales privados. Antes podía interpretar una lectura fallida
  como tamaño cero o como ausencia de marcadores.
- `agent-eval.sh check` usa un lector Git temporal con objetos, referencias e índice
  capturados. Inspecciona únicamente el formato de objetos como dato, sin seguir
  inclusiones externas; no aplica la configuración, hooks, filtros, atributos auxiliares,
  grafts ni reemplazos del repositorio evaluado. Rechaza metadatos enlazados y
  objetos externos mediante `alternates`; no actualiza el índice observado.
  Mantiene la normalización de texto de las copias preparadas y acepta los tres
  controles existentes. La evaluación requiere una copia autónoma creada por
  `prepare`, con sus metadatos regulares y las escrituras detenidas.
- `prepare` devuelve `BASE_CHECKPOINT`. Conserva ese punto fuera del alcance de
  la copia y pásalo como segundo argumento de `check`; el lector rechaza un
  contrato con otra raíz y no acepta referencias de reemplazo. El uso anterior
  sin ese argumento sigue disponible y declara `CONTRACT_ANCHOR=not_pinned`:
  acredita condiciones observables, sin acreditar la procedencia del contrato.

```sh
sh .agents/scripts/agent-eval.sh prepare evidencia .tmp-test/evaluacion-nueva
# Conserva el BASE_CHECKPOINT devuelto; no lo vuelvas a leer de la copia evaluada.
sh .agents/scripts/agent-eval.sh check .tmp-test/evaluacion-nueva PUNTO_BASE_CONSERVADO
```

Los ensayos iniciales reprodujeron una lectura fallida aceptada por el control
de guardado y la ejecución de un centinela mediante `fsmonitor` con el código
anterior. Los negativos equivalentes se rechazan con las correcciones.

## Informes, CI y límites

`informe.md` identifica fecha UTC, punto, sistema, versión de Git y alcance;
`resultados.tsv` separa los escenarios; `motor.tsv` identifica los bytes probados;
`huellas.tsv` y el recibo externo permiten detectar cambios posteriores. Una
alteración del informe o su sustitución por otro paquete autoconsistente falla
frente al recibo original. Las huellas comprueban integridad, no autoría.

Los informes y las copias con fallos son **privados**, quedan excluidos de los
guardados habituales y no se publican en Pages ni se adjuntan automáticamente
a Actions. Ante un fallo, `PRIVATE_FIXTURES` señala las copias conservadas; un
reintento debe usar carpetas nuevas y conservar el primer resultado.

El [flujo de pruebas](../.github/workflows/tests.yml) ejecuta los siete escenarios
y los cinco controles del recibo y sus rutas en Linux, macOS y Windows, además de
las suites anteriores. Comprueban la evidencia válida, un temporal que invada el
informe, rutas ambiguas, un informe alterado y un paquete sustituido. Para ejecutarlos:

```sh
sh .agents/tests/check-engine-evidence.sh .tmp-test/mi-ensayo-fase2 HUELLA_CONSERVADA
```

Se mantiene `OS_ISOLATION=not_attested`. Las carpetas separadas y el lector privado
no contienen un agente hostil con acceso libre al equipo ni observan red, llamadas,
CPU o procesos. La detección de una edición manual no ofrece una operación
atómica frente a un escritor que ignore el bloqueo después de la última
comprobación. Los escenarios A y las variantes no listadas siguen pendientes.
