# KB_05 - TEMPLATE HTML BASE

## CSS base

:root {
  --black:#0A0A0A; --smoke:#141414; --charcoal:#1F1F1F; --steel:#2A2A2A;
  --mid:#3A3A3A; --ash:#6B6B6B; --cream:#F2EBDD; --paper:#E8DFC9;
  --white:#FFFFFF; --accent:#E94822; --neon:#E8FF00;
  --f-display:'Anton',Impact,sans-serif;
  --f-serif:'Instrument Serif',Georgia,serif;
  --f-body:'Inter',system-ui,sans-serif;
  --f-mono:'JetBrains Mono',monospace;
  --safe:80px;
}
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#0e0e10; font-family:var(--f-body); -webkit-font-smoothing:antialiased; }
.slide { width:1080px; height:1350px; position:relative; overflow:hidden; background:var(--black); color:var(--white); }
.ui-top { position:absolute; top:var(--safe); left:var(--safe); z-index:30; }
.ui-tag { font-family:var(--f-mono); font-size:14px; letter-spacing:0.18em; text-transform:uppercase; color:var(--cream); }
.ui-tag .star { color:var(--neon); }
.slide-num { position:absolute; bottom:60px; right:60px; z-index:35; font-family:var(--f-mono); font-size:14px; color:var(--ash); }
.ghost { position:absolute; font-family:var(--f-display); line-height:0.78; color:transparent; -webkit-text-stroke:3px var(--steel); pointer-events:none; z-index:5; opacity:0.85; }
.hero { font-family:var(--f-display); font-weight:400; line-height:0.92; letter-spacing:-0.015em; color:var(--white); text-transform:uppercase; text-align:left; }
.hero-large { font-size:220px; }
.hero-medium { font-size:150px; }
.hero-small { font-size:110px; }
.italic-accent { font-family:var(--f-serif); font-style:italic; font-weight:400; letter-spacing:-0.025em; text-align:left; color:var(--accent); }
.body-text { font-family:var(--f-body); font-weight:500; font-size:36px; line-height:1.4; color:var(--cream); }
.vignette { position:absolute; inset:0; z-index:10; pointer-events:none; background:linear-gradient(to bottom,rgba(0,0,0,0.55) 0%,transparent 22%,transparent 60%,rgba(0,0,0,0.85) 100%); }
.dl-bar { position:fixed; top:16px; left:50%; transform:translateX(-50%); background:rgba(10,10,10,0.95); border:1px solid var(--steel); padding:12px 20px; font-family:var(--f-mono); font-size:12px; color:var(--cream); cursor:pointer; z-index:9999; }

## Snippet Hero foto (S1)

<section class="slide" data-slide="01">
  <img src="data:image/jpeg;base64,{BASE64}" style="width:100%;height:100%;object-fit:cover;" />
  <div class="vignette"></div>
  <div class="ui-top"><span class="ui-tag"><span class="star">*</span> {TAG}</span></div>
  <div style="position:absolute;left:80px;right:80px;bottom:220px;z-index:25;">
    <div class="hero hero-large">{TITULO}</div>
    <div style="font-family:var(--f-display);font-size:58px;color:var(--cream);text-transform:uppercase;margin-top:28px;text-align:left;">{SUBTITLE}</div>
  </div>
  <div class="slide-num">01 / 10</div>
</section>

## Snippet Tesis accent (S3)

<section class="slide" data-slide="03" style="background:var(--accent);color:var(--black);">
  <div style="position:absolute;inset:0;display:flex;align-items:center;padding:0 80px;z-index:25;">
    <div class="hero" style="font-size:180px;color:var(--black);">{TESIS}</div>
  </div>
  <div class="slide-num" style="color:var(--black);opacity:0.6;">03 / 10</div>
</section>

## Snippet Regla ghost (S4-S7)

<section class="slide" data-slide="04">
  <div class="ghost" style="font-size:1500px;right:-180px;bottom:-420px;">01</div>
  <div style="position:absolute;left:80px;right:80px;top:160px;z-index:25;">
    <div class="hero hero-small">{REGLA_TITULO}</div>
    <p class="body-text" style="margin-top:48px;max-width:760px;">{BODY}</p>
    <div class="italic-accent" style="font-size:48px;margin-top:40px;">{ITALIC}</div>
  </div>
  <div class="slide-num">04 / 10</div>
</section>

## Snippet Insight cream (S8)

<section class="slide" data-slide="08" style="background:var(--cream);color:var(--black);">
  <div style="position:absolute;inset:0;display:flex;align-items:center;padding:0 80px;z-index:25;">
    <div>
      <div class="hero" style="font-size:120px;color:var(--black);">{INSIGHT}</div>
      <div style="font-family:var(--f-serif);font-style:italic;font-size:60px;color:var(--accent);margin-top:32px;">{ITALIC}</div>
    </div>
  </div>
  <div class="slide-num" style="color:var(--black);opacity:0.5;">08 / 10</div>
</section>

## Build script Python

import os, base64

KIT_ID = "kit_01_editorial"
with open(f"assets/kits_tipograficos/{KIT_ID}/fonts_embedded.css") as f:
    FONTS_CSS = f.read()

PALETA = {"black":"#0A0A0A","cream":"#F2EBDD","accent":"#E94822","neon":"#E8FF00"}

# Construir HTML con todas las secciones <section class="slide">
# Guardar en /mnt/user-data/outputs/{marca}-{tema}.html

## Render Playwright

from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--font-render-hinting=none"])
    ctx = browser.new_context(viewport={"width":1080,"height":1350}, device_scale_factor=2)
    page = ctx.new_page()
    page.goto(f"file://{html_path}")
    page.wait_for_load_state("networkidle")
    page.evaluate("document.fonts.ready")
    page.wait_for_timeout(3000)
    page.evaluate("document.querySelector('.dl-bar').style.display='none'")
    for i, slide in enumerate(page.locator('.slide').all()):
        slide.screenshot(path=f"slides/slide-{i+1:02d}.png")
    browser.close()

## Checklist

- Fuentes del kit elegido (no mezclar kits)
- Pesos correctos segun KB_02
- text-align:left en TODOS los heroes
- Contraste minimo 7:1
- Safe zones: nada critico a menos de 60px del borde
- Slide num presente y consistente
- Ghost number en slides numerados
- Vignette si hay foto
- Fuentes embebidas (HTML > 400KB)
- dl-bar oculto antes de capture Playwright
