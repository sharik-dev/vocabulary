import puppeteer from 'puppeteer';
import fs from 'fs';

const DEV = {
  iphone: { w: 1320, h: 2868, frameW: 0.80, radius: 64, bezel: 14, head: 0.205 },
  ipad:   { w: 2064, h: 2752, frameW: 0.62, radius: 44, bezel: 18, head: 0.205 },
};

// Coloré / dynamique — terracotta gradients, big display headline.
const SLIDES = [
  { dev: 'iphone', src: 'assets/iphone/02_widgets.png',    out: 'iphone_1', t: ['Des widgets', 'chaque heure'],      s: "Écran d’accueil & écran verrouillé", g: 0 },
  { dev: 'iphone', src: 'assets/iphone/03_aujourdhui.png', out: 'iphone_2', t: ['Ton mot', 'du jour'],              s: 'Glisse pour en découvrir plus',     g: 1 },
  { dev: 'iphone', src: 'assets/iphone/04_progres.png',    out: 'iphone_3', t: ['Suis ta', 'progression'],          s: 'Du niveau A1 à B2',                 g: 2 },
  { dev: 'iphone', src: 'assets/iphone/01_onboarding.png', out: 'iphone_4', t: ["Apprends", "l’anglais"],           s: 'Un mot par jour, sans effort',      g: 3 },
  { dev: 'ipad',   src: 'assets/ipad/02_widgets.png',      out: 'ipad_1',   t: ['Des widgets', 'chaque heure'],      s: "Écran d’accueil & écran verrouillé", g: 0 },
  { dev: 'ipad',   src: 'assets/ipad/03_aujourdhui.png',   out: 'ipad_2',   t: ['Ton mot', 'du jour'],              s: 'Glisse pour en découvrir plus',     g: 1 },
  { dev: 'ipad',   src: 'assets/ipad/04_progres.png',      out: 'ipad_3',   t: ['Suis ta', 'progression'],          s: 'Du niveau A1 à B2',                 g: 2 },
  { dev: 'ipad',   src: 'assets/ipad/01_onboarding.png',   out: 'ipad_4',   t: ["Apprends", "l’anglais"],           s: 'Un mot par jour, sans effort',      g: 3 },
];

const GRADS = [
  'radial-gradient(120% 90% at 25% 8%, #D9774A 0%, #B85C38 42%, #8A3F22 100%)',
  'radial-gradient(120% 90% at 80% 6%, #C8693E 0%, #9A4827 45%, #6E2F18 100%)',
  'radial-gradient(120% 90% at 20% 6%, #CF7044 0%, #A8512E 45%, #7C3A20 100%)',
  'radial-gradient(120% 90% at 78% 8%, #DA7B4E 0%, #B2562F 45%, #84401F 100%)',
];

const STICK = ['✏️', '⭐️', '✨', '📚'];

function html(slide) {
  const d = DEV[slide.dev];
  const img = fs.readFileSync(slide.src).toString('base64');
  const headPx = Math.round(d.w * 0.082);
  const subPx = Math.round(d.w * 0.030);
  const padX = Math.round(d.w * 0.085);
  const stickerPx = Math.round(d.w * 0.06);
  return `<!doctype html><html><head><meta charset="utf-8">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Unbounded:wght@600;800&display=swap" rel="stylesheet">
  <style>
    *{margin:0;padding:0;box-sizing:border-box;}
    html,body{width:${d.w}px;height:${d.h}px;}
    .slide{position:relative;width:${d.w}px;height:${d.h}px;overflow:hidden;
      background:${GRADS[slide.g]};font-family:'Unbounded',sans-serif;}
    .grain{position:absolute;inset:0;opacity:.10;background-image:radial-gradient(rgba(255,255,255,.7) 1px,transparent 1px);background-size:7px 7px;}
    .head{position:relative;padding:${Math.round(d.h*0.058)}px ${padX}px 0;text-align:center;}
    .title{font-weight:800;color:#fff;font-size:${headPx}px;line-height:1.02;letter-spacing:-1px;
      text-shadow:0 4px 24px rgba(0,0,0,.18);}
    .title .hi{color:#FFE7C2;}
    .sub{margin-top:${Math.round(d.w*0.026)}px;font-weight:600;color:rgba(255,255,255,.86);
      font-size:${subPx}px;letter-spacing:.2px;}
    .stage{position:absolute;left:50%;transform:translateX(-50%);
      top:${Math.round(d.h*d.head)+Math.round(d.h*0.055)}px;}
    .phone{background:#141210;border-radius:${d.radius}px;padding:${d.bezel}px;
      box-shadow:0 50px 120px rgba(0,0,0,.45), 0 0 0 2px rgba(255,255,255,.06) inset;}
    .phone img{display:block;width:${Math.round(d.w*d.frameW)}px;height:auto;
      border-radius:${d.radius - d.bezel}px;}
    .st{position:absolute;filter:drop-shadow(0 6px 10px rgba(0,0,0,.25));font-size:${stickerPx}px;}
  </style></head>
  <body><div class="slide">
    <div class="grain"></div>
    <div class="head">
      <div class="title">${slide.t.map((l,i)=>i===1?`<span class="hi">${l}</span>`:l).join('<br>')}</div>
      <div class="sub">${slide.s}</div>
    </div>
    <div class="st" style="top:${Math.round(d.h*0.30)}px;left:${Math.round(d.w*0.06)}px;transform:rotate(-14deg)">${STICK[slide.g]}</div>
    <div class="st" style="top:${Math.round(d.h*0.72)}px;right:${Math.round(d.w*0.07)}px;left:auto;transform:rotate(12deg)">${STICK[(slide.g+2)%4]}</div>
    <div class="stage"><div class="phone"><img src="data:image/png;base64,${img}"></div></div>
  </div></body></html>`;
}

const browser = await puppeteer.launch({ args: ['--no-sandbox', '--font-render-hinting=none'] });
const page = await browser.newPage();
page.setDefaultTimeout(60000);
for (const s of SLIDES) {
  const d = DEV[s.dev];
  await page.setViewport({ width: d.w, height: d.h, deviceScaleFactor: 1 });
  await page.setContent(html(s), { waitUntil: 'load' });
  await page.evaluate(() => Promise.race([
    document.fonts.ready,
    new Promise(r => setTimeout(r, 6000)),
  ]));
  await new Promise(r => setTimeout(r, 500));
  const el = await page.$('.slide');
  await el.screenshot({ path: `export/${s.out}.png`, type: 'png' });
  console.log('rendered', s.out);
}
await browser.close();
