// Real WASM UI checks. No app-state injection or screenshot-difference oracles.
// Usage: node web_lifecycle.cjs PORT OUTPUT_DIR
const {chromium} = require('playwright');
const {stableTarget} = require('./stable_target.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const port = process.argv[2] || '8765';
const out = process.argv[3] || '/tmp/naga-qa/lifecycle';
const width = Number(process.env.QA_WIDTH || 1280);
const launch = {headless: true, ...(process.env.QA_BROWSER_CHANNEL ? {channel: process.env.QA_BROWSER_CHANNEL} : {})};
const scenarios = [];
const test = (name, run) => scenarios.push({name, run});
const button = (page, name) => page.getByRole('button', {name, exact: true});
const groupText = (page, prefix) =>
  page.getByRole('group', {name: new RegExp('^' + prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))});
// Trusted locator taps wait for actionability before targeting Flutter semantics.
async function touchButton(page, name) {
  await button(page, name).tap();
}
async function boot(page) {
  await page.goto(`http://127.0.0.1:${port}/`);
  assert.equal(await page.evaluate(() => crossOriginIsolated), true, 'WASM requires COOP/COEP');
  await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 30000});
  await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
  await button(page, 'Settings').waitFor();
}
async function mode(page, index) {
  await page.mouse.click(width / 2, 170);
  for (let n = 0; n <= index; n++) {
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(65);
  }
  await page.keyboard.press('Enter');
  await page.locator('flt-semantics', {hasText: /^SCORE: \d+/}).first().waitFor();
}
// Game-over overlay text is exposed only as the combined accessibility group
// name; capture both from aria snapshots rather than exact text nodes.
async function over(page, result = 'GAME OVER') {
  await button(page, 'PLAY AGAIN').waitFor({timeout: 20000});
  await groupText(page, result).waitFor();
  const snap = await page.locator('body').ariaSnapshot();
  const hud = snap.match(/text: "(?:LIVES: \d+ )?SCORE: (\d+)/);
  const final = snap.match(/Score: (\d+)/);
  assert.ok(hud && final, `Both HUD and result scores must be exposed: ${snap}`);
  assert.equal(hud[1], final[1], 'Final score must match the HUD');
  return Number(hud[1]);
}
async function menu(page, touch = false) {
  if (touch) await touchButton(page, 'BACK TO MENU');
  else await button(page, 'BACK TO MENU').click();
  await groupText(page, 'THE SNAKE GAME').waitFor();
  await button(page, 'Settings').waitFor();
  assert.equal(await button(page, 'PLAY AGAIN').count(), 0);
}
// Settings tiles already support keyboard traversal, including off-screen tiles.
// Observe persisted storage only; NEVER seed preferences or patch application state.
async function settings(page, choices) {
  await button(page, 'Settings').click();
  await page.getByRole('heading', {name: 'Settings', exact: true}).waitFor();
  await page.mouse.click(width / 2, 75);
  let current = -1;
  for (const [index, key, value] of choices) {
    while (current < index) { await page.keyboard.press('ArrowDown'); current++; }
    while (current > index) { await page.keyboard.press('ArrowUp'); current--; }
    await page.keyboard.press('Enter');
    await page.waitForFunction(({key, value}) => localStorage.getItem(`flutter.${key}`) === JSON.stringify(value), {key, value});
  }
  await button(page, 'Back').click();
  await button(page, 'Settings').waitFor();
}

test('classic-death-restart-menu', async page => {
  await mode(page, 0);
  const score = await over(page);
  await button(page, 'PLAY AGAIN').click();
  await button(page, 'PLAY AGAIN').waitFor({state: 'hidden'});
  await page.locator('flt-semantics', {hasText: /^(?:LIVES: \d+ )?SCORE: 0(?:\s|$)/}).first().waitFor();
  await over(page);
  await menu(page);
  return {score, restartedScore: 0, deaths: 2, menu: true};
});

test('settings-reload-lives-and-restart', async page => {
  await settings(page, [[3, 'grid_size', 0], [9, 'lives', 1], [21, 'start_speed', 1], [27, 'control_type', 1]]);
  const persisted = await page.evaluate(() => Object.fromEntries(Object.entries(localStorage).filter(([k]) => /^flutter\.(grid_size|lives|start_speed|control_type)$/.test(k))));
  assert.equal(Object.keys(persisted).length, 4);
  await boot(page); // New Flutter runtime: not the singleton's in-memory cache.
  assert.deepEqual(await page.evaluate(keys => Object.fromEntries(keys.map(k => [k, localStorage.getItem(k)])), Object.keys(persisted)), persisted);
  await mode(page, 1); // Arcade applies lives, speed and wall settings.
  await page.locator('flt-semantics', {hasText: /^LIVES: 1/}).first().waitFor();
  // Straight movement reaches the wall, respawns, then reaches it again.
  await page.locator('flt-semantics', {hasText: /^LIVES: 0/}).first().waitFor({timeout: 20000});
  assert.equal(await button(page, 'PLAY AGAIN').count(), 0, 'First death must consume the extra life and respawn');
  const score = await over(page);
  await button(page, 'PLAY AGAIN').click();
  await button(page, 'PLAY AGAIN').waitFor({state: 'hidden'});
  await page.locator('flt-semantics', {hasText: /^LIVES: 1/}).first().waitFor();
  await page.locator('flt-semantics', {hasText: /^(?:LIVES: \d+ )?SCORE: 0(?:\s|$)/}).first().waitFor();
  return {persisted, lives: [1, 0, 1], score, restartedScore: 0};
});

// With no input the two snakes collide head-on. Diverting only one player
// makes a different named winner. This proves routing, not just key dispatch.
// Production mapping and instructions: P1=WASD, P2=arrows.
for (const [key, winner] of [['w', 'Player 2 Wins!'], ['ArrowDown', 'Player 1 Wins!']]) {
  test(`duel-${key.toLowerCase()}`, async page => {
    await mode(page, 17);
    await page.keyboard.press(key);
    const score = await over(page, winner);
    await menu(page);
    return {key, winner, score};
  });
}

test('touch-taps-and-mouse-drag-duel', async page => {
  await mode(page, 17);
  // Semantics can appear before the route slide finishes; wait for stable
  // bounds (rAF-based) so the tap targets the pause button at its final point.
  const pauseButton = page.getByRole('button').nth(2);
  await stableTarget(pauseButton);
  await pauseButton.tap();
  await button(page, 'PAUSED Tap to resume').waitFor();
  await page.waitForTimeout(1200); // Longer than the unattended head-on death.
  assert.equal(await button(page, 'PLAY AGAIN').count(), 0);
  await touchButton(page, 'PAUSED Tap to resume');
  await button(page, 'PAUSED Tap to resume').waitFor({state: 'hidden'});
  // Mouse drag exercises the shared drag recognizer; this is NOT touch-swipe coverage.
  await page.mouse.move(width / 2, 400);
  await page.mouse.down();
  for (const y of [390, 380, 370, 350, 330, 310, 290]) {
    await page.mouse.move(width / 2, y);
    await page.waitForTimeout(16);
  }
  await page.mouse.up();
  const winner = 'Player 1 Wins!'; // Player 2 diverted upward hits the top wall first.
  await over(page, winner);
  await menu(page, true);
  return {touchTaps: true, pauseSurvivedMs: 1200, mouseDrag: 'up', touchSwipeVerified: false, winner, menuTap: true};
});

(async () => {
  fs.mkdirSync(out, {recursive: true});
  const wanted = process.env.QA_ONLY ? process.env.QA_ONLY.split(',') : null;
  const browser = await chromium.launch(launch);
  const results = [];
  try {
    for (const {name, run} of scenarios) {
      if (wanted && !wanted.includes(name)) continue;
      const context = await browser.newContext({viewport: {width, height: 800}, hasTouch: true, locale: 'en-US'});
      await context.tracing.start({screenshots: true, snapshots: true, sources: true});
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      const errors = [];
      page.on('pageerror', e => errors.push(`page: ${e}`));
      page.on('console', m => { if (m.type() === 'error') errors.push(`console: ${m.text()}`); });
      page.on('requestfailed', r => errors.push(`request: ${r.url()} ${r.failure()?.errorText}`));
      page.on('response', r => { if (r.status() >= 400) errors.push(`HTTP ${r.status()}: ${r.url()}`); });
      const entry = {name, ok: false, errors};
      try {
        await boot(page);
        entry.evidence = await run(page, context);
        entry.ok = true;
      } catch (e) { errors.push(String(e.stack || e)); }
      finally {
        try {
          fs.writeFileSync(path.join(out, `${name}.txt`), await page.locator('body').ariaSnapshot());
          await page.screenshot({path: path.join(out, `${name}.png`)});
          await context.tracing.stop({path: path.join(out, `${name}-trace.zip`)});
        } catch (e) { errors.push(`artifact: ${e}`); }
        if (errors.length) entry.ok = false;
        results.push(entry);
        fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify(results, null, 2));
        console.log(`${entry.ok ? 'PASS' : 'FAIL'} ${name}: ${errors.join(' | ')}`);
        await context.close();
      }
    }
  } finally { await browser.close(); }
  const saved = JSON.parse(fs.readFileSync(path.join(out, 'results.json')));
  const expected = wanted ? wanted.length : scenarios.length;
  const summary = {passed: saved.filter(r => r.ok).length, total: saved.length, expected};
  console.log(JSON.stringify(summary));
  assert.equal(new Set(saved.map(r => r.name)).size, saved.length);
  assert.equal(summary.passed, expected);
})().catch(e => { console.error(e); process.exitCode = 1; });
