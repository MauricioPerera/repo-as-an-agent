# Repo-as-an-Agent

[![Pruebas](https://github.com/MauricioPerera/repo-as-an-agent/actions/workflows/tests.yml/badge.svg?branch=main&event=push)](https://github.com/MauricioPerera/repo-as-an-agent/actions/workflows/tests.yml)
[![Licencia MIT](https://img.shields.io/badge/Licencia-MIT-blue.svg)](LICENSE)
[![Última versión](https://img.shields.io/github/v/release/MauricioPerera/repo-as-an-agent?label=Versi%C3%B3n)](https://github.com/MauricioPerera/repo-as-an-agent/releases/latest)
[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Ver%20landing-2ea44f?logo=github)](https://mauricioperera.github.io/repo-as-an-agent/)

Plantilla universal **agnóstica de motor** (*Antigravity, Codex, Claude Code, OpenCode, Cursor*) que convierte un repositorio Git en un asistente documental y de memoria seguro para **personas no técnicas**.

**Primera versión estable:** [v1.0.0](https://github.com/MauricioPerera/repo-as-an-agent/releases/tag/v1.0.0).
Consulta las novedades en el [historial de cambios](CHANGELOG.md).
Para proponer mejoras y ejecutar las pruebas, consulta la [guía para contribuir](CONTRIBUTING.md).

**Guía visual:** [Visita la landing de GitHub Pages](https://mauricioperera.github.io/repo-as-an-agent/), con recorridos para usuarios técnicos y no técnicos, diagramas y ejemplos interactivos.
Para publicar esta landing en tu propia copia, entrega a tu agente el [prompt de despliegue](prompt.md).

> **¿No eres perfil técnico?** Abre directamente [**LEEME.md**](./LEEME.md) para ver cómo usar este espacio con palabras sencillas.

---

## Qué incluye esta plantilla

1. **Columna vertebral multi-agente (`AGENTS.md` + `CLAUDE.md`):**
   - Contrato de comunicación sin jerga técnica (habla de *puntos de guardado* y *borradores paralelos* en lugar de tecnicismos de Git).
   - Separación estricta entre **Zona Humana** (`workspace/`), **Memoria Estructurada** (`knowledge/`) y **Motor Determinista** (`.agents/`).
2. **Memoria viva en Open Knowledge Format (`knowledge/`):**
   - Nodos Markdown con YAML frontmatter validado, carga progresiva desde `knowledge/index.md` y bitácora en `knowledge/log.md`.
3. **Músculo determinista en POSIX `sh` (`.agents/scripts/` + `.agents/hooks/`):**
   - **Cero dependencias adicionales:** solo requiere tener **Git** instalado (compatible con *Git for Windows*, macOS, Linux y *Git Worktrees*).
   - `okf-lint.sh`: valida el perfil YAML de la memoria y sus enlaces (incluyendo espacios y paréntesis). Al guardar, revisa los archivos exactos preparados y sus destinos, aunque difieran de los archivos locales.
   - `git-ops.sh`: gestiona puntos de guardado, borradores paralelos, conciliaciones y reversiones sin pérdida de datos (`undo-safe` genera etiquetas inmutables `rescate/*` antes de restaurar cualquier versión).
   - `tasks.sh`: gestiona tareas Markdown con cuatro estados, criterios verificados con evidencia e historial vinculado a puntos de guardado; `tasks-lint.sh` valida su formato y las reglas de cierre.
   - Hooks `pre-commit` y `pre-merge-commit`: bloquean automáticamente secretos (`.env`, llaves privadas), archivos >50 MB, marcadores de conflicto y nodos OKF inválidos.
4. **Skills modulares (`.agents/skills/`):**
   - `onboarding`: entrevista breve de bienvenida para personalizar el espacio en la primera sesión.
   - `safe-versioning`: máquina del tiempo y borradores en lenguaje humano.
   - `okf-librarian`: curaduría y enlace de conocimiento duradero.
   - `workspace-assistant`: organización de bandeja de entrada, edición masiva segura y auditoría de tablas CSV.
   - `task-manager`: pendientes, bloqueos, verificación y continuidad del trabajo entre conversaciones.

---

## Cómo usar esta plantilla

1. Haz clic en el botón **`Use this template`** -> **`Create a new repository`** en GitHub (o clona este repositorio).
2. Abre la carpeta clonada con **Antigravity**, **Codex**, **Claude Code** o tu asistente de preferencia.
3. Escribe: *"Hola, configuremos este espacio para mi proyecto"*.
   - En el primer turno, `boot-check.sh` activará automáticamente los hooks locales de Git y detectará el modo plantilla para guiarte en la personalización inicial.

## Tareas vinculadas a puntos de guardado

Pídele al agente: *"Añade una tarea para revisar la propuesta"*, *"¿Qué queda
pendiente?"* o *"Retoma la tarea que estaba en curso"*. Las tareas son archivos
legibles en `workspace/documentos/tareas/`. El gestor usa Git, `sh`, `awk` y las
herramientas habituales incluidas en Git Bash, macOS y Linux, sin instalar paquetes.

Los estados son **pendiente**, **en curso**, **bloqueada** y **terminada**. Una
tarea bloqueada necesita un motivo. Para terminarla, todos sus criterios deben
estar marcados como verificados con evidencia, y debe registrarse un resultado.
El agente debe comprobar la evidencia; el validador verifica su presencia y formato.

Ejemplo técnico, sustituyendo `T-123456789abc` por el ID que devuelve la creación:

```sh
sh .agents/scripts/tasks.sh create "Revisar propuesta" "Preparar el envío al cliente" "Comprobar las cifras"
sh .agents/scripts/tasks.sh list
sh .agents/scripts/tasks.sh status T-123456789abc "en curso"
sh .agents/scripts/tasks.sh verify T-123456789abc 1 "Cifras contrastadas con el presupuesto aprobado"
sh .agents/scripts/tasks.sh status T-123456789abc terminada "Propuesta revisada y lista para enviar"
sh .agents/scripts/tasks.sh checkpoint T-123456789abc "Guardar la propuesta revisada"
sh .agents/scripts/tasks.sh history T-123456789abc
```

`show ID` muestra el archivo y `list "en curso"` filtra por estado. Para bloquear,
usa `status ID bloqueada "motivo"`; para reabrir una tarea terminada, cambia su
estado aportando un motivo. `unverify ID número` retira una verificación después
de reabrir. El resultado anterior se conserva hasta el próximo cierre.

Crear, verificar o cambiar el estado edita el Markdown sin guardar automáticamente.
Antes de crear un punto, revisa qué cambió: el procedimiento de guardado incluye
todos los cambios del repositorio. Puedes asociar varias tareas al mismo punto:

```sh
sh .agents/scripts/git-ops.sh checkpoint "Avance compartido" --task T-123456789abc --task T-abcdef123456
```

La asociación se escribe como metadatos `Task-ID` en el mensaje de guardado.
`history ID` consulta el historial del borrador actual y reúne cambios del archivo
de tarea y asociaciones explícitas, incluso para tareas que fueron eliminadas.
Una tarea puede tener varios guardados, y guardar no cambia su estado. Los
guardados sin cambios siguen sin crear puntos vacíos.

Los encabezados del archivo definen su formato; puedes añadir secciones de notas.
`sh .agents/scripts/tasks.sh lint` diagnostica ediciones manuales inválidas. Los
controles de guardado revisan los archivos preparados y bloquean cierres incompletos.
Las tareas participan en las restauraciones con respaldo del espacio y en los
borradores paralelos. Permanecen fuera del artefacto público de GitHub Pages.

## Validación automatizada

Para ejecutar la suite de pruebas deterministas en un entorno temporal aislado:

```sh
sh .agents/tests/run-tests.sh
sh .agents/tests/run-task-tests.sh
```

Incluye regresiones para archivos ignorados que colisionan con una restauración,
memoria y enlaces preparados distintos de la copia local, y encabezados YAML mal formados.
La suite adicional del gestor cubre el ciclo de tareas, evidencia, asociaciones,
contenido preparado, restauraciones y borradores paralelos, también en un entorno aislado.

El flujo [Pruebas de GitHub Actions](.github/workflows/tests.yml) ejecuta esta misma
suite en Linux, macOS y Windows con cada actualización del repositorio y cada
solicitud de cambios. También puede iniciarse manualmente desde la pestaña Actions.
La landing tiene además pruebas de enlaces, rutas portables y límites de publicación
en `tests/test_site.py`, ejecutadas por el mismo flujo.

## Landing y GitHub Pages

La [landing pública](https://mauricioperera.github.io/repo-as-an-agent/) explica el
template en español con dos recorridos de inicio, diagramas, ejemplos interactivos
y animaciones con opción de pausa y soporte de movimiento reducido.
Su código está en `site/`: HTML, CSS y JavaScript sin dependencias externas.

Para construirla y previsualizarla necesitas Python 3.9 o posterior:

```sh
python -m unittest discover -s tests -p 'test_*.py'
python scripts/build-site.py
python -m http.server 8000 --directory _site --bind 127.0.0.1
```

Abre `http://127.0.0.1:8000`. En algunos entornos el comando se llama `python3`.
Si tienes Node disponible, `node --check site/app.js` comprueba la sintaxis del script.
El constructor genera `_site/` con una lista explícita de archivos públicos; no
incluye `workspace/` ni `knowledge/`. `prompt.md` se copia desde la raíz durante la
construcción, para mantener una sola fuente de las instrucciones de despliegue.

El flujo [Publicar landing](.github/workflows/pages.yml) comprueba y publica el sitio
cuando cambian sus archivos en `main`, y también admite ejecución manual. En tu
copia activa **Settings → Pages → Build and deployment → Source → GitHub Actions**.
Si usas otra rama predeterminada, ajusta el filtro del flujo. Pages en repositorios
privados depende del plan de GitHub; activar Pages no requiere hacer público el repo.
El artefacto público es únicamente `_site/`.

Para delegar todo el proceso, copia el contenido de [prompt.md](prompt.md) a tu agente.
Incluye construcción, configuración, publicación y verificación del sitio resultante.

## Formato de memoria admitido

Para mantener la instalación sin dependencias adicionales, los encabezados usan un
perfil YAML explícito: un mapa plano con campos `nombre: valor`, escalares de una
sola línea (sin comillas o con comillas simples/dobles) y listas de escalares en línea
como `tags: ['cliente', 'acuerdo']`. Las comillas y listas deben cerrar; las claves no
pueden repetirse. `type`, `title` y `description` requieren valores escalares no vacíos
ni nulos. Los comentarios deben separarse del valor por un espacio.

Los mapas anidados, bloques multilínea, etiquetas y alias no forman parte de este
perfil y se rechazan con un diagnóstico. El validador está en
`.agents/scripts/okf-frontmatter.awk` y se ejecuta con el `awk` incluido en el entorno.
`sh .agents/scripts/okf-lint.sh` revisa los archivos locales;
`sh .agents/scripts/okf-lint.sh --staged` revisa la versión preparada para guardar.

## Restauraciones y archivos locales excluidos

Los archivos excluidos por `.gitignore` pueden contener secretos y no se incorporan
automáticamente a los rescates. Si una restauración pudiera sobrescribir uno de
ellos, `undo-safe` devuelve `UNDO_STATUS=BLOCKED_IGNORED_FILES` antes de cambiar
archivos o crear un rescate. Mueve los archivos indicados fuera del repositorio
antes de volver a intentar. Los archivos excluidos sin colisión permanecen intactos.

## Licencia

Este proyecto se distribuye bajo la [licencia MIT](LICENSE).
