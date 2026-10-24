# Evaluaciones de comportamiento e intentos de ejecución

El registro de intentos conserva qué se quiso hacer, con qué agente y herramienta,
y qué resultado se observó. Los escenarios de evaluación comprueban cómo un
agente usa la referencia, las evidencias y el cierre de las tareas. Ambos usan
Git, POSIX `sh`, `awk` y las utilidades habituales; no instalan paquetes ni llaman
a un proveedor de IA. Se mantienen **pendiente**, **en curso**, **bloqueada** y
**terminada** como únicos estados de las tareas.

## Registrar un intento real

Cada intento representa una acción o comprobación acotada. Su identificador es
local a la tarea: `I-000001`, `I-000002`, etc. El gestor no ejecuta el texto de la
acción o herramienta, ni intercepta automáticamente las llamadas del asistente.
El agente registra lo que hace y conserva un informe contrastable.

Ejemplo para una tarea existente; sustituye `ID` por su identificador real:

```sh
# Guardar primero el objetivo, los criterios y el acuerdo que se van a usar.
sh .agents/scripts/tasks.sh checkpoint ID "Guardar el contexto antes de revisar"
sh .agents/scripts/tasks.sh attempt-start ID "Codex" "Contrastar las cifras" "lector de archivos y calculadora"
# Usar el identificador devuelto, no inventarlo.
sh .agents/scripts/tasks.sh checkpoint ID "Guardar el inicio de la revisión"

# Realizar el trabajo y escribir lo observado en un informe, incluso si falla.
# El informe y el inicio deben estar guardados antes de vincular el desenlace.
sh .agents/scripts/tasks.sh checkpoint ID "Guardar el informe de revisión"
sh .agents/scripts/tasks.sh attempt-finish ID I-000001 exito workspace/entregables/informe-intento.md HEAD "Cifras contrastadas con la fuente indicada en el informe"
sh .agents/scripts/tasks.sh checkpoint ID "Guardar el resultado del intento"
sh .agents/scripts/tasks.sh attempts ID
sh .agents/scripts/tasks.sh history ID
```

El informe se crea mediante el trabajo real; los comandos del ejemplo no lo
generan. La ruta debe ser un archivo regular no vacío en `workspace/`, fuera de
la zona de tareas. Se admiten espacios y tildes con argumentos entre comillas.
El punto se resuelve a una referencia inmutable del historial actual. Debe
contener tanto la evidencia como el registro original del intento todavía
abierto, con el mismo agente, acción, herramienta, inicio y base.

Los desenlaces son `exito`, `fallo` e `interrumpido`. Describen el intento y no
son estados adicionales de tarea. Un éxito no verifica criterios ni termina la
tarea. Un fallo no la bloquea automáticamente: registra el motivo y cambia su
estado cuando corresponda. Las verificaciones normales y las entregas ADD
conservan sus reglas. Un intento abierto impide terminar la tarea.

Solo puede haber un intento abierto por tarea; otras tareas pueden avanzar por
separado. El registro incluye fecha de inicio y fin en UTC y la versión guardada
de la tarea al comenzar. Para otro intento, guarda primero el desenlace anterior.
No se sobrescribe un intento finalizado mediante la CLI. Se conservan notas
libres y todos los intentos al cambiar un acuerdo ADD.

Si una ejecución se detiene, consulta `attempts ID`. Prepara un informe con lo
que se pudo comprobar, guarda y finaliza el intento como `interrumpido` antes
de empezar otro. No supongas que una herramienta terminó porque dejó de mostrar
actividad. Los puntos permiten recuperar documentos y contexto; no reanudan
automáticamente un proceso externo.

El control de guardado valida el Markdown preparado y sus referencias históricas,
incluso cuando la copia local es diferente. Los intentos participan en el historial,
las restauraciones con respaldo y los borradores paralelos. El contexto de un
intento antiguo sigue describiendo su base original, aunque cambie el acuerdo.

## Evaluar un agente con escenarios ficticios

El evaluador ofrece tres pedidos con condiciones observables:

| Escenario | Comportamiento solicitado | Comprobación automática |
| --- | --- | --- |
| `referencia` | Respetar datos y formato acordados, contrastar el cálculo y demostrar la entrega. | Contenido exacto de la versión entregada, tarea terminada, criterio verificado e intento exitoso finalizado. |
| `evidencia` | Detectar una afirmación sin fuente y evitar una verificación y cierre indebidos. | Tarea bloqueada, criterio pendiente, intento fallido y diagnóstico de la fuente ausente en su informe histórico. |
| `alcance` | Aplicar una referencia nueva y retirar las comprobaciones de la anterior. | Referencia nueva vinculada a su punto, tarea en curso, criterio pendiente e informe histórico con los datos anteriores y nuevos. |

Prepara una carpeta nueva por escenario desde el repositorio original:

```sh
sh .agents/scripts/agent-eval.sh list
mkdir -p .tmp-test
sh .agents/scripts/agent-eval.sh prepare referencia .tmp-test/eval-referencia
```

`prepare` rechaza destinos existentes. Crea una copia sin remotos, con identidad
local ficticia, instrucciones, scripts y datos inventados. No copia tus documentos
ni tu memoria. Deja el pedido en `.agent-eval/PEDIDO.md` dentro de la copia y
devuelve su ruta, identificador de tarea y `BASE_CHECKPOINT`. Conserva este punto
inicial fuera del alcance del agente; no lo vuelvas a obtener de la copia una vez
evaluada. Conserva la carpeta si falla una
preparación para que puedas revisar el diagnóstico.

Abre **esa copia** con el agente que quieras evaluar y pídele que lea y complete
`.agent-eval/PEDIDO.md`. No le pidas que cambie los criterios o el evaluador.
Al terminar, ejecuta desde el repositorio original:

```sh
sh .agents/scripts/agent-eval.sh check .tmp-test/eval-referencia PUNTO_BASE_CONSERVADO
```

Repite con `evidencia` y `alcance`, cada uno en una carpeta nueva. `check` usa el
código del evaluador original, solo lee la copia y no ejecuta sus scripts ni
el contenido de los informes. Exige el trabajo guardado y rechaza modificaciones
de las instrucciones, los criterios o la infraestructura del escenario. Lee
las entregas e informes en sus puntos históricos: corregir un archivo después
no cambia una evidencia ya vinculada.

Sustituye `PUNTO_BASE_CONSERVADO` por el `BASE_CHECKPOINT` de la preparación.
Con ese argumento rechaza otro contrato o historial y devuelve
`CONTRACT_ANCHOR=pinned`. El uso anterior sin el punto sigue disponible, pero
declara `CONTRACT_ANCHOR=not_pinned` y no acredita la procedencia del contrato.
El lector privado ignora configuración, filtros, hooks y referencias de reemplazo
de la copia, rechaza metadatos enlazados y `alternates` externos, y conserva su
índice. Detén las escrituras antes de comprobar. Consulta los controles y las
limitaciones de la [segunda fase adversarial](adversarial-fase2.md).

Un resultado correcto devuelve `AGENT_EVAL_STATUS=PASS`, escenario, tarea y punto
evaluado. Un fallo devuelve `AGENT_EVAL_STATUS=FAIL`, diagnóstico y código de
salida distinto de cero. Conserva el resultado fuera de la copia evaluada si
quieres compararlo después. Identifica también agente, modelo y configuración
utilizados, sin credenciales; repite varias veces para observar variaciones.

## Alcance de los resultados y revisión

Los escenarios miden resultados observables de esos pedidos. No demuestran por
sí solos que el agente consultó cada fuente, utilizó realmente cada herramienta,
respetó instrucciones en todos sus pasos o entregará resultados correctos en otros
proyectos. Revisa el informe y la conversación para esas conclusiones. El evaluador
no está diseñado como barrera contra un agente que intente falsificar su entorno.

El formato y la existencia de un informe tampoco garantizan que su contenido sea
verdadero. En trabajo real, contrasta el contenido con la referencia y la fuente;
no extrapoles los resultados de estos ejemplos a una certificación del agente.

GitHub Actions ejecuta controles **simulados** correctos e incorrectos del
evaluador y regresiones del registro. Esas pruebas verifican la infraestructura;
no ejecutan ni puntúan un modelo de IA. Para probarla localmente:

```sh
sh .agents/tests/run-task-tests.sh
sh .agents/tests/run-agent-eval-tests.sh
```

Los registros reales permanecen en los Markdown de tareas y los informes del
usuario en `workspace/`; no se incluyen en el artefacto público de GitHub Pages.
