"use strict";

(() => {
  const byId = (id) => document.getElementById(id);
  const status = byId("copy-status");
  let statusTimer;

  function notify(message) {
    clearTimeout(statusTimer);
    status.textContent = message;
    status.classList.add("is-visible");
    statusTimer = setTimeout(() => status.classList.remove("is-visible"), 5000);
  }

  async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      try {
        await navigator.clipboard.writeText(text);
        notify("Copiado. Ya puedes pegarlo en tu agente.");
        return true;
      } catch {
        // A denied clipboard permission can still allow a user-triggered copy.
      }
    }
    const previousFocus = document.activeElement;
    const field = document.createElement("textarea");
    field.value = text;
    field.setAttribute("aria-label", "Texto para copiar");
    field.style.cssText = "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0";
    document.body.append(field);
    field.select();
    let copied = false;
    try {
      copied = document.execCommand("copy");
    } catch {
      copied = false;
    } finally {
      field.remove();
      if (previousFocus instanceof HTMLElement) previousFocus.focus({ preventScroll: true });
    }
    notify(copied ? "Copiado. Ya puedes pegarlo en tu agente." : "El navegador no permitió copiar. Selecciona el texto o descarga prompt.md.");
    return copied;
  }

  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    button.addEventListener("click", () => copyText(byId(button.dataset.copyTarget).textContent.trim()));
  });

  // Every example is explanatory content. No model or filesystem is accessed.
  const demos = {
    notas: {
      request: "Revisa las notas de mi bandeja, ordénalas y guarda los acuerdos importantes.",
      steps: [
        ["Leer tus notas", "Consulta workspace/bandeja/ y las reglas del espacio."],
        ["Preparar un resumen", "Organiza el contenido en workspace/documentos/."],
        ["Conservar los acuerdos", "Registra las decisiones duraderas en knowledge/."]
      ],
      result: "Notas organizadas. Acuerdos localizables."
    },
    idea: {
      request: "Guarda cómo vamos y crea un borrador alternativo de esta propuesta con un tono más directo.",
      steps: [
        ["Guardar el estado actual", "Crea un punto de guardado antes de hacer cambios."],
        ["Explorar un borrador paralelo", "Trabaja la alternativa con git-ops.sh draft-create."],
        ["Mostrar qué cambió", "Resume las diferencias para que tú elijas qué incorporar."]
      ],
      result: "Dos alternativas. Una decisión en tus manos."
    },
    retomar: {
      request: "Lee el contexto del proyecto y dime qué acuerdos tenemos registrados antes de seguir con la propuesta.",
      steps: [
        ["Consultar el índice de memoria", "Empieza por knowledge/index.md y localiza el contexto relevante."],
        ["Recuperar decisiones", "Lee los acuerdos registrados y los documentos relacionados."],
        ["Continuar con una base común", "Resume lo que encontró y confirma contigo el siguiente paso."]
      ],
      result: "Una nueva conversación. El contexto sigue disponible."
    }
  };

  const demoButtons = [...document.querySelectorAll("[data-demo]")];
  function selectTab(buttons, active) {
    buttons.forEach((button) => {
      const selected = button === active;
      button.setAttribute("aria-selected", String(selected));
      button.tabIndex = selected ? 0 : -1;
    });
  }

  function changeDemo(button) {
    const demo = demos[button.dataset.demo];
    selectTab(demoButtons, button);
    byId("demo-panel").setAttribute("aria-labelledby", button.id);
    byId("demo-request").textContent = demo.request;
    byId("demo-result").textContent = demo.result;
    const items = demo.steps.map(([title, description]) => {
      const item = document.createElement("li");
      const check = document.createElement("span");
      check.setAttribute("aria-hidden", "true");
      check.textContent = "✓";
      const content = document.createElement("div");
      const heading = document.createElement("strong");
      heading.textContent = title;
      const paragraph = document.createElement("p");
      paragraph.textContent = description;
      content.append(heading, paragraph);
      item.append(check, content);
      return item;
    });
    byId("demo-steps").replaceChildren(...items);
    const panel = byId("demo-panel");
    panel.classList.remove("is-replaying");
    // Restart only after a deliberate user selection; examples never auto-advance.
    void panel.offsetWidth;
    panel.classList.add("is-replaying");
  }

  function enableTabs(buttons, activate) {
    buttons.forEach((button, index) => {
      button.addEventListener("click", () => activate(button));
      button.addEventListener("keydown", (event) => {
        let next;
        if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (index + 1) % buttons.length;
        else if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (index - 1 + buttons.length) % buttons.length;
        else if (event.key === "Home") next = 0;
        else if (event.key === "End") next = buttons.length - 1;
        else return;
        event.preventDefault();
        activate(buttons[next]);
        buttons[next].focus();
      });
    });
  }

  enableTabs(demoButtons, changeDemo);
  byId("copy-demo").addEventListener("click", () => copyText(byId("demo-request").textContent));
  const audienceButtons = [...document.querySelectorAll("[data-audience]")];
  enableTabs(audienceButtons, (active) => {
    selectTab(audienceButtons, active);
    audienceButtons.forEach((button) => {
      byId(button.getAttribute("aria-controls")).hidden = button !== active;
    });
  });

  const taskButtons = [...document.querySelectorAll("[data-task-state]")];
  enableTabs(taskButtons, (active) => {
    selectTab(taskButtons, active);
    taskButtons.forEach((button) => {
      byId(button.getAttribute("aria-controls")).hidden = button !== active;
    });
  });

  const attemptButtons = [...document.querySelectorAll("[data-attempt-outcome]")];
  enableTabs(attemptButtons, (active) => {
    selectTab(attemptButtons, active);
    attemptButtons.forEach((button) => {
      byId(button.getAttribute("aria-controls")).hidden = button !== active;
    });
  });

  const narrowScreen = window.matchMedia("(max-width: 680px)");
  const updateTabOrientation = () => {
    document.querySelector(".demo-tabs").setAttribute("aria-orientation", narrowScreen.matches ? "horizontal" : "vertical");
  };
  updateTabOrientation();
  narrowScreen.addEventListener("change", updateTabOrientation);

  const zones = {
    workspace: {
      label: "ZONA HUMANA", title: "Tus documentos de verdad.",
      description: "Aquí dejas lo que entra, desarrollas tu trabajo y preparas lo que vas a entregar. Son archivos de tu proyecto, abiertos y editables.",
      tree: "workspace/\n├── bandeja/       notas e ideas\n├── documentos/    trabajo en curso\n├── datos/         tablas CSV\n└── entregables/   versiones finales"
    },
    knowledge: {
      label: "MEMORIA ESTRUCTURADA", title: "El contexto que permanece.",
      description: "Decisiones y acuerdos se conservan en Markdown con metadatos OKF. El agente consulta primero el índice y carga solo los nodos que necesita.",
      tree: "knowledge/\n├── index.md       mapa de la memoria\n├── log.md         registro de actividad\n├── profile/       contexto del proyecto\n└── system/        arquitectura del espacio"
    },
    agents: {
      label: "MOTOR DETERMINISTA", title: "Procedimientos, no improvisación.",
      description: "Las habilidades guían al agente. Los scripts ejecutan operaciones de guardado y validación. Los controles revisan los cambios antes de guardarlos.",
      tree: ".agents/\n├── skills/        procedimientos del agente\n├── scripts/       operaciones y validación\n├── hooks/         controles al guardar\n└── tests/         pruebas de regresión"
    }
  };
  document.querySelectorAll("[data-zone]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-zone]").forEach((candidate) => candidate.setAttribute("aria-pressed", String(candidate === button)));
      const zone = zones[button.dataset.zone];
      byId("zone-label").textContent = zone.label;
      byId("zone-title").textContent = zone.title;
      byId("zone-description").textContent = zone.description;
      byId("zone-tree").textContent = zone.tree;
    });
  });

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const motionButton = byId("motion-toggle");
  function syncMotionPreference() {
    motionButton.hidden = reducedMotion.matches;
  }
  syncMotionPreference();
  reducedMotion.addEventListener("change", syncMotionPreference);
  motionButton.addEventListener("click", () => {
    const paused = document.documentElement.classList.toggle("motion-paused");
    motionButton.setAttribute("aria-pressed", String(paused));
    motionButton.textContent = paused ? "Activar animaciones ▷" : "Pausar animaciones Ⅱ";
  });

  async function loadDeploymentPrompt() {
    const button = byId("copy-deploy");
    try {
      const response = await fetch("prompt.md", { cache: "no-cache" });
      if (!response.ok) throw new Error("Prompt unavailable");
      const prompt = await response.text();
      if (!prompt.startsWith("# Publica la landing")) throw new Error("Unexpected response");
      byId("deploy-prompt").textContent = prompt;
      button.disabled = false;
      button.textContent = "Copiar prompt de despliegue ⧉";
      button.addEventListener("click", async () => {
        const copied = await copyText(prompt);
        if (!copied) byId("deploy-prompt").closest("details").open = true;
      });
    } catch {
      button.textContent = "Descarga el prompt en el enlace →";
      byId("deploy-prompt").textContent = "No se pudo cargar el archivo. Abre o descarga prompt.md desde el enlace de esta sección.";
    }
  }
  loadDeploymentPrompt();
})();
