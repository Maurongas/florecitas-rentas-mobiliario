"""Exporta los SVG de esta carpeta a PNG (2x) y a un PDF con todos los diagramas.
Requisitos: pip install playwright   (usa Edge/Chrome instalados)
Uso: python exportar_png.py
"""
from pathlib import Path
from playwright.sync_api import sync_playwright

AQUI = Path(__file__).resolve().parent
svgs = sorted(AQUI.glob("[1-5]_*.svg"))

with sync_playwright() as p:
    try:
        nav = p.chromium.launch(channel="msedge")
    except Exception:
        nav = p.chromium.launch(channel="chrome")
    pagina = nav.new_page(device_scale_factor=2)
    html = ["<html><body style='margin:0'>"]
    for svg in svgs:
        contenido = svg.read_text(encoding="utf-8")
        w = int(contenido.split('width="')[1].split('"')[0])
        h = int(contenido.split('height="')[1].split('"')[0])
        pagina.set_viewport_size({"width": w, "height": h})
        pagina.set_content(f"<html><body style='margin:0'>{contenido}</body></html>")
        png = svg.with_suffix(".png")
        pagina.screenshot(path=str(png), clip={"x": 0, "y": 0, "width": w, "height": h})
        print("exportado", png.name)
        html.append(f"<div style='page-break-after:always'>{contenido.replace(f'width=\"{w}\" height=\"{h}\"', 'width=\"100%\"')}</div>")
    html.append("</body></html>")
    pagina.set_content("".join(html))
    pagina.pdf(path=str(AQUI / "diagramas.pdf"), landscape=True, format="Letter", print_background=True,
               margin={"top": "10mm", "bottom": "10mm", "left": "10mm", "right": "10mm"})
    print("exportado diagramas.pdf")
    nav.close()
