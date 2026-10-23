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
