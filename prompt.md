# Publica la landing de Repo-as-an-Agent en GitHub Pages

Actúa como el agente de mantenimiento de mi copia de este template. Quiero que publiques la landing incluida en este repositorio usando GitHub Pages y que compruebes que funciona. Puedes crear el punto de guardado, subir los cambios necesarios y activar la publicación en este repositorio. Comunícate en español y usa un lenguaje claro.

## 1. Conoce el espacio y el destino

- Lee `AGENTS.md` y respeta las instrucciones locales. Ejecuta `sh .agents/scripts/boot-check.sh` si esta es una sesión nueva. No inicies la personalización del proyecto salvo que sea necesaria para esta tarea.
- Consulta el estado del trabajo y la URL remota. Identifica el propietario, el nombre del repositorio y su rama predeterminada; no supongas que coinciden con el repositorio original del template.
- Revisa los cambios locales antes de actuar. No sobrescribas trabajo ajeno, no fuerces subidas y no omitas los controles de guardado. Si el punto de guardado pudiera incluir cambios ajenos, sepáralos de forma segura o consulta ese caso concreto antes de guardarlos.
- Comprueba qué acceso autorizado tienes a GitHub. Puedes usar una integración de GitHub o `gh` ya autenticado. No pidas que pegue contraseñas ni tokens en el chat, el código o el sitio.

## 2. Revisa y construye la landing

- El sitio fuente está en `site/`. El archivo `prompt.md` de la raíz es la fuente única de estas instrucciones.
- El flujo de publicación está en `.github/workflows/pages.yml`. Si ya existe, úsalo y corrige solo lo necesario. Si falta, crea un flujo para la rama predeterminada y ejecución manual, con las acciones oficiales de Pages fijadas a revisiones verificadas. Debe tener `contents: read`, `pages: write`, `id-token: write`, el entorno `github-pages` y control de concurrencia.
- Ejecuta `python scripts/build-site.py` (o `python3` si corresponde). El constructor valida los enlaces locales y genera `_site/` con una lista explícita de archivos públicos. Solo esa carpeta se carga como artefacto de Pages.
- No publiques la raíz del repositorio, `workspace/`, `knowledge/`, archivos locales excluidos ni credenciales. No cambies la visibilidad del repositorio para solucionar un problema de Pages.
- Comprueba la sintaxis con `node --check site/app.js` si Node está disponible, y ejecuta `sh .agents/tests/run-tests.sh`. El motor del template usa Git y herramientas POSIX; Python es necesario para construir esta landing. No instales dependencias del proyecto si no hacen falta.
- Previsualiza `_site/` con un servidor HTTP local. Revisa la página en escritorio y móvil, sus anclas, las dos guías de inicio, los ejemplos, el mapa de carpetas, los botones de copia, `prompt.md` y la pausa de animaciones. Respeta la preferencia de movimiento reducido.
- Conserva las rutas relativas de los recursos para que funcionen tanto bajo `/<nombre-del-repositorio>/` como en un dominio propio. No agregues un archivo `CNAME` sin que yo haya pedido un dominio.

## 3. Guarda, configura y publica

- Si hay cambios tuyos por guardar, usa el procedimiento de `.agents/skills/safe-versioning/SKILL.md` y `sh .agents/scripts/git-ops.sh checkpoint "Preparar la landing para GitHub Pages"`. Revisa qué archivos quedarán incluidos antes de ejecutarlo y sube el punto de guardado sin forzar.
- Consulta la configuración actual de Pages. Si no está activado, configúralo con **GitHub Actions** como fuente; si ya existe un sitio diferente, conserva su configuración e informa de la colisión antes de sustituirlo.
- Si usas `gh`, los comandos de consulta pueden ser `gh api repos/PROPIETARIO/REPOSITORIO/pages` y `gh run list --workflow pages.yml`. Para un sitio inexistente, la API admite `gh api --method POST repos/PROPIETARIO/REPOSITORIO/pages -f build_type=workflow`. Sustituye los valores por el destino que identificaste.
- Un repositorio privado puede necesitar un plan que admita Pages. Si tu acceso no permite activar Pages o publicar, explica el bloqueo real y el paso exacto que debo completar. No cambies a otra plataforma ni hagas público el repositorio sin autorización.
- Ejecuta el flujo de publicación si la subida no lo inició: `gh workflow run pages.yml`. Espera su resultado y revisa los registros si falla. Una subida aceptada no confirma que el sitio se haya desplegado.

## 4. Comprueba el resultado y entrégalo

- Obtén la URL real desde el resultado de Pages; no la adivines ni des por publicado un sitio con el flujo pendiente.
- Abre la URL publicada y verifica una respuesta correcta, estilos, JavaScript, favicon y descarga de `prompt.md`. Comprueba los enlaces al template y a la documentación, la navegación interna y las interacciones principales.
- Confirma que el contenido publicado corresponde a la versión subida y que la suite de pruebas y el despliegue terminaron correctamente. Si algo falla, corrígelo y verifica de nuevo.
- Entrégame el enlace público, el enlace a la ejecución de despliegue, un resumen breve de los archivos modificados y si creaste un punto de guardado. Señala cualquier comprobación que no hayas podido completar.

Haz el trabajo completo dentro de este alcance. Pregunta solo si falta un dato imprescindible, existe una colisión con otro sitio o una restricción real de acceso impide continuar.
