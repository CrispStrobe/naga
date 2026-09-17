// Usage: node scripts/qa/profile_web.cjs PORT OUTPUT.json [SAMPLES=3] [LIVE_MS=5000]
// QA_BROWSER_CHANNEL=chrome; QA_BUILD_LABEL describes the served build, NOT source HEAD.
// See docs/verification/performance.md. No production instrumentation/state injection.
'use strict';
const assert = require('node:assert/strict');
const {stableTarget} = require('./stable_target.cjs');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const VERSION = 1;
function summarizeGaps(gaps) {
  assert.ok(gaps.length && gaps.every(x => Number.isFinite(x) && x > 0), 'Need positive live RAF gaps');
  const sorted = [...gaps].sort((a, b) => a - b);
  const p = q => sorted[Math.ceil(q * sorted.length) - 1];
  return {count: gaps.length, durationMs: gaps.reduce((a, b) => a + b, 0), p50Ms: p(.5), p95Ms: p(.95), p99Ms: p(.99), maxMs: sorted.at(-1)};
}
function guardedGaps(segments, guardMs = 100) {
  // Exclude both transition boundaries. Never bridge separate game lives.
  return segments.flatMap(s => s.times.slice(1).flatMap((t, i) =>
    s.times[i] >= s.times[0] + guardMs && t <= s.times.at(-1) - guardMs ? [t - s.times[i]] : []));
}
function selfTest() {
  assert.deepEqual(summarizeGaps([10, 20, 30, 40]), {count: 4, durationMs: 100, p50Ms: 20, p95Ms: 40, p99Ms: 40, maxMs: 40});
  assert.throws(() => summarizeGaps([]));
  assert.throws(() => summarizeGaps([0]));
  assert.deepEqual(guardedGaps([{times:[0,100,120,150,250]}, {times:[1000,1100,1120,1150,1250]}]), [20,30,20,30]);
  assert.deepEqual(guardedGaps([{times:[0,16,32]}]), []);
  console.log('PASS nearest-rank percentiles, empty/invalid samples, live boundary guards and no cross-life gaps');
}
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
function command(cmd, args) { try { return execFileSync(cmd, args, {encoding:'utf8'}).trim(); } catch { return null; } }
async function fingerprints(url) {
  const result = {};
  for (const name of ['index.html','flutter_bootstrap.js','main.dart.mjs','main.dart.wasm','version.json']) {
    const r = await fetch(new URL(name, url));
    assert.equal(r.status, 200, `Missing ${name}`);
    const b = Buffer.from(await r.arrayBuffer());
    result[name] = {sha256:hash(b), bytes:b.length, lastModified:r.headers.get('last-modified')};
  }
  return result;
}
// This observer reads public Flutter accessibility DOM only. It does not change game state.
function installObserver() {
  performance.setResourceTimingBufferSize(2000);
  const p = window.__nagaProfile = {appReadyMs:null, recording:false, live:false, segments:[], transitions:[]};
  function refresh() {
    const text = document.body?.innerText || '';
    if (p.appReadyMs === null && text.includes('CLASSIC Retro phone legacy') && text.includes('Settings')) p.appReadyMs = performance.now();
    const live = /^SCORE:\s*\d+/m.test(text) && !/PLAY AGAIN|BACK TO MENU|PAUSED|THE SNAKE GAME/.test(text) && !/^OK$/m.test(text);
    if (live !== p.live) {
      p.live = live;
      if (p.recording) p.transitions.push({atMs:performance.now(), live, text});
    }
  }
  new MutationObserver(refresh).observe(document, {subtree:true, childList:true, characterData:true, attributes:true, attributeFilter:['aria-label']});
  let current = null;
  function frame(t) {
    if (p.recording && p.live && document.visibilityState === 'visible') {
      if (!current) { current = {times:[]}; p.segments.push(current); }
      current.times.push(t);
    } else current = null;
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}
async function main() {
  let playwrightPath;
  try { playwrightPath = require.resolve('playwright'); } catch { playwrightPath = require.resolve('/tmp/naga-qa/node_modules/playwright'); }
  const playwright = require(playwrightPath);
  const playwrightVersion = JSON.parse(fs.readFileSync(path.join(path.dirname(playwrightPath), 'package.json'), 'utf8')).version;
  const port = process.argv[2] || '8766';
  const out = path.resolve(process.argv[3] || 'docs/verification/performance-baseline.json');
  const samples = Number(process.argv[4] || 3), liveMs = Number(process.argv[5] || 5000);
  assert.ok(Number.isInteger(samples) && samples > 0 && liveMs >= 1000);
  const rates = (process.env.QA_CPU_RATES || '1,4').split(',').map(Number);
  const modes = [{name:'Classic',index:0},{name:'VS AI',index:18}].filter(m => !process.env.QA_MODE || process.env.QA_MODE === m.name);
  assert.ok(rates.length && rates.every(r => r === 1 || r === 4) && new Set(rates).size === rates.length && modes.length);
  assert.ok(!fs.existsSync(out), 'Refusing to overwrite raw results: choose a new output filename');
  const url = /^https?:/.test(port) ? port.replace(/\/?$/, '/') : `http://127.0.0.1:${port}/`;
  const channel = process.env.QA_BROWSER_CHANNEL || 'chrome';
  const build = await fingerprints(url);
  const browser = await playwright.chromium.launch({channel, headless:true});
  const report = {
    schemaVersion:VERSION, scriptSha256:hash(fs.readFileSync(__filename)), startedAt:new Date().toISOString(),
    url, buildLabel:process.env.QA_BUILD_LABEL || 'available served build; source revision unverified', build,
    sourceCheckoutContextOnly:{head:command('git',['rev-parse','HEAD']), dirty:command('git',['status','--porcelain']) !== ''},
    host:{platform:os.platform(), release:os.release(), arch:os.arch(), cpu:os.cpus()[0]?.model, logicalCPUs:os.cpus().length, totalMemoryBytes:os.totalmem(), model:command('sysctl',['-n','hw.model']), osVersion:command('sw_vers',['-productVersion']), loadAverageAtStart:os.loadavg()},
    runtime:{node:process.version, playwright:playwrightVersion, browser:browser.version(), channel, headless:true},
    configuration:{samplesPerScenario:samples, targetGuardedLiveMs:liveMs, viewport:{width:1280,height:800}, deviceScaleFactor:1, locale:'en-US', throttles:rates, modes:modes.map(m=>m.name), network:'loopback, unthrottled; fresh contexts, HTTP cache disabled, service workers blocked', input:'default settings; unattended forward movement; click PLAY AGAIN on death; no seeded randomness', boundaryGuardMs:100},
    definitions:{startup:'Navigation time origin to first observable accessible home menu after enabling Flutter semantics. Includes harness activation delay; not HTML load or exact first pixel.', raf:'Nearest-rank percentiles of page requestAnimationFrame timestamp gaps inside HUD-present, overlay-absent visible intervals, with 100ms trimmed at both ends per life. Not engine update/render, raster, presentation, or input latency.', cpu:'CDP Performance metrics are main-target cumulative counters; deltas span complete capture window INCLUDING polling/restarts, not active-game-only CPU. 4x is CDP CPU throttling, not phone simulation or whole-system slowdown.', heap:'JSHeapUsedSize/TotalSize are V8 JS heap, NOT total app memory. WASM linear memory, renderer/worker/GPU/native allocations are outside this accounting; WASM-GC accounting is implementation-dependent.', network:'CDP main-target completed encodedDataLength from navigation through sample end; includes protocol overhead, localhost server compression policy, and may omit worker traffic. ResourceTiming retained separately; zero transferSize may mean unavailable cross-origin timing, not free transfer.', audio:'Physical output/onset latency UNMEASURED. Asset fetch completion is not audible latency.', physicalDevice:'UNMEASURED: paired iPad Safari session creation previously blocked because Web Inspector was not enabled; this script makes no device claim.'},
    expectedSamples:rates.length*modes.length*samples, results:[], complete:false
  };
  fs.mkdirSync(path.dirname(out), {recursive:true});
  // Save every completed batch atomically: interruption retains all preceding raw samples.
  const save = () => { fs.writeFileSync(`${out}.tmp`, JSON.stringify(report,null,2)+'\n'); fs.renameSync(`${out}.tmp`,out); };
  save();
  try {
    const browserCDP = await browser.newBrowserCDPSession();
    try { report.runtime.systemInfo = await browserCDP.send('SystemInfo.getInfo'); } catch (e) { report.runtime.systemInfoError=String(e); }
    await browserCDP.detach();
    for (const rate of rates) for (const mode of modes) for (let n=1;n<=samples;n++) {
      const r = {mode:mode.name, cpuThrottle:rate, sample:n, startedAt:new Date().toISOString(), ok:false, errors:[], requests:[], restarts:0, phase:'context creation'};
      const watchdog = setTimeout(() => {
        r.ok=false;
        r.errors.push(`Sample watchdog exceeded 90s at phase: ${r.phase}; run aborted, no fabricated measurements`);
        r.finishedAt=new Date().toISOString();
        if(!report.results.includes(r))report.results.push(r);
        report.aborted=true;save();
        console.error(r.errors.at(-1));
        setTimeout(()=>process.exit(1),5000);
        browser.close().finally(()=>process.exit(1));
      },90000);
      const context = await browser.newContext({viewport:report.configuration.viewport, deviceScaleFactor:1, locale:'en-US', serviceWorkers:'block'});
      const page = await context.newPage();
      page.setDefaultTimeout(30000);
      const cdp = await context.newCDPSession(page);
      const requests = new Map();
      const bodyJobs = [];
      page.on('pageerror',e => r.errors.push(`page: ${e}`));
      page.on('console',m => {if(m.type()==='error')r.errors.push(`console: ${m.text()}`);});
      page.on('response',res => {
        if(res.status()>=400)r.errors.push(`HTTP ${res.status()}: ${res.url()}`);
        if(new URL(res.url()).pathname.endsWith('/main.dart.wasm')) bodyJobs.push(res.body().then(b => {r.loadedWasmSha256=hash(b);}).catch(e => r.errors.push(`WASM body: ${e}`)));
      });
      cdp.on('Network.requestWillBeSent',e => requests.set(e.requestId,{url:e.request.url,type:e.type,requestTimestamp:e.timestamp}));
      cdp.on('Network.responseReceived',e => Object.assign(requests.get(e.requestId)||{}, {status:e.response.status,mimeType:e.response.mimeType,fromDiskCache:e.response.fromDiskCache,fromServiceWorker:e.response.fromServiceWorker}));
      cdp.on('Network.loadingFinished',e => { const item=requests.get(e.requestId); if(item)Object.assign(item,{encodedDataLength:e.encodedDataLength,finishedTimestamp:e.timestamp}); });
      cdp.on('Network.loadingFailed',e => {r.errors.push(`network: ${e.errorText}`);});
      try {
        await cdp.send('Network.enable');
        await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
        await cdp.send('Performance.enable');
        r.phase='set CPU throttle';
        await cdp.send('Emulation.setCPUThrottlingRate',{rate});
        await page.addInitScript(installObserver);
        r.phase='navigation/startup';
        await page.goto(url,{waitUntil:'domcontentloaded'});
        await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
        await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
        await page.getByRole('button',{name:'CLASSIC Retro phone legacy',exact:true}).waitFor();
        await page.waitForFunction(()=>window.__nagaProfile.appReadyMs !== null);
        r.startup = await page.evaluate(()=>({appReadyMs:window.__nagaProfile.appReadyMs, navigation:performance.getEntriesByType('navigation')[0].toJSON()}));
        r.browser = await page.evaluate(()=>({userAgent:navigator.userAgent, hardwareConcurrency:navigator.hardwareConcurrency, deviceMemory:navigator.deviceMemory, crossOriginIsolated, devicePixelRatio, visibilityState:document.visibilityState}));
        assert.equal(r.browser.crossOriginIsolated,true);
        r.phase='launch/verify mode';
        await page.mouse.click(640,170);
        for(let k=0;k<=mode.index;k++){await page.keyboard.press('ArrowDown');await page.waitForTimeout(65);}
        await page.keyboard.press('Enter');
        await page.waitForFunction(()=>/^SCORE:\s*\d+/m.test(document.body.innerText));
        // The first HUD semantics precede completion of the route transition.
        await stableTarget(page.getByRole('button').nth(2));
        await page.mouse.click(1280-74,28);
        await page.getByRole('button',{name:'OK',exact:true}).waitFor();
        await page.getByText(mode.name,{exact:true}).waitFor();
        r.verifiedMode=mode.name;
        await page.getByRole('button',{name:'OK',exact:true}).click();
        const pause = page.getByRole('button',{name:'PAUSED Tap to resume',exact:true});
        if(await pause.count())await pause.click();
        await page.waitForFunction(()=>window.__nagaProfile.live || document.body.innerText.includes('PLAY AGAIN'));
        r.phase='active capture';
        r.captureStartMetrics = (await cdp.send('Performance.getMetrics')).metrics;
        await page.evaluate(()=>{const p=window.__nagaProfile;p.segments=[];p.transitions=[];p.recording=true;p.captureStartMs=performance.now();});
        const deadline = Date.now() + Math.max(60000, liveMs*10);
        let state;
        while(Date.now()<deadline) {
          await page.waitForTimeout(150);
          state = await page.evaluate(()=>({segments:window.__nagaProfile.segments, text:document.body.innerText}));
          const gaps = guardedGaps(state.segments);
          if(gaps.reduce((a,b)=>a+b,0)>=liveMs)break;
          if(state.text.includes('PLAY AGAIN')) {
            await page.getByRole('button',{name:'PLAY AGAIN',exact:true}).click();
            await page.getByRole('button',{name:'PLAY AGAIN',exact:true}).waitFor({state:'hidden'});
            r.restarts++;
          }
        }
        r.raw = await page.evaluate(()=>{const p=window.__nagaProfile;p.recording=false;p.captureEndMs=performance.now();return {captureStartMs:p.captureStartMs,captureEndMs:p.captureEndMs,segments:p.segments,transitions:p.transitions,finalText:document.body.innerText};});
        r.captureEndMetrics = (await cdp.send('Performance.getMetrics')).metrics;
        r.raf = summarizeGaps(guardedGaps(r.raw.segments));
        assert.ok(r.raf.durationMs>=liveMs,`Insufficient live duration: ${r.raf.durationMs}`);
        assert.ok(r.raf.count>=100,'Insufficient active RAF samples');
        const before=Object.fromEntries(r.captureStartMetrics.map(x=>[x.name,x.value]));
        r.captureMetricDeltas=Object.fromEntries(r.captureEndMetrics.filter(x=>/Duration$|Count$/.test(x.name)).map(x=>[x.name,x.value-(before[x.name]||0)]));
        r.resources = await page.evaluate(()=>performance.getEntriesByType('resource').map(x=>x.toJSON()));
        await Promise.all(bodyJobs);
        assert.equal(r.loadedWasmSha256,build['main.dart.wasm'].sha256,'Loaded Dart WASM differs from fingerprint or fallback was used');
        assert.ok(![...requests.values()].some(x=>/\/main\.dart\.js(?:\?|$)/.test(x.url)),'Unexpected JS fallback');
        r.ok = r.errors.length===0;
      } catch(e) {
        r.errors.push(String(e.stack||e));
        try { r.failureEvidence={text:await page.locator('body').innerText(), ariaSnapshot:await page.locator('body').ariaSnapshot(), observer:await page.evaluate(()=>window.__nagaProfile)}; } catch(evidenceError) {r.errors.push(`evidence: ${evidenceError}`);}
      }
      finally {
        r.requests=[...requests.values()];
        r.network={completedRequests:r.requests.filter(x=>x.finishedTimestamp).length,encodedTransferBytes:r.requests.reduce((a,x)=>a+(x.encodedDataLength||0),0)};
        r.finishedAt=new Date().toISOString();
        if(!report.results.includes(r))report.results.push(r);save();
        console.log(JSON.stringify({mode:r.mode,rate,sample:n,ok:r.ok,readyMs:r.startup?.appReadyMs,raf:r.raf,restarts:r.restarts,errors:r.errors}));
        r.phase='context close';
        await context.close();
        clearTimeout(watchdog);
      }
    }
    report.buildAtEnd=await fingerprints(url);
    report.buildUnchanged=JSON.stringify(report.buildAtEnd)===JSON.stringify(build);
    report.finishedAt=new Date().toISOString();
    report.host.loadAverageAtEnd=os.loadavg();
    const saved=JSON.parse(fs.readFileSync(out));
    report.counts={collected:saved.results.length, unique:new Set(saved.results.map(r=>`${r.mode}/${r.cpuThrottle}/${r.sample}`)).size,passed:saved.results.filter(r=>r.ok).length,expected:report.expectedSamples};
    report.summary=[];
    for(const rate of rates)for(const mode of modes.map(m=>m.name)) {
      const rows=saved.results.filter(r=>r.ok&&r.cpuThrottle===rate&&r.mode===mode);
      if(rows.length)report.summary.push({mode,cpuThrottle:rate,samples:rows.length,appReadyMs:rows.map(r=>r.startup.appReadyMs),pooledRaf:summarizeGaps(rows.flatMap(r=>guardedGaps(r.raw.segments))),encodedTransferBytes:rows.map(r=>r.network.encodedTransferBytes),jsHeapUsedBytesAtEnd:rows.map(r=>r.captureEndMetrics.find(m=>m.name==='JSHeapUsedSize')?.value),restarts:rows.map(r=>r.restarts)});
    }
    report.complete=report.counts.passed===report.expectedSamples && report.counts.unique===report.expectedSamples && report.buildUnchanged;
    save();
    console.log(JSON.stringify({output:out,complete:report.complete,counts:report.counts,summary:report.summary},null,2));
    if(!report.complete)process.exitCode=1;
  } finally {await browser.close();}
}
if(process.argv.includes('--self-test'))selfTest();
else main().catch(e=>{console.error(e);process.exitCode=1;});
