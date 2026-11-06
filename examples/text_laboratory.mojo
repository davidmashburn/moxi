"""Executable text-laboratory states rendered from actual HarfBuzz outlines.

Run pixi run text-laboratory, then open dist/text-laboratory/index.html.
Optional arguments: primary, fallback, alternative Fontconfig family names.
"""
from std.sys import argv
from moxi import FontCollection, HarfBuzzParagraph, TextInputState, default_label_style, test_check


def panel(id: String, title: String, explanation: String, p: HarfBuzzParagraph,
          fonts: FontCollection, start: Int = 0, end: Int = 0) raises -> String:
    p.write_svg("dist/text-laboratory/" + id + ".svg", start, end)
    var shaped = p.shaped()
    return '<section id="' + id + '"><h2>' + title + '</h2><p>' + explanation + '</p><p class="metrics">Lines: ' + String(shaped.measurement.line_count) + ' · Width: ' + String(shaped.measurement.size.width) + ' · Font revision: ' + String(p.revision()) + ' · Builds: ' + String(fonts.builds()) + ' · Cache hits: ' + String(fonts.cache_hits()) + ' · Missing clusters: ' + String(p.missing_clusters()) + '</p><img alt="HarfBuzz paragraph outlines" src="' + id + '.svg"><p>Selection rectangles: ' + String(len(p.selection_rects(start, end))) + ' · Caret source offset: ' + String(p.caret_offset(end)) + '</p></section>'


def main() raises:
    var args = argv()
    var fonts = FontCollection()
    fonts.add_family(args[1] if len(args) > 1 else "Arial")
    fonts.add_family(args[2] if len(args) > 2 else "Arial Unicode MS")
    fonts.add_family(args[3] if len(args) > 3 else "Hiragino Sans")
    var style = default_label_style()
    style.font_size = 24
    var text = "Café • Ελληνικά • Кириллица • 世界 • שלום • مرحبا\nComposed: Å, 👩‍💻, 🇺🇸. Resize, change fallback, then select and edit."
    var wide = fonts.paragraph(text, style, 660)
    var body = panel("mixed", "1. Mixed scripts and composed clusters", "Primary glyphs are blue; fallback glyphs are purple. Missing coverage remains visible and counted.", wide, fonts)
    var narrow = fonts.paragraph(text, style, 330)
    test_check(narrow.shaped().measurement.line_count > wide.shaped().measurement.line_count)
    body += panel("wrap", "2. Resize to 330 units", "The adapter reshapes each line and keeps each composed fallback unit together.", narrow, fonts)
    fonts.move(2, 1)
    var fallback = fonts.paragraph(text, style, 330)
    test_check(fallback.revision() != narrow.revision())
    body += panel("fallback", "3. Change the fallback order", "The alternative fallback now precedes the original. The collection revision invalidates the layout cache.", fallback, fonts)
    var selected = fonts.paragraph(text, style, 330)
    test_check(fonts.cache_hits() == 1)
    body += panel("selection", "4. Selection and caret", "Selection geometry reuses the current paragraph: no new layout build. The range spans scripts and lines.", selected, fonts, 3, 42)
    var editing = TextInputState(text)
    editing.cursor = 5
    test_check(editing.delete_backward())
    test_check(editing.cursor == 3)
    var edited = fonts.paragraph(editing.text, style, 330)
    body += panel("edit", "5. Delete the composed e + acute", "One editor deletion removes the whole composed unit; changed text triggers a new paragraph build. The original snapshot is still valid.", edited, fonts, 3, 3)
    wide.write_svg("dist/text-laboratory/retained.svg")
    var html = """<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Moxi text laboratory</title>
<style>body{max-width:1050px;margin:40px auto;padding:0 24px;background:#f3f5f8;color:#193347;font:17px system-ui}h1{font-size:32px}nav{display:flex;gap:10px;flex-wrap:wrap}a{padding:10px 15px;background:#fff;border:1px solid #bbc9d6;border-radius:6px;color:#183e69;text-decoration:none}section{display:none;background:white;border:1px solid #c8d1dc;padding:24px;margin:24px 0;border-radius:10px}section.active{display:block}img{max-width:100%;height:auto;border:1px solid #d9e1e9}.metrics{font:14px ui-monospace,monospace;color:#485e71}footer{font-size:14px;color:#526779}</style>
<h1>Moxi text laboratory</h1><p>Actual HarfBuzz glyphs, FreeType outlines, collection policy and editor operations.</p>
<nav><a href="#mixed">1 Mixed scripts</a><a href="#wrap">2 Resize</a><a href="#fallback">3 Fallback</a><a href="#selection">4 Selection</a><a href="#edit">5 Edit</a></nav>
""" + body + """<footer>Greedy cluster wrapping; coarse script-run bidi. Fontconfig choices are host-dependent. This is an executable replay, not a browser text editor. No human IME or VoiceOver acceptance is asserted.</footer>
<script>function show(){let id=location.hash.slice(1)||'mixed';document.querySelectorAll('section').forEach(s=>s.classList.toggle('active',s.id===id));}addEventListener('hashchange',show);show();</script></html>"""
    with open("dist/text-laboratory/index.html", "w") as file:
        file.write(html)
    print("Text laboratory: dist/text-laboratory/index.html")
    print("Final builds:", fonts.builds(), "cache hits:", fonts.cache_hits(), "revision:", fonts.revision())
