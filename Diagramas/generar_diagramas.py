"""
Generador de los diagramas del modelo de datos en 5 notaciones (Actividad 4):
  1. Crow's Foot (pata de gallo)           -> 1_crows_foot.svg
  2. Classic / Chen                        -> 2_chen_clasica.svg
  3. Connect to Columns (relacional)       -> 3_connect_to_columns.svg
  4. UML (diagrama de clases)              -> 4_uml.svg
  5. IDEF1X                                -> 5_idef1x.svg

Todas las notaciones se generan a partir de la MISMA definición del modelo
(ENTIDADES y RELACIONES), por eso son coherentes entre sí.
Los SVG son editables (Inkscape, draw.io, navegador) y se exportan a PNG con
exportar_png.py.

Uso:  python generar_diagramas.py
"""
from pathlib import Path
from html import escape

SALIDA = Path(__file__).resolve().parent
FUENTE = "Segoe UI, Helvetica, Arial, sans-serif"

# ---------------------------------------------------------------------------
# MODELO (único origen de verdad)
# tipo: fuerte | asociativa | debil
# atributos: (nombre, tipo SQL, claves)  claves: PK, FK, UQ combinables
# ---------------------------------------------------------------------------
ENTIDADES = {
    "CATEGORIA": ("fuerte", [("id_categoria", "INT", "PK"), ("nombre", "VARCHAR(40)", "UQ"),
                             ("descripcion", "VARCHAR(150)", "")]),
    "CLIENTE": ("fuerte", [("id_cliente", "INT", "PK"), ("nombre", "VARCHAR(60)", ""),
                           ("apellidos", "VARCHAR(80)", ""), ("telefono", "VARCHAR(15)", ""),
                           ("correo", "VARCHAR(100)", "UQ"), ("direccion", "VARCHAR(150)", "")]),
    "EMPLEADO": ("fuerte", [("id_empleado", "INT", "PK"), ("nombre", "VARCHAR(100)", ""),
                            ("usuario", "VARCHAR(30)", "UQ"), ("contrasena_hash", "VARCHAR(255)", ""),
                            ("rol", "VARCHAR(15)", ""), ("activo", "BOOLEAN", "")]),
    "ARTICULO": ("fuerte", [("id_articulo", "INT", "PK"), ("id_categoria", "INT", "FK"),
                            ("nombre", "VARCHAR(80)", ""), ("descripcion", "VARCHAR(200)", ""),
                            ("cantidad_total", "INT", ""), ("precio_dia", "DECIMAL(10,2)", ""),
                            ("activo", "BOOLEAN", "")]),
    "RESERVACION": ("fuerte", [("id_reservacion", "INT", "PK"), ("id_cliente", "INT", "FK"),
                               ("fecha_registro", "DATETIME", ""), ("fecha_inicio", "DATE", ""),
                               ("fecha_fin", "DATE", ""), ("lugar_evento", "VARCHAR(150)", ""),
                               ("estado", "VARCHAR(15)", "")]),
    "DETALLE_RESERVACION": ("asociativa", [("id_reservacion", "INT", "PK,FK"), ("id_articulo", "INT", "PK,FK"),
                                           ("cantidad", "INT", ""), ("precio_unitario", "DECIMAL(10,2)", "")]),
    "ENTREGA": ("fuerte", [("id_entrega", "INT", "PK"), ("id_reservacion", "INT", "FK,UQ"),
                           ("id_empleado", "INT", "FK"), ("fecha_hora", "DATETIME", ""),
                           ("observaciones", "VARCHAR(200)", "")]),
    "DEVOLUCION": ("fuerte", [("id_devolucion", "INT", "PK"), ("id_reservacion", "INT", "FK,UQ"),
                              ("id_empleado", "INT", "FK"), ("fecha_hora", "DATETIME", ""),
                              ("observaciones", "VARCHAR(200)", "")]),
    "DETALLE_DEVOLUCION": ("debil", [("id_devolucion", "INT", "PK,FK"), ("id_articulo", "INT", "PK,FK"),
                                     ("cantidad_devuelta", "INT", ""), ("cantidad_danada", "INT", "")]),
}

# (id, padre, hijo, verbo, min_hijo, max_hijo, identificante, fk_en_hijo)
#   min_hijo 0/1 y max_hijo "1"/"N": participación y cardinalidad del lado hijo.
RELACIONES = [
    ("R1", "CLIENTE", "RESERVACION", "realiza", 0, "N", False, "id_cliente"),
    ("R2", "CATEGORIA", "ARTICULO", "clasifica", 0, "N", False, "id_categoria"),
    ("R3a", "RESERVACION", "DETALLE_RESERVACION", "incluye", 1, "N", True, "id_reservacion"),
    ("R3b", "ARTICULO", "DETALLE_RESERVACION", "se renta en", 0, "N", True, "id_articulo"),
    ("R4", "RESERVACION", "ENTREGA", "se entrega", 0, "1", False, "id_reservacion"),
    ("R5", "RESERVACION", "DEVOLUCION", "se devuelve", 0, "1", False, "id_reservacion"),
    ("R6", "EMPLEADO", "ENTREGA", "registra", 0, "N", False, "id_empleado"),
    ("R7", "EMPLEADO", "DEVOLUCION", "recibe", 0, "N", False, "id_empleado"),
    ("R8", "DEVOLUCION", "DETALLE_DEVOLUCION", "detalla", 1, "N", True, "id_devolucion"),
    ("R9", "ARTICULO", "DETALLE_DEVOLUCION", "se revisa en", 0, "N", True, "id_articulo"),
]

COLOR = {"fuerte": "#9D174D", "asociativa": "#A16207", "debil": "#6D28D9"}
TINTA = "#2A1424"
GRIS = "#6B5866"
LINEA = "#3F2A37"

# Posición (esquina superior izquierda) para las notaciones con cajas
POS = {
    "CATEGORIA": (60, 60), "CLIENTE": (620, 40), "EMPLEADO": (1560, 300),
    "ARTICULO": (60, 330), "RESERVACION": (620, 330),
    "ENTREGA": (1120, 190), "DEVOLUCION": (1120, 480),
    "DETALLE_RESERVACION": (340, 690), "DETALLE_DEVOLUCION": (1120, 800),
}
ANCHO = 260
CAB = 34
FILA = 22


class Svg:
    def __init__(self, w, h, titulo):
        self.w, self.h = w, h
        self.p = []
        self.titulo = titulo

    def add(self, s):
        self.p.append(s)

    def text(self, x, y, s, size=13, weight="normal", fill=TINTA, anchor="start", style="", deco=""):
        extra = f' font-style="{style}"' if style else ""
        extra += f' text-decoration="{deco}"' if deco else ""
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FUENTE}" font-size="{size}" font-weight="{weight}" '
                 f'fill="{fill}" text-anchor="{anchor}"{extra}>{escape(s)}</text>')

    def line(self, pts, dash=False, width=1.6, color=LINEA):
        d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        da = ' stroke-dasharray="7 5"' if dash else ""
        self.add(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{width}"{da} stroke-linejoin="round"/>')

    def save(self, nombre):
        cuerpo = "\n".join(self.p)
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
               f'viewBox="0 0 {self.w} {self.h}">\n<title>{escape(self.titulo)}</title>\n'
               f'<rect width="100%" height="100%" fill="#FFFFFF"/>\n{cuerpo}\n</svg>\n')
        (SALIDA / nombre).write_text(svg, encoding="utf-8")
        print("generado", nombre)


def caja(nombre, filas_extra=0):
    x, y = POS[nombre]
    n = len(ENTIDADES[nombre][1]) + filas_extra
    return x, y, ANCHO, CAB + n * FILA + 10


def ancla(nombre, lado, f, filas_extra=0):
    x, y, w, h = caja(nombre, filas_extra)
    return {"T": (x + w * f, y), "B": (x + w * f, y + h), "L": (x, y + h * f), "R": (x + w, y + h * f)}[lado]


# Rutas ortogonales para las notaciones con cajas (mismo trazo en 1, 4 y 5)
RUTAS = {
    "R2": (("B", .5), ("T", .5)),
    "R1": (("B", .5), ("T", .5)),
    "R4": (("R", .3), ("L", .5)),
    "R5": (("R", .7), ("L", .5)),
    "R6": (("L", .3), ("R", .5)),
    "R7": (("L", .7), ("R", .5)),
    "R8": (("B", .5), ("T", .5)),
    "R3a": (("B", .3), ("T", .7)),
    "R3b": (("B", .7), ("T", .3)),
    "R9": (("B", .2), ("L", .5)),
}


def ruta(rel, extra=0):
    rid, padre, hijo = rel[0], rel[1], rel[2]
    (lp, fp), (lh, fh) = RUTAS[rid]
    a = ancla(padre, lp, fp, extra)
    b = ancla(hijo, lh, fh, extra)
    if lp in "TB" and lh in "TB":
        my = (a[1] + b[1]) / 2 if rid not in ("R3a", "R3b") else 640
        pts = [a, (a[0], my), (b[0], my), b]
    elif lp in "LR" and lh in "LR":
        mx = (a[0] + b[0]) / 2
        pts = [a, (mx, a[1]), (mx, b[1]), b]
    else:  # vertical y luego horizontal
        pts = [a, (a[0], b[1]), b]
    return pts, lp, lh


def unitario(p, q):
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = (dx * dx + dy * dy) ** .5 or 1
    return dx / n, dy / n


def etiqueta_media(svg, pts, texto, dy=-6):
    # segmento más largo
    if len(pts) == 4:
        mejor = 1
    else:
        mejor = max(range(len(pts) - 1), key=lambda i: abs(pts[i + 1][0] - pts[i][0]) + abs(pts[i + 1][1] - pts[i][1]))
    (x1, y1), (x2, y2) = pts[mejor], pts[mejor + 1]
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    w = len(texto) * 6.6 + 10
    svg.add(f'<rect x="{mx - w / 2:.1f}" y="{my - 9 + dy + 3:.1f}" width="{w:.1f}" height="16" rx="4" fill="#FFFFFF" opacity=".92"/>')
    svg.text(mx, my + dy + 7, texto, size=11.5, fill=GRIS, anchor="middle", style="italic")


# ----------------------------- Crow's Foot ---------------------------------
def pata(svg, extremo, siguiente, minimo, maximo):
    """Dibuja el símbolo de pata de gallo en 'extremo' (punto sobre la caja)."""
    ux, uy = unitario(extremo, siguiente)       # hacia afuera de la caja
    px, py = -uy, ux                            # perpendicular
    ex, ey = extremo

    def barra(d):
        cx, cy = ex + ux * d, ey + uy * d
        svg.line([(cx + px * 8, cy + py * 8), (cx - px * 8, cy - py * 8)], width=1.8)

    def circulo(d):
        cx, cy = ex + ux * d, ey + uy * d
        svg.add(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="5.5" fill="#FFF" stroke="{LINEA}" stroke-width="1.6"/>')

    if maximo == "N":
        base = (ex + ux * 14, ey + uy * 14)
        svg.line([(ex + px * 9, ey + py * 9), base, (ex - px * 9, ey - py * 9)], width=1.6)
        svg.line([(ex, ey), base], width=1.6)
        barra(20) if minimo == 1 else circulo(24)
    else:
        barra(10)
        barra(17) if minimo == 1 else circulo(22)


def caja_er(svg, nombre, columnas=True, tipos=False, idef=False, uml=False):
    tipo, atributos = ENTIDADES[nombre]
    x, y, w, h = caja(nombre)
    color = COLOR[tipo]
    svg.add(f'<rect x="{x+3}" y="{y+4}" width="{w}" height="{h}" rx="8" fill="#000" opacity=".06"/>')
    svg.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#FFF" stroke="{color}" stroke-width="1.6"/>')
    svg.add(f'<path d="M{x},{y+CAB} v-{CAB-8} a8,8 0 0 1 8,-8 h{w-16} a8,8 0 0 1 8,8 v{CAB-8} z" fill="{color}"/>')
    svg.text(x + w / 2, y + 22, nombre, size=13.5, weight="bold", fill="#FFF", anchor="middle")
    for i, (a, t, k) in enumerate(atributos):
        yy = y + CAB + 17 + i * FILA
        if "PK" in k:
            svg.add(f'<rect x="{x+1}" y="{yy-14}" width="{w-2}" height="{FILA}" fill="{color}" opacity=".07"/>')
        svg.text(x + 10, yy, k.replace(",", ", "), size=10.5, weight="bold", fill=color)
        svg.text(x + 62, yy, a, size=12.5, weight="bold" if "PK" in k else "normal",
                 deco="underline" if "PK" in k else "")
        if tipos:
            svg.text(x + w - 10, yy, t, size=10.5, fill=GRIS, anchor="end")


def leyenda_cf(svg, x, y):
    svg.add(f'<rect x="{x}" y="{y}" width="330" height="150" rx="8" fill="#FBF7FA" stroke="#EDE1E8"/>')
    svg.text(x + 14, y + 22, "Simbología", size=13, weight="bold")
    items = [((1, "1"), "exactamente uno (obligatorio)"), ((0, "1"), "cero o uno"),
             ((0, "N"), "cero o muchos"), ((1, "N"), "uno o muchos")]
    for i, ((mn, mx), t) in enumerate(items):
        yy = y + 48 + i * 26
        svg.line([(x + 18, yy), (x + 80, yy)])
        pata(svg, (x + 80, yy), (x + 18, yy), mn, mx)
        svg.text(x + 96, yy + 4, t, size=12)


def crows_foot():
    s = Svg(1860, 1150, "DER Crow's Foot - Rentas de mobiliario")
    s.text(40, 30, "Diagrama Entidad-Relación · notación Crow's Foot", size=20, weight="bold")
    for rel in RELACIONES:
        pts, _, _ = ruta(rel)
        s.line(pts, dash=not rel[6])
        etiqueta_media(s, pts, rel[3])
    for n in ENTIDADES:
        caja_er(s, n, tipos=True)
    for rel in RELACIONES:
        pts, _, _ = ruta(rel)
        pata(s, pts[0], pts[1], 1, "1")                     # lado padre: exactamente uno
        pata(s, pts[-1], pts[-2], rel[4], rel[5])            # lado hijo
    leyenda_cf(s, 40, 975)
    s.text(400, 1020, "Línea continua = relación identificante (la FK forma parte de la PK del hijo).", size=12, fill=GRIS)
    s.text(400, 1045, "Línea punteada = relación no identificante.", size=12, fill=GRIS)
    s.text(400, 1070, "Encabezado guinda: entidad fuerte · dorado: asociativa · morado: débil.", size=12, fill=GRIS)
    s.save("1_crows_foot.svg")


# ----------------------------- Connect to Columns --------------------------
def fila_y(nombre, columna):
    x, y, w, h = caja(nombre)
    for i, (a, _, _) in enumerate(ENTIDADES[nombre][1]):
        if a == columna:
            return y + CAB + 13 + i * FILA
    raise KeyError(columna)


def connect_to_columns():
    s = Svg(1860, 1040, "DER Connect to Columns - Rentas de mobiliario")
    s.text(40, 30, "Modelo relacional · notación Connect to Columns (FK → PK)", size=20, weight="bold")
    X = {n: (POS[n][0], POS[n][0] + ANCHO) for n in POS}
    rutas = {}
    for rid, padre, hijo, verbo, mn, mx, ident, fk in RELACIONES:
        pk = ENTIDADES[padre][1][0][0]
        yp, yh = fila_y(padre, pk), fila_y(hijo, fk)
        if rid == "R1":
            pts = [(X[padre][0], yp), (590, yp), (590, yh), (X[hijo][0], yh)]
        elif rid == "R2":
            pts = [(X[padre][0], yp), (38, yp), (38, yh), (X[hijo][0], yh)]
        elif rid == "R3b":
            pts = [(X[padre][1], yp), (330, yp), (330, yh), (X[hijo][0], yh)]
        elif rid == "R3a":
            pts = [(X[padre][0], yp + 0), (606, yp), (606, yh), (X[hijo][1], yh)]
        elif rid in ("R4", "R5"):
            mx_ = 1000 if rid == "R4" else 1030
            pts = [(X[padre][1], yp), (mx_, yp), (mx_, yh), (X[hijo][0], yh)]
        elif rid in ("R6", "R7"):
            mx_ = 1470 if rid == "R6" else 1500
            pts = [(X[padre][0], yp), (mx_, yp), (mx_, yh), (X[hijo][1], yh)]
        elif rid == "R8":
            pts = [(X[padre][0], yp), (1090, yp), (1090, yh), (X[hijo][0], yh)]
        else:  # R9
            pts = [(X[padre][0], yp), (22, yp), (22, 985), (1060, 985), (1060, yh), (X[hijo][0], yh)]
        rutas[rid] = pts
        s.line(pts, dash=not ident)
    for n in ENTIDADES:
        caja_er(s, n, tipos=True)
    for rid, padre, hijo, verbo, mn, mx, ident, fk in RELACIONES:
        pts = rutas[rid]
        pata(s, pts[0], pts[1], 1, "1")
        pata(s, pts[-1], pts[-2], mn, mx)
    s.text(620, 1022, "Cada línea une la columna FK del hijo con la PK del padre. Continua = identificante; punteada = no identificante.",
           size=12, fill=GRIS)
    s.save("3_connect_to_columns.svg")


# ----------------------------- UML -----------------------------------------
def uml():
    s = Svg(1860, 1010, "Diagrama de clases UML - Rentas de mobiliario")
    s.text(40, 30, "Modelo de datos · notación UML (diagrama de clases)", size=20, weight="bold")
    estereo = {"asociativa": "«asociativa»", "debil": "«débil»", "fuerte": "«entidad»"}
    for rel in RELACIONES:
        pts, _, _ = ruta(rel, 1)
        s.line(pts)
        etiqueta_media(s, pts, rel[3])
    for n, (tipo, atributos) in ENTIDADES.items():
        x, y, w, h = caja(n, 1)
        color = COLOR[tipo]
        s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#FFF" stroke="{color}" stroke-width="1.6"/>')
        s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{CAB + 14}" fill="{color}" opacity=".12"/>')
        s.text(x + w / 2, y + 16, estereo[tipo], size=10.5, fill=color, anchor="middle")
        s.text(x + w / 2, y + 34, n.title().replace("_", ""), size=13.5, weight="bold", anchor="middle")
        s.line([(x, y + CAB + 14), (x + w, y + CAB + 14)], color=color, width=1.2)
        for i, (a, t, k) in enumerate(atributos):
            yy = y + CAB + 32 + i * FILA
            tipo_uml = {"INT": "int", "DATE": "Date", "DATETIME": "DateTime", "BOOLEAN": "bool"}.get(t, "decimal" if "DECIMAL" in t else "string")
            marca = " {" + k.replace(",", ", ") + "}" if k else ""
            s.text(x + 10, yy, f"- {a}: {tipo_uml}{marca}", size=11.5, deco="underline" if "PK" in k else "")
    for rel in RELACIONES:
        pts, _, _ = ruta(rel, 1)
        rid = rel[0]
        # multiplicidades
        def mult(p, q, t, lado):
            ux, uy = unitario(p, q)
            if uy == 0:   # sale por un lado: el texto va arriba de la línea, fuera de la caja
                s.text(p[0] + ux * 10, p[1] - 9, t, size=12, weight="bold", fill="#1D4ED8", anchor="start" if ux > 0 else "end")
            else:         # sale por arriba/abajo: a la derecha de la línea
                s.text(p[0] + 7, p[1] + uy * 18 + (4 if uy > 0 else 0), t, size=12, weight="bold", fill="#1D4ED8")
        mult(pts[0], pts[1], "1", "p")
        mult(pts[-1], pts[-2], {(0, "N"): "0..*", (1, "N"): "1..*", (0, "1"): "0..1"}[(rel[4], rel[5])], "h")
        if rid == "R8":  # composición: la parte no existe sin el todo
            ex, ey = pts[0]
            ux, uy = unitario(pts[0], pts[1])
            px, py = -uy, ux
            d = [(ex, ey), (ex + ux * 10 + px * 7, ey + uy * 10 + py * 7), (ex + ux * 20, ey + uy * 20),
                 (ex + ux * 10 - px * 7, ey + uy * 10 - py * 7)]
            s.add('<polygon points="' + " ".join(f"{a:.1f},{b:.1f}" for a, b in d) + f'" fill="{LINEA}"/>')
    s.text(40, 960, "Multiplicidades en azul. Rombo relleno = composición (DetalleDevolucion no existe sin su Devolucion).", size=12, fill=GRIS)
    s.text(40, 980, "DetalleReservacion es la clase que resuelve la asociación N:M entre Reservacion y Articulo (guarda cantidad y precio).", size=12, fill=GRIS)
    s.save("4_uml.svg")


# ----------------------------- IDEF1X --------------------------------------
def idef1x():
    s = Svg(1860, 1010, "Modelo IDEF1X - Rentas de mobiliario")
    s.text(40, 30, "Modelo de datos · notación IDEF1X", size=20, weight="bold")
    dependientes = {n for n, (t, _) in ENTIDADES.items() if t != "fuerte"}
    for rel in RELACIONES:
        pts, _, _ = ruta(rel)
        s.line(pts, dash=not rel[6])
        etiqueta_media(s, pts, rel[3])
    for n, (tipo, atributos) in ENTIDADES.items():
        x, y, w, h = caja(n)
        y2 = y + 6
        pk = [a for a in atributos if "PK" in a[2]]
        resto = [a for a in atributos if "PK" not in a[2]]
        rx = 14 if n in dependientes else 0
        etq_w = len(n) * 8.2 + 8
        s.add(f'<rect x="{x - 2}" y="{y - 19}" width="{etq_w:.0f}" height="20" rx="4" fill="#FFF"/>')
        s.text(x + 2, y - 4, f"{n}", size=12.5, weight="bold", fill=COLOR[tipo])
        s.add(f'<rect x="{x}" y="{y2}" width="{w}" height="{h - 6}" rx="{rx}" fill="#FFF" stroke="{TINTA}" stroke-width="1.6"/>')
        yline = y2 + 10 + len(pk) * FILA
        s.line([(x, yline), (x + w, yline)], color=TINTA, width=1.4)
        for i, (a, t, k) in enumerate(pk):
            s.text(x + 12, y2 + 22 + i * FILA, a + (" (FK)" if "FK" in k else ""), size=12.5, weight="bold")
        for i, (a, t, k) in enumerate(resto):
            marca = ""
            if "FK" in k:
                marca += " (FK)"
            if "UQ" in k:
                marca += " (AK1)"
            s.text(x + 12, yline + 20 + i * FILA, a + marca, size=12.5)
    for rel in RELACIONES:
        pts, _, _ = ruta(rel)
        ex, ey = pts[-1]
        ux, uy = unitario(pts[-1], pts[-2])
        s.add(f'<circle cx="{ex + ux * 5:.1f}" cy="{ey + uy * 5:.1f}" r="5" fill="{TINTA}"/>')
        letra = {(1, "N"): "P", (0, "1"): "Z", (0, "N"): ""}[(rel[4], rel[5])]
        if letra:
            s.text(ex + ux * 14 + (10 if uy else 0), ey + uy * 14 + (-8 if ux else 4), letra, size=13, weight="bold", fill="#1D4ED8")
    s.text(40, 940, "Caja con esquinas rectas = entidad independiente; esquinas redondeadas = entidad dependiente (su PK incluye una FK).", size=12, fill=GRIS)
    s.text(40, 960, "Sobre la línea horizontal de cada caja va la llave primaria. Línea continua = identificante; punteada = no identificante.", size=12, fill=GRIS)
    s.text(40, 980, "Punto en el extremo hijo: cero o muchos · P = uno o muchos · Z = cero o uno · (AK1) = llave alterna (UNIQUE).", size=12, fill=GRIS)
    s.save("5_idef1x.svg")


# ----------------------------- Chen (clásica) ------------------------------
CHEN_POS = {
    "CATEGORIA": (260, 200), "CLIENTE": (840, 200), "EMPLEADO": (1720, 570),
    "ARTICULO": (260, 610), "RESERVACION": (840, 610), "ENTREGA": (1300, 380),
    "DEVOLUCION": (1300, 810), "DETALLE_RESERVACION": (560, 980), "DETALLE_DEVOLUCION": (1300, 1160),
}
# atributos conceptuales (sin FK). Cada uno con su ángulo (grados; 0 = derecha, 90 = abajo) y radio.
CHEN_ATR = {
    "CATEGORIA": ([("id_categoria", 160), ("nombre", 270), ("descripcion", 20)], 120),
    "CLIENTE": ([("id_cliente", 150), ("nombre", 190), ("apellidos", 235), ("telefono", 305), ("correo", 350), ("direccion", 30)], 135),
    "EMPLEADO": ([("id_empleado", -95), ("nombre", -55), ("usuario", -18), ("contrasena_hash", 18), ("rol", 55), ("activo", 95)], 135),
    "ARTICULO": ([("id_articulo", 125), ("nombre", 148), ("descripcion", 171), ("cantidad_total", 194), ("precio_dia", 217), ("activo", 240)], 150),
    "RESERVACION": ([("id_reservacion", 165), ("fecha_inicio", 186), ("fecha_fin", 207), ("lugar_evento", 228),
                     ("estado", 249), ("fecha_registro", 75), ("/total", 108, 205)], 165),
    "ENTREGA": ([("id_entrega", 215), ("fecha_hora", 270), ("observaciones", 325)], 110),
    "DEVOLUCION": ([("id_devolucion", -5), ("fecha_hora", 25), ("observaciones", 55)], 150),
    "DETALLE_RESERVACION": ([("cantidad", 120), ("precio_unitario", 165)], 150),
    "DETALLE_DEVOLUCION": ([("cantidad_danada", 150), ("cantidad_devuelta", 210)], 170),
}


def chen():
    import math
    s = Svg(2000, 1320, "DER notación clásica de Chen - Rentas de mobiliario")
    s.text(40, 36, "Diagrama Entidad-Relación · notación clásica (Chen)", size=20, weight="bold")
    EW, EH = 190, 52

    def borde(nombre, hacia):
        cx, cy = CHEN_POS[nombre]
        dx, dy = hacia[0] - cx, hacia[1] - cy
        if dx == 0 and dy == 0:
            return cx, cy
        t = min((EW / 2) / abs(dx) if dx else 1e9, (EH / 2) / abs(dy) if dy else 1e9)
        return cx + dx * t, cy + dy * t

    def doble(p, q):
        ux, uy = unitario(p, q)
        px, py = -uy * 3, ux * 3
        s.line([(p[0] + px, p[1] + py), (q[0] + px, q[1] + py)], width=1.4)
        s.line([(p[0] - px, p[1] - py), (q[0] - px, q[1] - py)], width=1.4)

    # relaciones con rombo (la asociativa se une directo)
    for rid, padre, hijo, verbo, mn, mx, ident, fk in RELACIONES:
        a, b = CHEN_POS[padre], CHEN_POS[hijo]
        if hijo == "DETALLE_RESERVACION":
            p1, p2 = borde(padre, b), borde(hijo, a)
            # el lado de la asociativa siempre es total
            doble(p1, p2) if mn == 1 else s.line([p1, p2], width=1.5)
            mxp, myp = (p1[0] * .75 + p2[0] * .25), (p1[1] * .75 + p2[1] * .25)
            s.text(mxp + 10, myp - 6, "1", size=14, weight="bold", fill="#1D4ED8")
            mxh, myh = (p1[0] * .2 + p2[0] * .8), (p1[1] * .2 + p2[1] * .8)
            s.text(mxh + 10, myh, "N", size=14, weight="bold", fill="#1D4ED8")
            s.text((p1[0] + p2[0]) / 2 + 12, (p1[1] + p2[1]) / 2, verbo, size=11.5, fill=GRIS, style="italic")
            continue
        mxr, myr = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if rid == "R9":
            mxr, myr = 700, 1160
        dw, dh = 72, 34
        p1 = borde(padre, (mxr, myr))
        p2 = borde(hijo, (mxr, myr))
        if rid == "R9":
            s.line([p1, (a[0] - 0, myr)] if False else [borde(padre, (a[0], myr + 500)), (a[0], myr), (mxr - dw, myr)], width=1.5)
            doble((mxr + dw, myr), p2)
        else:
            s.line([p1, (mxr, myr)], width=1.5)
            # participación total del hijo (todas las relaciones del modelo son obligatorias para el hijo)
            doble((mxr, myr), p2)
        poly = f"{mxr},{myr-dh} {mxr+dw},{myr} {mxr},{myr+dh} {mxr-dw},{myr}"
        s.add(f'<polygon points="{poly}" fill="#FFF7FB" stroke="{LINEA}" stroke-width="1.6"/>')
        if ident:
            s.add(f'<polygon points="{mxr},{myr-dh+6} {mxr+dw-10},{myr} {mxr},{myr+dh-6} {mxr-dw+10},{myr}" fill="none" stroke="{LINEA}" stroke-width="1.2"/>')
        s.text(mxr, myr + 4, verbo, size=11.5, weight="bold", anchor="middle")
        # cardinalidades
        def card(p, q, t):
            s.text(p[0] * .8 + q[0] * .2 + 8, p[1] * .8 + q[1] * .2 - 6, t, size=14, weight="bold", fill="#1D4ED8")
        if rid == "R9":
            s.text(a[0] + 10, a[1] + EH / 2 + 30, "1", size=14, weight="bold", fill="#1D4ED8")
        else:
            card(p1, (mxr, myr), "1")
        card(p2, (mxr, myr), "N" if mx == "N" else "1")

    # entidades
    for n, (tipo, _) in ENTIDADES.items():
        cx, cy = CHEN_POS[n]
        x, y = cx - EW / 2, cy - EH / 2
        s.add(f'<rect x="{x}" y="{y}" width="{EW}" height="{EH}" fill="#FFF" stroke="{COLOR[tipo]}" stroke-width="2"/>')
        if tipo == "debil":
            s.add(f'<rect x="{x+5}" y="{y+5}" width="{EW-10}" height="{EH-10}" fill="none" stroke="{COLOR[tipo]}" stroke-width="1.4"/>')
        if tipo == "asociativa":
            s.add(f'<polygon points="{cx},{y+3} {x+EW-6},{cy} {cx},{y+EH-3} {x+6},{cy}" fill="none" stroke="{COLOR[tipo]}" stroke-width="1.2"/>')
        s.text(cx, cy + 5, n.replace("_", " ") if len(n) < 15 else n.replace("DETALLE_", "DET. "), size=13, weight="bold",
               fill=COLOR[tipo], anchor="middle")
        # atributos
        attrs, r = CHEN_ATR[n]
        for item in attrs:
            at, grados = item[0], item[1]
            rr = item[2] if len(item) > 2 else r
            ang = math.radians(grados)
            ox, oy = cx + math.cos(ang) * rr, cy + math.sin(ang) * rr
            pe = borde(n, (ox, oy))
            s.line([pe, (ox, oy)], width=1.1, color="#8E7A88")
            rx = max(52, len(at.lstrip("/")) * 4.1 + 14)
            derivado = at.startswith("/")
            dash = ' stroke-dasharray="5 4"' if derivado else ""
            s.add(f'<ellipse cx="{ox:.1f}" cy="{oy:.1f}" rx="{rx:.1f}" ry="16" fill="#FFF" stroke="#8E7A88" stroke-width="1.3"{dash}/>')
            es_pk = at.startswith("id_")
            s.text(ox, oy + 4, at.lstrip("/"), size=11, anchor="middle", weight="bold" if es_pk else "normal",
                   deco="underline" if es_pk else "")
    # leyenda
    lx, ly = 1500, 1060
    s.add(f'<rect x="{lx}" y="{ly}" width="460" height="230" rx="8" fill="#FBF7FA" stroke="#EDE1E8"/>')
    s.text(lx + 14, ly + 24, "Simbología (Chen)", size=13, weight="bold")
    ley = ["Rectángulo: entidad fuerte · doble rectángulo: entidad débil",
           "Rectángulo con rombo: entidad asociativa (resuelve N:M)",
           "Rombo: relación · doble rombo: relación identificante",
           "Óvalo: atributo · subrayado: identificador",
           "Óvalo punteado: atributo derivado (/total, no se guarda)",
           "Línea doble: participación total (obligatoria)",
           "1 / N: cardinalidad máxima de cada lado"]
    for i, t in enumerate(ley):
        s.text(lx + 14, ly + 52 + i * 24, "• " + t, size=12)
    s.save("2_chen_clasica.svg")


def mermaid():
    lineas = ["erDiagram"]
    card = {(0, "N"): "o{", (1, "N"): "|{", (0, "1"): "o|"}
    for rid, padre, hijo, verbo, mn, mx, ident, fk in RELACIONES:
        rel = "--" if ident else ".."
        lineas.append(f'    {padre} ||{rel}{card[(mn, mx)]} {hijo} : "{verbo}"')
    for n, (_, attrs) in ENTIDADES.items():
        lineas.append(f"    {n} {{")
        for a, t, k in attrs:
            tm = t.split("(")[0].lower()
            kk = " " + ",".join(x for x in k.split(",") if x in ("PK", "FK", "UK" if x == "UQ" else "")) if k else ""
            kk = kk.replace("UQ", "UK")
            lineas.append(f"        {tm} {a}{kk}")
        lineas.append("    }")
    md = "# DER en Mermaid (fuente editable)\n\nGitHub dibuja este diagrama automáticamente.\n\n```mermaid\n" + "\n".join(lineas) + "\n```\n"
    (SALIDA / "der_mermaid.md").write_text(md, encoding="utf-8")
    print("generado der_mermaid.md")


if __name__ == "__main__":
    crows_foot()
    chen()
    connect_to_columns()
    uml()
    idef1x()
    mermaid()
