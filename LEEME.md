# Tu Espacio de Trabajo Inteligente

Bienvenido. Esta carpeta combina tus documentos con una **máquina del tiempo invisible** y un **asistente de Inteligencia Artificial** que recuerda el contexto de tus proyectos.

No necesitas saber programar ni aprender comandos técnicos: **solo abre esta carpeta con tu asistente de IA favorito y pídele lo que necesites con tus propias palabras.**

---

## ¿Dónde guardo mis archivos?

Todo tu trabajo vive dentro de la carpeta **`workspace/`**:

* **`workspace/bandeja/`** — *Tu bandeja de entrada.* Suelta aquí notas rápidas, transcripciones de reuniones, borradores sueltos o ideas sin orden. Luego dile a tu asistente: *"Organiza lo que dejé en la bandeja"*.
* **`workspace/documentos/`** — *Tus textos principales.* Propuestas, manuales, capítulos, contratos o apuntes limpios.
* **`workspace/datos/`** — *Tus listas y tablas.* Presupuestos, inventarios o registros en formato `.csv` (compatibles con Excel) donde el asistente puede ayudarte a limpiar datos sin perder rastro de ningún número.
* **`workspace/entregables/`** — *Versiones listas para enviar.* Documentos finales preparados para compartir con clientes o colegas.

---

## Frases útiles que puedes decirle a tu asistente

### Para empezar por primera vez
* *"Hola, configuremos este espacio para mi proyecto."*

### Para trabajar sin miedo a equivocarte
* *"Guarda un punto de control antes de que cambiemos esta sección."*
* *"Crea un borrador alternativo de esta propuesta con un tono más directo."*
* *"¿Qué cambió exactamente en mis documentos desde la semana pasada?"*
* *"No me convenció este último cambio, vuelve a como estaba antes."*

### Para organizar y recordar información
* *"Revisa los apuntes de mi bandeja de entrada, ordénalos y guarda los datos clave en tu memoria."*
* *"¿Qué acuerdos tenemos registrados sobre este proyecto?"*

---

## Para organizar tus pendientes

Puedes decirle a tu asistente:

* *"Crea una tarea para revisar la propuesta y anota cómo sabremos que está lista."*
* *"Muéstrame las tareas pendientes y retoma la que estaba en curso."*
* *"Esta tarea está bloqueada porque falta la respuesta del cliente."*
* *"Comprueba los criterios, registra el resultado y guarda el avance de esta tarea."*

Las tareas quedan en `workspace/documentos/tareas/`, como archivos que puedes
leer. Cada una puede estar **pendiente**, **en curso**, **bloqueada** o **terminada**.
El asistente debe registrar qué comprobó antes de darla por terminada. Guardar
un avance conserva una versión y lo relaciona con la tarea; puedes guardar
varios avances durante el mismo trabajo.

### Para acordar un resultado y revisar su entrega

Puedes pedir: *"Usa el piloto ADD: toma este esquema como referencia y, al
entregar, muéstrame las pruebas de que se cumplió"*. El asistente guarda la
referencia acordada y relaciona las evidencias con la tarea y sus puntos de
guardado. Conservas los mismos cuatro estados. Si cambia el acuerdo, hay que
comprobar de nuevo sus criterios antes de terminar.

Consulta la [guía del piloto ADD](docs/piloto-add.md). El agente debe comprobar
las evidencias: que exista un informe no demuestra por sí solo que sea correcto.

## Carpetas que mantiene tu asistente (no necesitas tocarlas)

* **`knowledge/`**: Es la memoria ordenada de tu asistente (escrita en archivos legibles por si algún día quieres consultarlos).
* **`AGENTS.md` / `CLAUDE.md` / `.agents/`**: Son las instrucciones y frenos de seguridad que obligan al asistente a cuidar tus archivos y no perder nunca una versión anterior.
