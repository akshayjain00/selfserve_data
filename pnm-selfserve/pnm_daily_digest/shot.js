const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium'}).catch(()=>chromium.launch());
  const p = await b.newPage({viewport:{width:1200,height:900}});
  await p.goto('file://'+require('path').resolve(process.argv[2]||'pnm-leadership-digest.html'));
  await p.evaluate(()=>document.querySelectorAll('details').forEach(d=>d.open=true));
  const errs=[]; p.on('pageerror',e=>errs.push(e.message));
  await p.screenshot({path:'s_top.png', clip:{x:0,y:0,width:1200,height:1400}});
  for (const id of ['city-trend','alloc-completion']) {
    const el = await p.$('#'+id); await el.screenshot({path:'s_'+id+'.png'});
  }
  console.log('errors', errs);
  await b.close();
})();
