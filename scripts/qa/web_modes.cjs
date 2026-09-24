// Usage: node web_modes.cjs PORT OUTPUT_DIR [MODE_LIMIT]
// Launch smoke test: real accessibility semantics, not canvas/PNG existence.
const {chromium} = require('playwright');
const {stableTarget} = require('./stable_target.cjs');
const {withTimeout, closeQuietly, WatchdogTimeout} = require('./watchdog.cjs');
const fs = require('fs');
const port = process.argv[2] || '8765';
const outdir = process.argv[3] || '/tmp/naga-qa/modes';
const modes = ['Daily','Classic','Arcade','Zen','Nightfall','Portals','Maze Hunter','Trail','Fangs','Venom',
 'Shed','Pit','Swarm','Rush','Snake II','ASCII','CGA','Nibbles','Stampede','Naga Dive',
 'Dungeon','Duel','VS AI','VS AI Split'];
const limit = Number(process.argv[4] || modes.length);
const width = Number(process.env.QA_WIDTH || 1280);
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g,'-');
fs.mkdirSync(outdir,{recursive:true});
const launchOptions={headless:true,...(process.env.QA_BROWSER_CHANNEL?{channel:process.env.QA_BROWSER_CHANNEL}:{})};
// Generous per mode: a healthy run takes 10-20s.
const modeTimeoutMs=Number(process.env.QA_MODE_TIMEOUT_MS||120000);
async function runMode(page, i, name, entry) {
    entry.step='load page';
    await page.goto(`http://127.0.0.1:${port}/`);
    entry.step='wait for app';
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:30000});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'CLASSIC Retro phone legacy',exact:true}).waitFor();
    // Refocus the app, leaving accessibility enabled for assertions.
    await page.mouse.click(width/2,170);
    for(let k=0;k<=i;k++){await page.keyboard.press('ArrowDown');await page.waitForTimeout(65);}
    await page.waitForTimeout(180);
    const focused=await page.locator('body').ariaSnapshot();
    fs.writeFileSync(`${outdir}/${slug(name)}-menu.txt`,focused);
    entry.step='open mode';
    await page.keyboard.press('Enter');
    entry.step='wait for game HUD';
    await page.waitForFunction(()=>/^SCORE:\s*\d+/m.test(document.body.innerText),{},{timeout:10000});
    entry.step='settle pause button';
    await stableTarget(page.getByRole('button').nth(2));
    entry.launchedText=await page.locator('body').innerText();
    if(entry.launchedText.includes('THE SNAKE GAME'))throw Error('Still on home screen');
    entry.step='screenshot';
    await page.screenshot({path:`${outdir}/${slug(name)}-screen.png`});
    // Scorebar info opens a dialog whose exact title proves mode identity.
    entry.step='open info dialog';
    await page.mouse.click(width-74,28);
    await page.getByRole('button',{name:'OK',exact:true}).waitFor();
    await page.getByText(name,{exact:true}).waitFor();
    entry.verifiedMode=name;
    await page.keyboard.press('p');
    await page.getByRole('button',{name:'OK',exact:true}).click();
    await page.waitForTimeout(200);
    if(!(await page.getByRole('button',{name:'PLAY AGAIN',exact:true}).count())) {
     await page.mouse.click(width-36,28);
     entry.step='pause overlay';
     await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).waitFor();
     await page.keyboard.press('p');
     await page.waitForTimeout(100);
     if(!(await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).count()))throw Error('P bypassed pause overlay');
     entry.step='screenshot';
     await page.screenshot({path:`${outdir}/${slug(name)}-paused.png`});
     entry.step='pause overlay';
     await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).click();
     await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).waitFor({state:'hidden'});
     entry.pauseResume=true;
    } else { entry.pauseResume='already game over'; }
    for(const key of ['ArrowUp','ArrowLeft','ArrowDown','ArrowRight']){
     await page.keyboard.press(key);await page.waitForTimeout(90);
    }
    await page.keyboard.press('Space');
    if(name==='Duel') for(const k of ['w','a','s','d'])await page.keyboard.press(k);
    await page.waitForTimeout(200);
    entry.step='screenshot';
    await page.screenshot({path:`${outdir}/${slug(name)}-played.png`});
    entry.finalText=await page.locator('body').innerText();
    entry.ok=true;
}

(async()=>{
 let browser=await chromium.launch(launchOptions);
 const results=[];
 try {
  for(let i=0;i<limit;i++) {
   const name=modes[i];
   let entry;
   for(let attempt=1;attempt<=2;attempt++) {
    entry={mode:name,index:i,attempt,ok:false,errors:[],step:'start'};
    const errors=[];
    const context=await browser.newContext({viewport:{width,height:800}});
    const page=await context.newPage();
    page.on('pageerror',e=>errors.push(`page: ${e}`));
    page.on('console',m=>{if(m.type()==='error')errors.push(`console: ${m.text()}`);});
    page.on('requestfailed',r=>errors.push(`request: ${r.url()} ${r.failure()?.errorText}`));
    page.on('response',r=>{if(r.status()>=400)errors.push(`HTTP ${r.status()}: ${r.url()}`);});
    let frozen=false;
    try {
     await withTimeout(runMode(page,i,name,entry),modeTimeoutMs,name);
    } catch(e) {
     frozen=e instanceof WatchdogTimeout;
     entry.errors.push(frozen?`${e.message} [last step: ${entry.step}]`:String(e));
     if(!frozen) try {
      entry.failureText=await withTimeout(page.locator('body').innerText(),10000,'innerText');
      entry.failureAX=await withTimeout(page.locator('body').ariaSnapshot(),10000,'ariaSnapshot');
      await withTimeout(page.screenshot({path:`${outdir}/${slug(name)}-failure.png`}),10000,'screenshot');
     } catch(_) {}
    }
    entry.errors.push(...errors);
    if(entry.errors.length)entry.ok=false;
    await closeQuietly(context);
    if(frozen) {
     // A hung renderer can wedge the whole browser; start a fresh one.
     try { await withTimeout(browser.close(),10000,'browser.close'); } catch(_) {}
     browser=await chromium.launch(launchOptions);
    }
    // Only a frozen page is retried: real assertion failures fail at once.
    if(entry.ok||!frozen||attempt===2)break;
    console.log(`RETRY ${name}: ${entry.errors.join(' | ')}`);
   }
   if(entry.ok&&entry.attempt>1)entry.flaky=true;
   results.push(entry);
   fs.writeFileSync(`${outdir}/results.json`,JSON.stringify(results,null,2));
   console.log(`${entry.ok?(entry.flaky?'FLAKY':'PASS'):'FAIL'} ${name}: ${entry.errors.join(' | ')}`);
  }
 }finally{ try { await withTimeout(browser.close(),10000,'browser.close'); } catch(_) {} }
 const saved=JSON.parse(fs.readFileSync(`${outdir}/results.json`));
 const passed=saved.filter(x=>x.ok).length;
 const flaky=saved.filter(x=>x.flaky).map(x=>x.mode);
 const unique=new Set(saved.map(x=>x.mode)).size;
 console.log(JSON.stringify({passed,total:saved.length,unique,expected:limit,flaky},null,2));
 process.exitCode=passed===limit&&unique===limit?0:1;
})().catch(e=>{console.error(e);process.exitCode=1;});
