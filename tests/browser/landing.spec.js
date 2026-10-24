const { test, expect } = require('@playwright/test');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const states = [
  { key: 'pending', label: 'Pendiente', verified: 0, pending: 2 },
  { key: 'active', label: 'En curso', verified: 1, pending: 1 },
  { key: 'blocked', label: 'Bloqueada', verified: 1, pending: 1 },
  { key: 'done', label: 'Terminada', verified: 2, pending: 0 },
];
const normalize = (text) => text.replace(/\r\n/g, '\n');

async function activate(page, locator, isMobile) {
  if (isMobile) await locator.tap();
  else await locator.click();
}

async function expectCopied(page, button, expected, isMobile) {
  // A success message alone cannot prove that the clipboard was updated.
  await page.evaluate(() => navigator.clipboard.writeText('ANTES DE COPIAR'));
  await activate(page, button, isMobile);
  await expect(page.locator('#copy-status')).toHaveText('Copiado. Ya puedes pegarlo en tu agente.');
  await expect.poll(async () => normalize(await page.evaluate(() => navigator.clipboard.readText())))
    .toBe(normalize(expected));
}

async function expectSelected(page, key) {
  await expect(page.locator('[data-task-state][aria-selected="true"]')).toHaveCount(1);
  await expect(page.locator('.task-example:visible')).toHaveCount(1);
  await expect(page.locator(`#task-tab-${key}`)).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator(`#task-tab-${key}`)).toHaveJSProperty('tabIndex', 0);
  await expect(page.locator(`#task-${key}`)).toBeVisible();
  for (const other of states.filter((state) => state.key !== key)) {
    await expect(page.locator(`#task-${other.key}`)).toBeHidden();
    await expect(page.locator(`#task-tab-${other.key}`)).toHaveAttribute('tabindex', '-1');
  }
}

test.beforeEach(async ({ page }) => {
  await page.goto('./');
});

test('la vista sin red conserva un enlace de versiones accesible', async ({ page }) => {
  const repository = process.env.GITHUB_REPOSITORY || 'MauricioPerera/repo-as-an-agent';
  await expect(page.locator('#latest-release')).toHaveAttribute('href', `https://github.com/${repository}/releases`);
  await expect(page.locator('#latest-release .pill-version')).toHaveText('Ver versiones ↗');
});

test('los cuatro estados conservan sus criterios, evidencia y resultado', async ({ page, isMobile }) => {
  await expectSelected(page, 'pending');
  for (const state of states) {
    await activate(page, page.locator(`#task-tab-${state.key}`), isMobile);
    await expectSelected(page, state.key);
    const panel = page.locator(`#task-${state.key}`);
    await expect(panel.locator('.task-badge')).toHaveText(state.label);
    await expect(panel.locator('.task-criteria > li')).toHaveCount(2);
    await expect(panel.locator('.criterion-verified')).toHaveCount(state.verified);
    await expect(panel.locator('.task-criteria strong')).toHaveText(Array(state.verified).fill('Evidencia:'));
    await expect(panel.getByText('Pendiente de verificar', { exact: true })).toHaveCount(state.pending);
    if (state.verified) await expect(panel.locator('.task-criteria')).toContainText('totales contrastados con el presupuesto aprobado.');
    if (state.key === 'blocked') {
      await expect(panel.locator('.task-blocker')).toContainText('Falta la confirmación del cliente sobre los acuerdos.');
    }
    if (state.key === 'done') {
      await expect(panel.locator('.task-criteria')).toContainText('condiciones contrastadas con el acta confirmada por el cliente.');
      await expect(panel.locator('.task-outcome')).toContainText('Propuesta revisada y lista para enviar.');
    } else await expect(panel.locator('.task-outcome')).toHaveCount(0);
    // Check the task section at each state, including narrow touch layouts.
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  }
});

test('las pestañas funcionan con flechas, Inicio y Fin', async ({ page }) => {
  await page.locator('#task-tab-pending').focus();
  for (const [key, selected] of [
    ['ArrowRight', 'active'], ['ArrowDown', 'blocked'], ['ArrowRight', 'done'],
    ['ArrowRight', 'pending'], ['ArrowLeft', 'done'], ['Home', 'pending'], ['End', 'done'],
  ]) {
    await page.keyboard.press(key);
    await expectSelected(page, selected);
    await expect(page.locator(`#task-tab-${selected}`)).toBeFocused();
  }
});

test('el piloto ADD conecta referencia, evidencias y sus puntos de guardado', async ({ page, isMobile }) => {
  await activate(page, page.locator('.site-header nav a[href="#add"]'), isMobile);
  await expect(page).toHaveURL(/#add$/);
  await expect(page.locator('#add-title')).toBeInViewport();
  await expect(page.locator('#add .eyebrow')).toContainText('v1.2.0');
  await expect(page.locator('.add-artifact')).toHaveCount(3);
  await expect(page.locator('#add-reference')).toContainText('workspace/documentos/referencia.md');
  await expect(page.locator('#add-reference')).toContainText('definidas en el pedido del usuario');
  await expect(page.locator('#add-delivery .add-evidence')).toHaveCount(2);
  await expect(page.locator('#add-delivery')).toContainText('Diferencia: 0.');
  await expect(page.locator('#add-close')).toContainText('2 de 2 criterios verificados');
  await expect(page.locator('#add-close .add-result')).toContainText('Propuesta revisada y lista para enviar.');
  await expect(page.locator('.add-rules')).toContainText('retira las verificaciones y entregas anteriores');
  await expect(page.locator('.add-links a').first()).toHaveAttribute('href', /\/docs\/piloto-add\.md$/);
  await expect(page.locator('.add-links a').last()).toHaveAttribute('href', /\/releases\/tag\/v1\.2\.0$/);
  for (const key of ['reference', 'delivery', 'close']) {
    await activate(page, page.locator(`.add-point[href="#add-save-${key}"]`), isMobile);
    await expect(page).toHaveURL(new RegExp(`#add-save-${key}$`));
    await expect(page.locator(`#add-save-${key}`)).toBeInViewport();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  }
});

const outcomes = [
  { key: 'success', label: 'exito', proof: 'revision-cifras.md', observation: 'Diferencia: 0.' },
  { key: 'failure', label: 'fallo', proof: 'fallo-de-acceso.md', observation: 'No se pudo contrastar el total' },
  { key: 'interrupted', label: 'interrumpido', proof: 'revision-parcial.md', observation: 'total pendiente de comprobar' },
];

async function expectOutcome(page, key) {
  await expect(page.locator('[data-attempt-outcome][aria-selected="true"]')).toHaveCount(1);
  await expect(page.locator('.attempt-panel:visible')).toHaveCount(1);
  await expect(page.locator(`#attempt-tab-${key}`)).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator(`#attempt-tab-${key}`)).toHaveJSProperty('tabIndex', 0);
  for (const outcome of outcomes) {
    if (outcome.key === key) await expect(page.locator(`#attempt-${key}`)).toBeVisible();
    else {
      await expect(page.locator(`#attempt-${outcome.key}`)).toBeHidden();
      await expect(page.locator(`#attempt-tab-${outcome.key}`)).toHaveAttribute('tabindex', '-1');
    }
  }
}

test('v1.3.0 muestra los tres desenlaces con contexto y evidencia sin cerrar la tarea', async ({ page, isMobile }) => {
  await activate(page, page.locator('.site-header nav a[href="#evaluaciones"]'), isMobile);
  await expect(page).toHaveURL(/#evaluaciones$/);
  await expect(page.locator('#behavior-title')).toBeInViewport();
  await expect(page.locator('#evaluaciones .eyebrow')).toContainText('v1.3.0');
  await expectOutcome(page, 'success');
  for (const outcome of outcomes) {
    await activate(page, page.locator(`#attempt-tab-${outcome.key}`), isMobile);
    await expectOutcome(page, outcome.key);
    const panel = page.locator(`#attempt-${outcome.key}`);
    await expect(panel.locator('.attempt-badge')).toHaveText(outcome.label);
    await expect(panel.locator('.attempt-fields')).toContainText('Herramienta');
    await expect(panel.locator('.attempt-fields')).toContainText('UTC');
    await expect(panel.locator('.attempt-fields a')).toHaveAttribute('href', '#attempt-save-context');
    await expect(panel.locator('.attempt-evidence code')).toHaveText(`workspace/entregables/${outcome.proof}`);
    await expect(panel.locator('.attempt-evidence')).toContainText(outcome.observation);
    await expect(panel.locator('.attempt-task-rule')).toContainText('La tarea sigue en curso.');
    await expect(page.locator('[data-task-state]')).toHaveCount(4);
  }
});

test('los desenlaces permiten navegación por teclado sin mezclar estados de tarea', async ({ page }) => {
  await page.locator('#attempt-tab-success').focus();
  for (const [key, selected] of [
    ['ArrowRight', 'failure'], ['ArrowDown', 'interrupted'], ['ArrowRight', 'success'],
    ['ArrowLeft', 'interrupted'], ['Home', 'success'], ['End', 'interrupted'],
  ]) {
    await page.keyboard.press(key);
    await expectOutcome(page, selected);
    await expect(page.locator(`#attempt-tab-${selected}`)).toBeFocused();
  }
  await expectSelected(page, 'pending');
});

test('cada evidencia del intento enlaza a su contexto y punto histórico', async ({ page, isMobile }) => {
  await expect(page.locator('.attempt-checkpoints > li')).toHaveCount(4);
  await expect(page.locator('#attempt-save-evidence')).toContainText('registro original abierto');
  await expect(page.locator('#attempt-save-outcome')).toContainText('vínculo al informe');
  for (const outcome of outcomes) {
    await activate(page, page.locator(`#attempt-tab-${outcome.key}`), isMobile);
    for (const part of ['context', 'evidence']) {
      await activate(page, page.locator(`#attempt-${outcome.key} a[href="#attempt-save-${part}"]`), isMobile);
      await expect(page).toHaveURL(new RegExp(`#attempt-save-${part}$`));
      await expect(page.locator(`#attempt-save-${part}`)).toBeInViewport();
    }
  }
});

test('las evaluaciones explican sus tres escenarios, límites y documentación', async ({ page, isMobile }) => {
  await activate(page, page.locator('.site-header nav a[href="#evaluaciones"]'), isMobile);
  await expect(page).toHaveURL(/#evaluaciones$/);
  await expect(page.locator('.evaluation-case-id')).toHaveText(['referencia', 'evidencia', 'alcance']);
  await expect(page.locator('.evaluation-cases article')).toHaveCount(3);
  await expect(page.locator('.evaluation-cases article').nth(1)).toContainText('criterio pendiente');
  await expect(page.locator('.evaluation-cases article').nth(2)).toContainText('4 unidades');
  await expect(page.locator('.evaluation-limit')).toContainText('respuestas simuladas');
  await expect(page.locator('.evaluation-limit')).toContainText('no puntúan un modelo real');
  await expect(page.locator('.behavior-links a').first()).toHaveAttribute('href', /\/docs\/evaluaciones-e-intentos\.md$/);
  await expect(page.locator('.behavior-links a').last()).toHaveAttribute('href', /\/releases\/tag\/v1\.3\.0$/);
});

for (const kind of ['attempt', 'evaluation']) {
  test(`copia el pedido de ${kind === 'attempt' ? 'intentos' : 'evaluación'}`, async ({ page, isMobile }) => {
    const expected = (await page.locator(`#${kind}-request`).textContent()).trim();
    expect(expected.length).toBeGreaterThan(200);
    expect(expected).toContain('punto');
    await expectCopied(page, page.locator(`[data-copy-target="${kind}-request"]`), expected, isMobile);
  });
}

test('copia el flujo de intentos con inicio e informe guardados antes del desenlace', async ({ page, isMobile }) => {
  await activate(page, page.locator('.behavior-technical > summary'), isMobile);
  const expected = (await page.locator('#attempt-code').textContent()).trim();
  expect(expected).toContain('tasks.sh attempt-start');
  expect(expected).toContain('tasks.sh attempt-finish T-123456789abc I-000001 exito');
  expect(expected).toContain('exito, fallo o interrumpido');
  expect(expected.indexOf('Guardar el contexto actual')).toBeLessThan(expected.indexOf('tasks.sh attempt-start'));
  expect(expected.indexOf('Guardar el inicio antes de trabajar')).toBeLessThan(expected.indexOf('Realiza la comprobación'));
  expect(expected.indexOf('Guardar el informe del intento')).toBeLessThan(expected.indexOf('tasks.sh attempt-finish'));
  expect(expected.indexOf('tasks.sh attempt-finish')).toBeLessThan(expected.indexOf('Guardar el desenlace del intento'));
  expect(expected).toContain('tasks.sh history');
  await expectCopied(page, page.getByRole('button', { name: 'Copiar ejemplo técnico de intentos', exact: true }), expected, isMobile);
});

test('copia la evaluación con preparación, pedido al agente y comprobación posterior', async ({ page, isMobile }) => {
  await activate(page, page.locator('.behavior-technical > summary'), isMobile);
  const expected = (await page.locator('#evaluation-code').textContent()).trim();
  expect(expected).toContain('agent-eval.sh prepare referencia .tmp-test/eval-referencia');
  expect(expected).toContain('.agent-eval/PEDIDO.md');
  expect(expected).toContain('agent-eval.sh check .tmp-test/eval-referencia');
  expect(expected.indexOf('agent-eval.sh prepare')).toBeLessThan(expected.indexOf('.agent-eval/PEDIDO.md'));
  expect(expected.indexOf('.agent-eval/PEDIDO.md')).toBeLessThan(expected.indexOf('agent-eval.sh check'));
  expect(expected).toContain('evidencia y alcance');
  await expectCopied(page, page.getByRole('button', { name: 'Copiar comandos de evaluación', exact: true }), expected, isMobile);
});

test('la sección v1.3.0 se adapta de 320 a 1280 px sin desbordamientos', async ({ page }) => {
  for (const width of [320, 390, 680, 900, 1280]) {
    await page.setViewportSize({ width, height: 900 });
    for (const outcome of outcomes) {
      await page.locator(`#attempt-tab-${outcome.key}`).click();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      await expect(page.locator(`#attempt-${outcome.key} .attempt-evidence`)).toBeVisible();
    }
  }
});

const observerCases = [
  { key: 'clean', panel: 'observer-clean', verdict: 'PASS', reason: 'OBSERVABLE_FILE_CONDITIONS_MET', anchor: 'observer-receipt' },
  { key: 'leak', panel: 'observer-leak', verdict: 'FAIL', reason: 'CANARY_LEAK', anchor: 'observer-capture' },
  { key: 'contract', panel: 'observer-contract-error', verdict: 'ERROR', reason: 'CONTRACT_INTEGRITY_ERROR', anchor: 'observer-contract' },
];

async function expectObserverCase(page, key) {
  await expect(page.locator('[data-observer-case][aria-selected="true"]')).toHaveCount(1);
  await expect(page.locator('.observer-panel:visible')).toHaveCount(1);
  for (const sample of observerCases) {
    await expect(page.locator(`#observer-tab-${sample.key}`)).toHaveAttribute('aria-selected', String(sample.key === key));
    await expect(page.locator(`#observer-tab-${sample.key}`)).toHaveJSProperty('tabIndex', sample.key === key ? 0 : -1);
    if (sample.key === key) await expect(page.locator(`#${sample.panel}`)).toBeVisible();
    else await expect(page.locator(`#${sample.panel}`)).toBeHidden();
  }
}

test('v1.4.0 destaca el observador y distingue PASS, FAIL y ERROR', async ({ page, isMobile }) => {
  await activate(page, page.locator('.hero-feature'), isMobile);
  await expect(page).toHaveURL(/#observador$/);
  await expect(page.locator('#observer-title')).toBeInViewport();
  await expect(page.locator('#observador .eyebrow')).toContainText('v1.4.0');
  for (const sample of observerCases) {
    await activate(page, page.locator(`#observer-tab-${sample.key}`), isMobile);
    await expectObserverCase(page, sample.key);
    await expect(page.locator(`#${sample.panel} .observer-verdict`)).toHaveText(sample.verdict);
    await expect(page.locator(`#${sample.panel} .observer-reason`)).toHaveText(sample.reason);
  }
  await expect(page.locator('#observer-clean')).toContainText('No mide la actuación de un modelo.');
  await expect(page.locator('#observer-contract-error')).toContainText('ERROR no es una aprobación.');
  await expectSelected(page, 'pending');
  await expectOutcome(page, 'success');
});

test('el observador permite navegar por teclado sin cambiar las otras demostraciones', async ({ page }) => {
  await page.locator('#observer-tab-clean').focus();
  for (const [key, selected] of [
    ['ArrowRight', 'leak'], ['ArrowDown', 'contract'], ['ArrowRight', 'clean'],
    ['ArrowLeft', 'contract'], ['Home', 'clean'], ['End', 'contract'],
  ]) {
    await page.keyboard.press(key);
    await expectObserverCase(page, selected);
    await expect(page.locator(`#observer-tab-${selected}`)).toBeFocused();
  }
  await expectSelected(page, 'pending');
  await expectOutcome(page, 'success');
});

test('los tres canarios son ejemplos públicos ficticios con ubicaciones diferenciadas', async ({ page }) => {
  await expect(page.locator('.observer-canaries article')).toHaveCount(3);
  await expect(page.locator('.observer-canaries h4')).toHaveText(['Fuga propia', 'Fuga cruzada', 'Fuga externa']);
  await expect(page.locator('.observer-canaries code')).toHaveText([
    'ataque/.env.canario', 'valido/.env.canario', 'observador/contrato/canario-externo',
  ]);
  await expect(page.locator('.observer-demo-token')).toHaveText([
    'CANARY-DEMO-ATAQUE', 'CANARY-DEMO-VALIDO', 'CANARY-DEMO-EXTERNO',
  ]);
  await expect(page.locator('.observer-demo-note')).toContainText('muestras públicas inventadas');
  await expect(page.locator('.observer-demo-note')).toContainText('no lee archivos ni ejecuta pruebas o modelos');
  await expect(page.locator('#observer-leak pre')).toContainText('[valor omitido]');
});

test('el observador muestra los límites de aislamiento e integridad y enlaza su documentación', async ({ page, isMobile }) => {
  await activate(page, page.locator('.site-header nav a[href="#observador"]'), isMobile);
  await expect(page).toHaveURL(/#observador$/);
  await expect(page.locator('.observer-integrity dd code')).toHaveText([
    'CONTRACT_INTEGRITY_ERROR', 'VERIFIER_INTEGRITY_ERROR', 'EVIDENCE_INTEGRITY_ERROR',
  ]);
  await expect(page.locator('.observer-integrity')).toContainText('integridad, no autoría');
  await expect(page.locator('.observer-limits')).toBeVisible();
  await expect(page.locator('.observer-isolation')).toHaveText('OS_ISOLATION=not_attested');
  await expect(page.locator('.observer-limits')).toContainText('no configura una máquina virtual, permisos ni un cortafuegos');
  await expect(page.locator('.observer-limits')).toContainText('512 entradas');
  await expect(page.locator('.observer-limits')).toContainText('1 MiB');
  await expect(page.locator('.observer-limits')).toContainText('8 MiB');
  await expect(page.locator('.observer-limits')).toContainText('60 escenarios del catálogo siguen pendientes');
  await expect(page.locator('.observer-test-summary')).toContainText('35 + 1 SKIP');
  await expect(page.locator('.observer-links a').nth(0)).toHaveAttribute('href', /\/docs\/observador-adversarial\.md$/);
  await expect(page.locator('.observer-links a').nth(1)).toHaveAttribute('href', /\/docs\/testing-adversarial\.md$/);
  await expect(page.locator('.observer-links a').nth(2)).toHaveAttribute('href', /\/releases\/tag\/v1\.4\.0$/);
});

test('los ejemplos del observador conectan contrato, capturas y huellas externas', async ({ page, isMobile }) => {
  await expect(page.locator('.observer-checkpoints > li')).toHaveCount(3);
  await expect(page.locator('#observer-contract')).toContainText('CONTRACT_SEAL');
  await expect(page.locator('#observer-capture')).toContainText('Detén las escrituras');
  await expect(page.locator('#observer-receipt')).toContainText('EVIDENCE_SEAL');
  for (const sample of observerCases) {
    await activate(page, page.locator(`#observer-tab-${sample.key}`), isMobile);
    await activate(page, page.locator(`#${sample.panel} a[href="#${sample.anchor}"]`), isMobile);
    await expect(page).toHaveURL(new RegExp(`#${sample.anchor}$`));
    await expect(page.locator(`#${sample.anchor}`)).toBeInViewport();
  }
});

test('copia el pedido del observador con evidencias privadas y alcance explícito', async ({ page, isMobile }) => {
  const expected = (await page.locator('#observer-request').textContent()).trim();
  expect(expected).toContain('sin lanzar una campaña real de modelos');
  expect(expected).toContain('fuera del alcance del evaluado');
  expect(expected).toContain('capturas en privado');
  await expectCopied(page, page.locator('[data-copy-target="observer-request"]'), expected, isMobile);
});

test('copia la preparación y comprobación con una huella que conserva el operador', async ({ page, isMobile }) => {
  await activate(page, page.locator('.observer-technical > summary'), isMobile);
  const expected = (await page.locator('#observer-prepare-code').textContent()).trim();
  expect(expected).toContain('adversarial.sh prepare .tmp-test/ensayo/agente .tmp-test/ensayo/observador');
  expect(expected).toContain('HUELLA_CONTRATO_CONSERVADA');
  expect(expected).toContain('no scripts de las copias');
  expect(expected.indexOf('adversarial.sh prepare')).toBeLessThan(expected.indexOf('adversarial.sh check'));
  expect(expected.indexOf('detén sus escrituras')).toBeLessThan(expected.indexOf('adversarial.sh check'));
  await expectCopied(page, page.getByRole('button', { name: 'Copiar comandos del observador', exact: true }), expected, isMobile);
});

test('copia la verificación de evidencia sin confundir integridad con una campaña aprobada', async ({ page, isMobile }) => {
  await activate(page, page.locator('.observer-technical > summary'), isMobile);
  const expected = (await page.locator('#observer-evidence-code').textContent()).trim();
  expect(expected).toContain('adversarial.sh verify-evidence RUTA_EVIDENCE HUELLA_EVIDENCIA_CONSERVADA');
  expect(expected).toContain('EVIDENCE_SEAL aparte');
  expect(expected).toContain('solo acredita integridad de archivos');
  await expectCopied(page, page.getByRole('button', { name: 'Copiar verificación de evidencia', exact: true }), expected, isMobile);
});

test('el observador se adapta de 320 a 1280 px con sus comandos desplegados', async ({ page }) => {
  await page.locator('.observer-technical > summary').click();
  for (const width of [320, 390, 680, 900, 1280]) {
    await page.setViewportSize({ width, height: 900 });
    for (const sample of observerCases) {
      await page.locator(`#observer-tab-${sample.key}`).click();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      await expect(page.locator(`#${sample.panel} .observer-reason`)).toBeVisible();
    }
  }
});

for (const kind of ['agreement', 'delivery']) {
  test(`copia el pedido ADD de ${kind === 'agreement' ? 'referencia' : 'entrega'}`, async ({ page, isMobile }) => {
    const expected = (await page.locator(`#add-request-${kind}`).textContent()).trim();
    expect(expected).toContain('punto de guardado');
    expect(expected.length).toBeGreaterThan(150);
    await expectCopied(page, page.locator(`[data-copy-target="add-request-${kind}"]`), expected, isMobile);
  });
}

test('copia el flujo ADD con archivos guardados antes de acordar y entregar', async ({ page, isMobile }) => {
  await activate(page, page.locator('.add-technical > summary'), isMobile);
  const expected = (await page.locator('#add-code').textContent()).trim();
  expect(expected).toContain('tasks.sh agree T-123456789abc workspace/documentos/referencia.md HEAD');
  expect(expected).toContain('tasks.sh deliver T-123456789abc 1 workspace/entregables/cifras.md HEAD');
  expect(expected).toContain('tasks.sh deliver T-123456789abc 2 workspace/entregables/acuerdos.md HEAD');
  expect(expected.indexOf('Guardar la referencia inicial')).toBeLessThan(expected.indexOf('tasks.sh agree'));
  expect(expected.indexOf('Guardar la entrega y los informes comprobados')).toBeLessThan(expected.indexOf('tasks.sh deliver'));
  expect(expected.indexOf('tasks.sh status T-123456789abc terminada')).toBeLessThan(expected.indexOf('Guardar el cierre y sus evidencias'));
  expect(expected).toContain('tasks.sh history T-123456789abc');
  await expectCopied(page, page.getByRole('button', { name: 'Copiar ejemplo técnico de ADD', exact: true }), expected, isMobile);
});

for (const state of states) {
  test(`copia el pedido del estado ${state.label}`, async ({ page, isMobile }) => {
    await activate(page, page.locator(`#task-tab-${state.key}`), isMobile);
    const expected = (await page.locator(`#task-request-${state.key}`).textContent()).trim();
    expect(expected.length).toBeGreaterThan(100);
    await expectCopied(page, page.locator(`[data-copy-target="task-request-${state.key}"]`), expected, isMobile);
  });
}

test('copia el ejemplo técnico con evidencia y puntos vinculados', async ({ page, isMobile }) => {
  await activate(page, page.locator('.task-technical > summary'), isMobile);
  const expected = (await page.locator('#task-code').textContent()).trim();
  expect(expected).toContain('tasks.sh verify');
  expect(expected).toContain('terminada "Propuesta revisada y lista para enviar"');
  expect(expected).toContain('tasks.sh checkpoint T-123456789abc');
  expect(expected).toContain('tasks.sh history T-123456789abc');
  await expectCopied(page, page.getByRole('button', { name: 'Copiar ejemplo técnico de tareas', exact: true }), expected, isMobile);
});

test('copia los mensajes de inicio y las tres demostraciones', async ({ page, isMobile }) => {
  const starter = (await page.locator('#starter-prompt').textContent()).trim();
  await expectCopied(page, page.locator('[data-copy-target="starter-prompt"]'), starter, isMobile);
  for (const key of ['notas', 'idea', 'retomar']) {
    await activate(page, page.locator(`[data-demo="${key}"]`), isMobile);
    const expected = await page.locator('#demo-request').textContent();
    await expectCopied(page, page.locator('#copy-demo'), expected, isMobile);
  }
});

test('copia los comandos de ambas guías técnicas', async ({ page, isMobile }) => {
  await activate(page, page.locator('#audience-technical'), isMobile);
  for (const key of ['setup-code', 'test-code']) {
    const expected = (await page.locator(`#${key}`).textContent()).trim();
    await expectCopied(page, page.locator(`[data-copy-target="${key}"]`), expected, isMobile);
  }
});

test('carga y copia prompt.md completo desde la ruta de proyecto', async ({ page, isMobile }) => {
  const button = page.locator('#copy-deploy');
  await expect(button).toBeEnabled();
  const expected = readFileSync(resolve(__dirname, '../../prompt.md'), 'utf8');
  await expectCopied(page, button, expected, isMobile);
  const response = await page.request.get('prompt.md');
  expect(response.ok()).toBe(true);
  expect(normalize(await response.text())).toBe(normalize(expected));
});

test('la copia alternativa funciona cuando Clipboard API falla', async ({ page, isMobile }) => {
  await page.evaluate(async () => {
    await navigator.clipboard.writeText('ANTES DE COPIAR');
    navigator.clipboard.writeText = async () => { throw new DOMException('Denegado', 'NotAllowedError'); };
  });
  const expected = (await page.locator('#task-request-pending').textContent()).trim();
  await activate(page, page.locator('[data-copy-target="task-request-pending"]'), isMobile);
  await expect.poll(async () => normalize(await page.evaluate(() => navigator.clipboard.readText())))
    .toBe(normalize(expected));
});

test('si las dos vías de copia fallan, permite seleccionar el prompt', async ({ page, isMobile }) => {
  await page.evaluate(() => {
    navigator.clipboard.writeText = async () => { throw new DOMException('Denegado', 'NotAllowedError'); };
    document.execCommand = () => false;
  });
  const button = page.locator('#copy-deploy');
  await expect(button).toBeEnabled();
  await activate(page, button, isMobile);
  await expect(page.locator('#copy-status')).toContainText('El navegador no permitió copiar.');
  await expect(page.locator('#deploy-prompt')).toBeVisible();
});
