const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {stableTarget} = require('./stable_target.cjs');
(async () => {
  const browser = await chromium.launch({channel: process.env.QA_BROWSER_CHANNEL || 'chrome'});
  try {
    const page = await browser.newPage({viewport: {width: 800, height: 600}});
    await page.setContent('<button style="position:absolute;left:900px;top:20px;width:80px;height:40px">Pause</button>');
    await page.evaluate(() => {
      const b = document.querySelector('button');
      b.animate([{left:'900px'}, {left:'700px'}], {duration:300, fill:'forwards'});
    });
    const center = await stableTarget(page.getByRole('button'));
    assert.ok(center.x >= 739 && center.x <= 741, JSON.stringify(center));
    await page.setContent('<button style="position:absolute;left:900px">Outside</button>');
    await assert.rejects(stableTarget(page.getByRole('button'), 200), /never settled/);
    await page.setContent('<button style="position:absolute;left:20px;top:20px">Remove</button>');
    const pending = stableTarget(page.getByRole('button'));
    await page.waitForTimeout(20);
    await page.locator('button').evaluate(e => e.remove());
    await assert.rejects(pending, /never settled|detached/);
    console.log('PASS route animation, offscreen timeout, detached target');
  } finally { await browser.close(); }
})().catch(e => {console.error(e); process.exitCode = 1;});
