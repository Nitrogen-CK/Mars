// Exercise the offline file through the real page controls and keyboard movement.
// No player poses, ingredients or gate states are set through browser evaluation.
const { chromium } = require('C:/Users/Adam/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = __dirname;
const report = { checks: [], errors: [], networkRequests: [] };
(async () => {
  const browser = await chromium.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('request', r => { if (/^https?:/.test(r.url())) report.networkRequests.push(r.url()); });
    await page.goto('file:///' + path.join(root, 'cistern-greybox.html').replaceAll('\\', '/'));
    await page.waitForFunction(() => !!window.greybox);
    await page.waitForTimeout(600);
    await page.screenshot({ path: path.join(root, 'overview.png') });
    report.checks.push({ check: 'offline scene', cells: await page.evaluate(() => greybox.floorCellCount) });
    await page.locator('#plan').click();
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(root, 'plan.png') });
    assert.equal(await page.evaluate(() => greybox.mode), 'plan');
    await page.locator('#layer').selectOption('4');
    assert.equal(await page.locator('#layer').inputValue(), '4');
    await page.locator('#reset').click();
    await page.locator('#roof').check();
    await page.waitForTimeout(100);
    await page.screenshot({ path: path.join(root, 'ceiling.png') });
    await page.locator('#roof').uncheck();
    const gridCheck = await page.evaluate(() => {
      const failures = [];
      // Sample the whole always-open circuit with the actual floor/collision functions.
      let z = 0;
      for (const [i, a] of greybox.data.routes.loop.entries()) {
        const b = greybox.data.routes.loop[i + 1]; if (!b) break;
        const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
        const count = Math.ceil(length / .1);
        for (let j = 0; j <= count; j++) {
          const t = j / count, x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t;
          const next = greybox.floorAt(x, y, z);
          if (next === null || greybox.collides(x, y, next)) failures.push({ x, y, previous: z, next });
          if (next !== null) z = next;
        }
      }
      return failures;
    });
    assert.deepEqual(gridCheck, [], 'Outer circuit has an actual collision/floor discontinuity');
    report.checks.push({ check: 'continuous outer circuit', sample_spacing_m: .1, failures: gridCheck.length });
    for (const id of ['A', 'B', 'C', 'D']) {
      await page.locator(`[data-spawn="${id}"]`).click();
      const s = await page.evaluate(() => ({ ...greybox.player, colliding: greybox.collides(greybox.player.x, greybox.player.y, greybox.player.z) }));
      assert.equal(s.colliding, false, 'Spawn ' + id);
      report.checks.push({ check: 'clear entrance ' + id, at: [s.x, s.y, s.z] });
    }
    await page.locator('[data-spawn="A"]').click();
    const snapshot = () => page.evaluate(() => ({ ...greybox.player }));
    async function walkTo(x, y, label) {
      // A faces north. Axis-aligned keyboard travel keeps that heading throughout.
      const start = Date.now();
      for (const [axis, goal, positive, negative] of [['x', x, 'd', 'a'], ['y', y, 'w', 's']]) {
        let pos = await snapshot();
        const key = pos[axis] < goal ? positive : negative;
        let previous = pos[axis], idle = 0;
        await page.keyboard.down('Shift'); await page.keyboard.down(key);
        try {
          while (Math.abs(pos[axis] - goal) > .23) {
            if (Date.now() - start > 25000) throw Error(label + ': movement timeout at ' + JSON.stringify(pos));
            await page.waitForTimeout(35);
            pos = await snapshot();
            idle = Math.abs(pos[axis] - previous) < .001 ? idle + 1 : 0;
            if (idle > 20) throw Error(label + ': blocked at ' + JSON.stringify(pos));
            previous = pos[axis];
            if ((key === positive && pos[axis] >= goal) || (key === negative && pos[axis] <= goal)) break;
          }
        } finally { await page.keyboard.up(key); await page.keyboard.up('Shift'); }
      }
      const pos = await snapshot();
      report.checks.push({ check: 'actual keys / ' + label, at: [pos.x, pos.y, pos.z] });
      console.log(label, JSON.stringify(pos));
    }
    await walkTo(48, 32, 'kitchen threshold');
    await walkTo(16, 32, 'west court opening');
    await walkTo(16, 51, 'west stair base');
    await walkTo(16, 61, 'west stair climbed');
    assert.equal((await snapshot()).z, 4);
    await walkTo(16, 68, 'west gallery');
    await walkTo(48, 68, 'upper stores');
    await walkTo(80, 68, 'east gallery');
    await walkTo(80, 51, 'east stair descended');
    assert.equal((await snapshot()).z, 0);
    await walkTo(80, 32, 'hunt through-route');
    await walkTo(48, 32, 'arrival return');
    await walkTo(48, 12, 'kitchen return');
    await page.screenshot({ path: path.join(root, 'walk-kitchen.png') });
    // Walk to the actual two-plate shortcut, place the pack with E, step onto the second plate.
    await walkTo(48, 32, 'shortcut approach');
    await walkTo(16, 32, 'shortcut west approach');
    await walkTo(16, 61, 'shortcut stair');
    await walkTo(16, 68, 'shortcut gallery');
    await walkTo(24, 68, 'shortcut west link');
    await walkTo(24, 48, 'bridge west mouth');
    await walkTo(27, 48, 'pack plate reach');
    await page.keyboard.press('e');
    assert.equal(await page.evaluate(() => greybox.state.pack), false);
    await walkTo(32, 48, 'chef plate');
    assert.equal(await page.evaluate(() => greybox.state.latched), true);
    await walkTo(27, 48, 'pack recovery stance');
    await page.keyboard.press('e');
    assert.equal(await page.evaluate(() => greybox.state.pack), true);
    await walkTo(59, 48.5, 'timed chain approach');
    await page.keyboard.press('e');
    assert.ok(await page.evaluate(() => greybox.state.timer > 0));
    await walkTo(64, 48.5, 'timed gate threshold');
    await page.waitForFunction(() => greybox.state.timer === 0, null, {timeout:12000});
    assert.equal(await page.evaluate(() => greybox.gates[1].open), true, 'Closing gate must wait for an occupying walker');
    await walkTo(69, 48.5, 'timed gate crossing');
    await page.waitForTimeout(100);
    assert.equal(await page.evaluate(() => greybox.gates[1].open), false, 'Gate must close after the walker clears');
    await page.screenshot({ path: path.join(root, 'walk-bridge.png') });
    report.checks.push({ check: 'plate latch, pack recovery, chain window, actual gate crossing', passed: true });
    report.desktopPassed = true;
    await page.keyboard.press('Escape');
    await page.locator('#reset').click();
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(root, 'mobile.png') });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.deepEqual(report.errors, []); assert.deepEqual(report.networkRequests, []);
    report.checks.push({ check: '390px responsive / offline requests / page errors', passed: true });
    report.passed = true;
  } finally {
    fs.writeFileSync(path.join(root, 'verification.json'), JSON.stringify(report, null, 2));
    await browser.close();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
