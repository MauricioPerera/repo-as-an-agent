# Piloto de desarrollo guiado por artefactos (ADD)

ADD conecta lo que se acordó con lo que se entrega. Antes de ejecutar una tarea,
el agente registra una referencia concreta; al entregar, presenta evidencia por
criterio. La persona puede contrastar ambos usando archivos y puntos de guardado.
La propuesta se inspira en el [manifiesto de Kosuke](https://kosuke.ai/blog/manifesto).

Este piloto es **opcional por tarea**, local y sin paquetes adicionales. Usa el
mismo gestor, los mismos cuatro estados (**pendiente**, **en curso**, **bloqueada**
y **terminada**) y los vínculos `Task-ID` existentes. Las tareas anteriores siguen
funcionando con `verify` y evidencia escrita.

## Qué puedes pedirle al agente

> Usa el piloto ADD para revisar esta propuesta. Toma como referencia el esquema
> que acordamos en el pedido, guárdalo y vincúlalo a la tarea. Al terminar, muéstrame
> los informes que demuestran cada criterio y el punto de guardado que los contiene.

Una referencia puede ser una muestra de documento, una tabla de ejemplo, un
diagrama, un boceto o un texto corto con el resultado esperado. El agente registra
de dónde surge el acuerdo: un pedido claro puede bastar. Consulta contigo las
decisiones que sigan ambiguas; el piloto no añade una aprobación obligatoria a
cada operación.

Las evidencias deben corresponder al criterio: para una landing, capturas y un
informe de interacciones; para cifras, una conciliación; para documentos, una
revisión contra la referencia. Un archivo presente demuestra que existe, pero
su contenido debe ser comprobado por el agente o la persona responsable.

## Flujo completo desde la terminal

Desde la raíz de tu copia, usando Git Bash en Windows o una terminal POSIX en
macOS/Linux. Primero crea los archivos reales de referencia y define criterios:

```sh
sh .agents/scripts/tasks.sh create "Revisar propuesta" "Preparar el envío al cliente" "Cifras contrastadas" "Acuerdos contrastados"
```

Usa el ID devuelto en lugar de `T-123456789abc` en los siguientes ejemplos.
La referencia del ejemplo debe existir en `workspace/documentos/referencia.md`.

```sh
# Guarda primero la referencia: agree exige un archivo ya guardado.
sh .agents/scripts/tasks.sh checkpoint T-123456789abc "Guardar la referencia inicial"
sh .agents/scripts/tasks.sh agree T-123456789abc workspace/documentos/referencia.md HEAD "Esquema y ejemplo solicitados en el pedido del usuario"
sh .agents/scripts/tasks.sh checkpoint T-123456789abc "Guardar el acuerdo antes de ejecutar"
sh .agents/scripts/tasks.sh status T-123456789abc "en curso"
```

Realiza el trabajo y las comprobaciones. Escribe los resultados observados en
archivos reales, por ejemplo `workspace/entregables/revision-cifras.md` y
`workspace/entregables/revision-acuerdos.md`. Incluye qué se comparó, el resultado,
las limitaciones y, si corresponde, enlaces a las ejecuciones de pruebas. Conserva
una copia local útil del informe cuando un enlace externo pueda caducar.

```sh
# Guarda la entrega y sus informes después de comprobarlos.
sh .agents/scripts/tasks.sh checkpoint T-123456789abc "Guardar la entrega y los informes comprobados"
sh .agents/scripts/tasks.sh deliver T-123456789abc 1 workspace/entregables/revision-cifras.md HEAD "Totales contrastados con el presupuesto: diferencia cero"
sh .agents/scripts/tasks.sh deliver T-123456789abc 2 workspace/entregables/revision-acuerdos.md HEAD "Condiciones contrastadas con el acta confirmada"
sh .agents/scripts/tasks.sh show T-123456789abc
sh .agents/scripts/tasks.sh status T-123456789abc terminada "Propuesta revisada y lista para enviar"
sh .agents/scripts/tasks.sh checkpoint T-123456789abc "Guardar el cierre y sus evidencias"
sh .agents/scripts/tasks.sh history T-123456789abc
```

`HEAD` significa el último punto de guardado del borrador actual. Los comandos lo
convierten inmediatamente en una referencia completa e inmutable. También admiten
un punto anterior o una etiqueta que resuelva a un punto del historial actual.
Los informes deben existir en el punto que se indique, y ese punto debe contener
en su historial el punto de la referencia acordada. Se guardan los archivos
primero y el registro de cierre después, evitando una referencia al cierre aún
inexistente.

## Qué registra el Markdown

La tarea mantiene su objetivo, criterios, resultado y motivo. El piloto añade:

```text
## Referencia acordada
Archivo: workspace/documentos/referencia.md
Punto: <referencia completa del punto guardado>
Acuerdo: Esquema y ejemplo solicitados en el pedido del usuario

## Evidencias de entrega
### Criterio 1
Archivo: workspace/entregables/revision-cifras.md
Punto: <referencia completa del punto con el informe>
Observación: Totales contrastados con el presupuesto: diferencia cero
```

Los marcadores entre `<...>` son explicativos: los comandos escriben referencias
reales. Cada `deliver` marca su criterio como verificado y registra tanto la
observación como el archivo y su punto. Se permite reutilizar un informe para
varios criterios, indicando una observación concreta para cada uno.

`show` presenta el registro completo. `history` reúne cambios en la tarea,
asociaciones `Task-ID` y los puntos de sus artefactos actuales, incluso si esos
puntos no cambiaron la tarea ni tenían una asociación explícita. Después de
retirar una tarea, siguen disponibles sus puntos con cambios y asociaciones; las
referencias de sus artefactos se pueden consultar abriendo esas versiones anteriores.

Para abrir exactamente un archivo histórico, usa la referencia completa que
aparece en `Punto:`:

```sh
git show PUNTO:workspace/documentos/referencia.md
git show PUNTO:workspace/entregables/revision-cifras.md
```

La ruta es relativa a la raíz del repositorio y usa `/`; se admiten espacios,
paréntesis y nombres UTF-8. Conserva los argumentos entre comillas si los necesitan.
Se aceptan archivos regulares no vacíos en `workspace/`, fuera de la propia zona
de tareas. Se rechazan rutas absolutas, recorridos `..`, enlaces simbólicos,
carpetas y archivos inexistentes en el punto indicado.

## Cambios, reaperturas y límites

- **Acuerdo nuevo:** `agree` activa el piloto o cambia la referencia. Retira las
  verificaciones y las entregas anteriores para comprobar los criterios contra
  el nuevo acuerdo. Conserva el estado y las notas libres. Repetir exactamente
  el mismo archivo, punto y acuerdo no modifica nada.
- **Nueva evidencia:** repetir `deliver` para un criterio sustituye su entrega.
  `unverify` retira su verificación y su entrega, conservando las de los demás.
- **Tarea terminada:** primero reábrela con un motivo para cambiar acuerdos o
  entregas. Guardar un avance sigue sin cerrar una tarea automáticamente.
- **Cierre:** exige todos los criterios verificados, una entrega por criterio y
  un resultado escrito. `verify` con texto libre se mantiene para tareas normales;
  las tareas ADD usan `deliver`.
- **Versión comprobada:** los vínculos describen los archivos y el contexto del
  punto indicado, aunque después se editen o retiren las copias locales. No
  certifican automáticamente cambios posteriores ni que una observación sea
  verdadera. Si cambia el trabajo o un criterio, reabre y vuelve a comprobar lo
  afectado. Las pruebas técnicas siguen siendo necesarias.

El control de guardado comprueba los registros exactos que se van a guardar y
resuelve sus archivos en los puntos históricos, no en las copias locales. Los
registros ADD editados manualmente reciben esas mismas comprobaciones. La validación es local: no
necesita GitHub ni acceso a Internet. En una copia con historial incompleto,
recupera los puntos necesarios antes de usar sus referencias.

Los acuerdos y los informes del usuario permanecen en `workspace/`, excluidos
del artefacto público de Pages. Un informe breve en Markdown suele bastar;
conserva los vídeos grandes fuera del repositorio y enlázalos desde el informe
cuando corresponda. Los controles de archivos sensibles y de tamaño siguen activos.

## Evaluar el piloto

Úsalo primero en unas pocas tareas. Registra si la referencia evitó aclaraciones,
si la evidencia permitió decidir que la entrega cumplía el pedido y si hubo que
rehacer trabajo. El piloto permite medir su utilidad dentro de nuestro proyecto.

Las regresiones se ejecutan con `sh .agents/tests/run-task-tests.sh`, en su
repositorio temporal, también en Linux, macOS y Windows mediante GitHub Actions.
