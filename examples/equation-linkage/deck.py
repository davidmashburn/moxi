"""Make a navigable offline screenshot deck from check.cjs's evidence manifest."""
import argparse
import html
import json
from pathlib import Path


def build(directory):
    manifest = json.loads((directory / 'manifest.json').read_text())
    escape = lambda text: html.escape(str(text), quote=True)
    slides, thumbnails, rows = [], [], []
    for scenario in manifest['scenarios']:
        rows.append('<tr>' + ''.join(f'<td>{escape(scenario[key])}</td>'
                    for key in ['name', 'steps', 'expected', 'outcome']) + '</tr>')
        for image in scenario.get('screenshots', []):
            number = len(slides) + 1
            slides.append(f'''<figure id="slide-{number}" hidden><img src="{escape(image)}" alt="{escape(scenario['name'])}">
<figcaption><h2>{number}. {escape(scenario['name'])}</h2><p>{escape(scenario['steps'])}</p><p><b>Expected / checked:</b> {escape(scenario['expected'])}</p></figcaption></figure>''')
            thumbnails.append(f'<a href="#{number}"><img src="{escape(image)}" alt="{number}. {escape(scenario["name"])}"></a>')
    document = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>I21 · Living linkage · Evidence</title><style>
*{{box-sizing:border-box}}body{{margin:0;background:#152b28;color:#f6f4eb;font:16px/1.5 system-ui,sans-serif}}header,nav,figcaption,details,footer{{max-width:1200px;margin:auto;padding:16px 24px}}h1{{font:normal 2rem Georgia,serif;margin:0}}h2{{font-size:1.2rem}}a{{color:#b7ddc8}}button{{font:inherit;padding:8px 15px;margin-right:8px;cursor:pointer;border:1px solid #8bafa0;background:#e7eee4;color:#183c32;border-radius:4px}}figure{{margin:0}}figure>img{{display:block;max-width:100%;max-height:78vh;width:auto;margin:auto;object-fit:contain}}[hidden]{{display:none!important}}.thumbs{{display:grid;grid-template-columns:repeat(auto-fit,minmax(110px,1fr));gap:10px}}.thumbs img{{width:100%;height:110px;object-fit:contain;background:#f5f3ec}}.table{{overflow:auto}}table{{border-collapse:collapse;min-width:650px}}th,td{{padding:10px;border:1px solid #4b6c61;text-align:left;vertical-align:top}}code{{overflow-wrap:anywhere}}
</style><header><h1>I21 · Living linkage</h1><p>Exact equation text ⇄ structured numeric layout ⇄ one moving bar. Local offline Chrome replay.</p>
<p>Captured {escape(manifest['capturedAt'])} · Chrome {escape(manifest['browser'])} · wide 1280×900 / narrow 390×844 CSS pixels</p></header>
<nav><button id="prev">← Previous</button><button id="next">Next →</button><span id="position"></span> · <a href="#validation">Verification record</a></nav>
{''.join(slides)}<details><summary>All screenshots</summary><div class="thumbs">{''.join(thumbnails)}</div></details>
<details id="validation"><summary>Scenarios and environment</summary><p>Source revision <code>{escape(manifest['revision'])}</code>; public base <code>{escape(manifest['base'])}</code>. Exact source hashes, observed values, viewport per scenario and error records are in <a href="manifest.json">manifest.json</a>.</p>
<p>Source status at capture: <code>{escape(manifest['sourceState'] or 'clean')}</code>. Synthetic fixture; no account; browser context offline.</p>
<div class="table"><table><thead><tr><th>Scenario</th><th>Steps</th><th>Expected</th><th>Outcome</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>
<p>{escape('; '.join(manifest['limits']))}. Pointer-cancellation and window-blur events were dispatched by the replay; drag, key, text and button flows used normal browser input.</p></details>
<footer>Source, model and reproduction: <a href="../../../examples/equation-linkage/README.md">consumer README</a>. Screenshots establish appearance; assertions and manifest establish behavior.</footer>
<script>const slides=[...document.querySelectorAll('figure')];let index=0;
function show(n){{index=Math.max(0,Math.min(slides.length-1,n));slides.forEach((s,i)=>s.hidden=i!==index);document.querySelector('#position').textContent=(index+1)+' / '+slides.length;}}
function route(){{if(location.hash==='#validation'){{const d=document.querySelector('#validation');d.open=true;d.scrollIntoView();return;}}const n=Number(location.hash.slice(1));if(Number.isInteger(n)&&n>0)show(n-1);}}
document.querySelector('#prev').onclick=()=>location.hash=String(Math.max(1,index));document.querySelector('#next').onclick=()=>location.hash=String(Math.min(slides.length,index+2));
window.addEventListener('hashchange',route);document.addEventListener('keydown',e=>{{if(e.key==='ArrowLeft')document.querySelector('#prev').click();if(e.key==='ArrowRight')document.querySelector('#next').click();}});show(0);route();
</script></html>'''
    (directory / 'index.html').write_text(document)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    build(parser.parse_args().directory)
