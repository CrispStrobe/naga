// Usage: node web_modes.cjs PORT OUTPUT_DIR [MODE_LIMIT]
// Launch smoke test: real accessibility semantics, not canvas/PNG existence.
const {chromium} = require('playwright');
const fs = require('fs');
const port = process.argv[2] || '8765';
const outdir = process.argv[3] || '/tmp/naga-qa/modes';
const modes = ['Classic','Arcade','Zen','Maze Hunter','Trail','Fangs','Venom',
 'Pit','Swarm','Rush','Snake II','ASCII','CGA','Nibbles','Stampede','Naga Dive',
 'Dungeon','Duel','VS AI','VS AI Split'];
const limit = Number(process.argv[4] || modes.length);
const width = Number(process.env.QA_WIDTH || 1280);
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g,'-');
fs.mkdirSync(outdir,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.QA_BROWSER_CHANNEL?{channel:process.env.QA_BROWSER_CHANNEL}:{})});
 const page=await browser.newPage({viewport:{width,height:800}});
 const errors=[];
 page.on('pageerror',e=>errors.push(`page: ${e}`));
 page.on('console',m=>{if(m.type()==='error')errors.push(`console: ${m.text()}`);});
 page.on('requestfailed',r=>errors.push(`request: ${r.url()} ${r.failure()?.errorText}`));
 page.on('response',r=>{if(r.status()>=400)errors.push(`HTTP ${r.status()}: ${r.url()}`);});
 const results=[];
 try {
  for(let i=0;i<limit;i++) {
   const name=modes[i], entry={mode:name,index:i,ok:false,errors:[]};
   errors.length=0;
   try {
    await page.goto(`http://127.0.0.1:${port}/`);
    await page.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:30000});
    await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    await page.getByRole('button',{name:'CLASSIC Retro phone legacy',exact:true}).waitFor();
    // Refocus the app, leaving accessibility enabled for assertions.
    await page.mouse.click(width/2,170);
    for(let k=0;k<=i;k++){await page.keyboard.press('ArrowDown');await page.waitForTimeout(65);}
    await page.waitForTimeout(180);
    const focused=await page.locator('body').ariaSnapshot();
    fs.writeFileSync(`${outdir}/${slug(name)}-menu.txt`,focused);
    await page.keyboard.press('Enter');
    await page.waitForFunction(()=>/^SCORE:\s*\d+/m.test(document.body.innerText),{},{timeout:10000});
    await page.waitForTimeout(350);
    entry.launchedText=await page.locator('body').innerText();
    if(entry.launchedText.includes('THE SNAKE GAME'))throw Error('Still on home screen');
    await page.screenshot({path:`${outdir}/${slug(name)}-screen.png`});
    // Scorebar info opens a dialog whose exact title proves mode identity.
    await page.mouse.click(width-74,28);
    await page.getByRole('button',{name:'OK',exact:true}).waitFor();
    await page.getByText(name,{exact:true}).waitFor();
    entry.verifiedMode=name;
    await page.keyboard.press('p');
    await page.getByRole('button',{name:'OK',exact:true}).click();
    await page.waitForTimeout(200);
    if(!(await page.getByRole('button',{name:'PLAY AGAIN',exact:true}).count())) {
     await page.mouse.click(width-36,28);
     await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).waitFor();
     await page.keyboard.press('p');
     await page.waitForTimeout(100);
     if(!(await page.getByRole('button',{name:'PAUSED Tap to resume',exact:true}).count()))throw Error('P bypassed pause overlay');
     await page.screenshot({path:`${outdir}/${slug(name)}-paused.png`});
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
    await page.screenshot({path:`${outdir}/${slug(name)}-played.png`});
    entry.finalText=await page.locator('body').innerText();
    entry.ok=true;
   }catch(e){entry.errors.push(String(e));entry.failureText=await page.locator('body').innerText();entry.failureAX=await page.locator('body').ariaSnapshot();await page.screenshot({path:`${outdir}/${slug(name)}-failure.png`});}
   entry.errors.push(...errors.splice(0));
   if(entry.errors.length)entry.ok=false;
   results.push(entry);
   fs.writeFileSync(`${outdir}/results.json`,JSON.stringify(results,null,2));
   console.log(`${entry.ok?'PASS':'FAIL'} ${name}: ${entry.errors.join(' | ')}`);
  }
 }finally{await browser.close();}
 const saved=JSON.parse(fs.readFileSync(`${outdir}/results.json`));
 const passed=saved.filter(x=>x.ok).length;
 const unique=new Set(saved.map(x=>x.mode)).size;
 console.log(JSON.stringify({passed,total:saved.length,unique,expected:limit},null,2));
 process.exitCode=passed===limit&&unique===limit?0:1;
})().catch(e=>{console.error(e);process.exitCode=1;});
