// node tools/toggle_test.js <html path>   (NODE_PATH=$(npm root -g) if playwright is global)
// Opens the digest, clicks the Nano toggle through all views and reports JS errors. Expect: errors []
const { chromium } = require('playwright');
(async () => {
  const opts = require('fs').existsSync('/opt/pw-browsers/chromium') ? {executablePath:'/opt/pw-browsers/chromium'} : {};
  const b = await chromium.launch(opts);
  const p = await b.newPage({viewport:{width:1200,height:900}});
  const errs=[]; p.on('pageerror',e=>errs.push(e.message));
  await p.goto('file://'+require('path').resolve(process.argv[2]));
  for (const s of ['all','nano','nn']) {
    await p.click(`.segbtn[data-seg="${s}"]`);
    const vis = await p.$$eval('.seg-view', vs=>vs.filter(v=>!v.hidden).map(v=>v.dataset.seg));
    console.log('clicked',s,'visible',vis);
    if (vis.length!==1 || vis[0]!==s) errs.push('toggle '+s+' shows '+vis);
  }
  console.log('errors', errs);
  await b.close();
  process.exit(errs.length?1:0);
})();
