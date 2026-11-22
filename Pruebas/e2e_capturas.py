"""
Pruebas de interfaz de punta a punta + capturas para el reporte.

Recorre la aplicación como lo haría un usuario (Playwright con Microsoft Edge
o Chrome instalados), ejecuta casos válidos e inválidos y guarda:
  * Pruebas/capturas/*.png        -> evidencias para el reporte
  * Pruebas/resultados_ui.json    -> resultado observado de cada caso

Uso (con la aplicación corriendo en http://localhost:5207 y la BD recién instalada):
    python Pruebas/e2e_capturas.py            # fase 1: operaciones
    (cerrar y volver a abrir la aplicación)
    python Pruebas/e2e_capturas.py fase2      # fase 2: persistencia
Requisitos: pip install playwright   (usa el navegador Edge/Chrome ya instalado)
"""
import json
import sys
import datetime as dt
from pathlib import Path
from playwright.sync_api import sync_playwright, Page

BASE = "http://localhost:5207"
AQUI = Path(__file__).resolve().parent
CAPTURAS = AQUI / "capturas"
CAPTURAS.mkdir(exist_ok=True)
ESTADO = AQUI / "estado_e2e.json"
RESULTADOS = AQUI / "resultados_ui.json"

hoy = dt.date.today()
viernes = hoy + dt.timedelta(days=((4 - hoy.weekday() + 7) % 7) + 7)
resultados: list[dict] = json.loads(RESULTADOS.read_text(encoding="utf-8")) if RESULTADOS.exists() and "fase2" in sys.argv else []


def registrar(id_caso, descripcion, esperado, observado, paso):
    resultados.append({"id": id_caso, "descripcion": descripcion, "esperado": esperado,
                       "observado": observado, "estado": "PASA" if paso else "FALLA"})
    print(("PASA " if paso else "FALLA") + f" {id_caso}: {observado}")


def foto(page: Page, nombre: str, completa=True):
    page.screenshot(path=str(CAPTURAS / f"{nombre}.png"), full_page=completa)


def login(page: Page, usuario: str, clave: str):
    page.goto(f"{BASE}/Cuenta/Login")
    page.fill("#Usuario", usuario)
    page.fill("#pwd", clave)
    page.click("button[type=submit]")
    page.wait_for_load_state("networkidle")


def logout(page: Page):
    if page.locator("button[aria-label='Cerrar sesión']").count() == 0:
        page.goto(f"{BASE}/")
    page.click("button[aria-label='Cerrar sesión']")
    page.wait_for_load_state("networkidle")


def texto_alerta(page: Page) -> str:
    loc = page.locator(".alert-danger, .toast[role=alert] .toast-body")
    return loc.first.inner_text().strip() if loc.count() else ""


def toast_ok(page: Page) -> str:
    loc = page.locator(".toast[role=status] .toast-body")
    return loc.first.inner_text().strip() if loc.count() else ""


def nueva_reservacion(page: Page, cliente: str, inicio: dt.date, fin: dt.date, lugar: str, renglones):
    page.goto(f"{BASE}/Reservaciones/Nueva")
    page.select_option("#IdCliente", cliente)
    page.fill("#Lugar", lugar)
    page.fill("#Inicio", inicio.isoformat())
    page.dispatch_event("#Inicio", "change")
    page.fill("#Fin", fin.isoformat())
    page.dispatch_event("#Fin", "change")
    for i, (art, cant) in enumerate(renglones):
        if i > 0:
            page.click("#btnAgregar")
        page.select_option(f"#art-{i}", str(art))
        page.fill(f"#cant-{i}", str(cant))
    page.wait_for_timeout(700)  # disponibilidad en vivo


def fase1(page: Page):
    estado = {}

    # ---------- Login ----------
    page.goto(f"{BASE}/")
    foto(page, "01_login", completa=False)
    page.fill("#Usuario", "admin")
    page.fill("#pwd", "contraseña-incorrecta1")
    page.click("button[type=submit]")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-01", "Inicio de sesión con contraseña incorrecta", "Mensaje de error, sin acceso",
              msg, "incorrectos" in msg)
    foto(page, "02_login_error", completa=False)

    login(page, "admin", "Admin2026!")
    registrar("UI-02", "Inicio de sesión del Administrador", "Entra al tablero",
              page.title(), page.title().startswith("Tablero"))
    page.wait_for_timeout(600)
    foto(page, "03_tablero")

    # ---------- Disponibilidad (ejemplo del análisis) ----------
    page.goto(f"{BASE}/Disponibilidad?Inicio={viernes}&Fin={viernes}&IdCategoria=1")
    fila = page.locator("tr", has_text="Silla Tiffany dorada")
    disp = fila.locator("td").nth(3).inner_text().strip()
    registrar("UI-03", f"Disponibilidad de sillas Tiffany el viernes {viernes} (ejemplo del análisis)",
              "10 disponibles (100 - 60 - 30)", f"{disp} disponibles", disp == "10")
    foto(page, "04_disponibilidad")

    # ---------- RN-03 sobreventa desde la interfaz ----------
    nueva_reservacion(page, "21", viernes, viernes, "Casa de Camila, Ensenada", [(2, 20)])
    foto(page, "05_nueva_exceso_vista_previa")
    page.click("button:has-text('Confirmar reservación')")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    conservado = page.input_value("#cant-0") == "20" and page.input_value("#Lugar") == "Casa de Camila, Ensenada"
    registrar("UI-04", "Reservar 20 sillas Tiffany el viernes (solo hay 10)",
              "La BD rechaza (RN-03) y el formulario conserva lo capturado",
              msg + (" | datos conservados" if conservado else " | datos perdidos"), "RN-03" in msg and conservado)
    foto(page, "06_nueva_rechazo_rn03")

    # ---------- Alta válida de reservación (operación multitabla) ----------
    inicio = hoy + dt.timedelta(days=9)
    nueva_reservacion(page, "21", inicio, inicio + dt.timedelta(days=1), "Jardín Las Rosas, Ensenada",
                      [(1, 30), (4, 3), (8, 3)])
    page.wait_for_timeout(500)
    total_vista = page.inner_text("#resTotal")
    foto(page, "07_nueva_valida")
    page.click("button:has-text('Confirmar reservación')")
    page.wait_for_load_state("networkidle")
    url = page.url
    ok = "/Reservaciones/Detalle/" in url
    id_res = int(url.rstrip("/").split("/")[-1]) if ok else None
    estado["reservacion"] = id_res
    total_bd = page.locator("tfoot td").nth(1).inner_text().strip() if ok else ""
    registrar("UI-05", "Crear reservación con 3 artículos por 2 días (sp_crear_reservacion)",
              "Se guarda Confirmada; total calculado por la BD igual al de la vista previa",
              f"Reservación #{id_res}, total vista {total_vista} / BD {total_bd}",
              ok and total_vista.replace(" ", "") == total_bd.replace(" ", ""))
    foto(page, "08_detalle_confirmada")

    # ---------- Edición de cantidad que excede ----------
    page.fill("#c-1", "999")
    page.locator("form:has(#c-1) button[type=submit]").click()
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-06", "Cambiar la cantidad de sillas plegables a 999 en la reservación",
              "Trigger trg_detres_bu rechaza (RN-03)", msg, "RN-03" in msg)

    # ---------- Entrega ----------
    page.click("button:has-text('Registrar entrega')")
    page.fill("#obsEntrega", "Entrega de prueba desde la interfaz")
    foto(page, "09_modal_entrega", completa=False)
    page.click("button:has-text('Confirmar entrega')")
    page.wait_for_load_state("networkidle")
    est = page.locator(".page-header .badge-estado").first.inner_text().strip()
    registrar("UI-07", "Registrar entrega (sp_registrar_entrega + trigger trg_entrega_ai)",
              "Estado cambia a Entregada", f"Estado: {est}. {toast_ok(page)}", est == "Entregada")

    # ---------- Devolución inválida y válida ----------
    page.goto(f"{BASE}/Reservaciones/Devolucion/{id_res}")
    page.fill("#dan-0", "2")   # 30 devueltas + 2 dañadas > 30 rentadas
    page.wait_for_timeout(200)
    foto(page, "10_devolucion_invalida")
    page.click("button:has-text('Guardar devolución')")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-08", "Devolución con devueltas + dañadas mayor que lo rentado",
              "Rechazo por RN-10", msg, "RN-10" in msg)

    page.goto(f"{BASE}/Reservaciones/Devolucion/{id_res}")
    fila_sillas = page.locator("tr.renglon-dev", has_text="Silla plegable blanca")
    fila_sillas.locator(".inp-dev").fill("27")
    fila_sillas.locator(".inp-dan").fill("2")   # 1 faltante
    page.click("button:has-text('Guardar devolución')")
    page.wait_for_load_state("networkidle")
    est = page.locator(".page-header .badge-estado").first.inner_text().strip()
    registrar("UI-09", "Devolución válida con 2 dañadas y 1 faltante (sp_registrar_devolucion)",
              "Estado Finalizada y revisión visible", f"Estado: {est}. {toast_ok(page)}", est == "Finalizada")
    foto(page, "11_detalle_finalizada")

    # ---------- Cancelación ----------
    nueva_reservacion(page, "22", hoy + dt.timedelta(days=12), hoy + dt.timedelta(days=12),
                      "Terraza Andrés, Ensenada", [(3, 10)])
    page.click("button:has-text('Confirmar reservación')")
    page.wait_for_load_state("networkidle")
    id_cancel = int(page.url.rstrip("/").split("/")[-1])
    page.once("dialog", lambda d: d.accept())
    page.click("form[action*='handler=Cancelar'] button")
    page.wait_for_load_state("networkidle")
    est = page.locator(".page-header .badge-estado").first.inner_text().strip()
    registrar("UI-10", "Cancelar una reservación Confirmada (sp_cancelar_reservacion)",
              "Estado Cancelada y piezas liberadas", f"#{id_cancel} {est}", est == "Cancelada")
    estado["cancelada"] = id_cancel

    # ---------- Listado de reservaciones con filtros ----------
    page.goto(f"{BASE}/Reservaciones?Filtro.Estado=Confirmada")
    foto(page, "12_reservaciones_lista")
    page.goto(f"{BASE}/Reservaciones?Filtro.Buscar=zzzz_no_existe")
    vacio = page.locator(".empty-state").count() > 0
    registrar("UI-11", "Búsqueda sin coincidencias en reservaciones", "Estado vacío con mensaje",
              "Se muestra estado vacío" if vacio else "Sin estado vacío", vacio)
    foto(page, "13_estado_vacio", completa=False)

    # ---------- CRUD de clientes ----------
    page.goto(f"{BASE}/Clientes/Editar")
    page.fill("#Form_Nombre", "Lucero")
    page.fill("#Form_Apellidos", "Prueba Interfaz")
    page.fill("#Form_Telefono", "64612AB")
    page.fill("#Form_Correo", "correo-malo")
    page.click("button:has-text('Registrar cliente')")
    page.wait_for_timeout(400)
    errores = page.locator(".field-validation-error").all_inner_texts()
    registrar("UI-12", "Alta de cliente con teléfono y correo inválidos",
              "Mensajes de validación junto a cada campo", "; ".join(errores), len(errores) >= 2)
    foto(page, "14_cliente_validacion")

    page.fill("#Form_Telefono", "6461112233")
    page.fill("#Form_Correo", "mafer.lopez@example.com")   # duplicado
    page.click("button:has-text('Registrar cliente')")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-13", "Alta de cliente con correo ya registrado", "Rechazo por UNIQUE (RN-12)",
              msg, "Ya existe" in msg)

    page.fill("#Form_Correo", "lucero.prueba@example.com")
    page.click("button:has-text('Registrar cliente')")
    page.wait_for_load_state("networkidle")
    id_cli = int(page.url.rstrip("/").split("/")[-1]) if "/Clientes/Detalle/" in page.url else None
    estado["cliente"] = id_cli
    registrar("UI-14", "Alta válida de cliente", "Se guarda y muestra su ficha",
              f"Cliente #{id_cli}. {toast_ok(page)}", id_cli is not None)

    page.goto(f"{BASE}/Clientes/Editar/{id_cli}")
    page.fill("#Form_Direccion", "Calle Primera 100, Ensenada")
    page.click("button:has-text('Guardar cambios')")
    page.wait_for_load_state("networkidle")
    registrar("UI-15", "Modificar la dirección del cliente", "Cambios guardados",
              toast_ok(page), "Calle Primera 100" in page.content())

    page.goto(f"{BASE}/Clientes?Buscar=Lucero")
    foto(page, "15_clientes_busqueda")
    page.once("dialog", lambda d: d.accept())
    page.locator(f"form[action*='id={id_cli}'] button, form[action*='/{id_cli}?'] button").first.click()
    page.wait_for_load_state("networkidle")
    registrar("UI-16", "Eliminar un cliente sin reservaciones", "Se elimina",
              toast_ok(page), "eliminado" in toast_ok(page))

    page.goto(f"{BASE}/Clientes/Detalle/1")
    page.once("dialog", lambda d: d.accept())
    page.click("button:has-text('Eliminar')")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-17", "Eliminar un cliente con reservaciones", "Rechazo por FK ON DELETE RESTRICT (RN-11)",
              msg, "No se puede eliminar" in msg)
    foto(page, "16_cliente_fk_error", completa=False)

    # ---------- Artículos ----------
    page.goto(f"{BASE}/Articulos")
    foto(page, "17_articulos")
    page.goto(f"{BASE}/Articulos/Editar/1")
    page.fill("#Form_CantidadTotal", "20")
    page.click("button:has-text('Guardar')")
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-18", "Reducir el inventario de sillas plegables a 20", "Trigger trg_articulo_bu rechaza (RN-03)",
              msg, "RN-03" in msg)

    page.goto(f"{BASE}/Articulos/Editar/9")
    page.fill("#Form_PrecioDia", "32.50")
    page.click("button:has-text('Guardar')")
    page.wait_for_load_state("networkidle")
    page.goto(f"{BASE}/Articulos/Editar/9")
    hist = page.locator(".list-group-item").count()
    registrar("UI-19", "Cambiar el precio del mantel rectangular a $32.50",
              "Se guarda y trg_articulo_au registra el historial", f"{hist} cambio(s) en historial", hist >= 1)
    foto(page, "18_articulo_historial_precio")

    page.goto(f"{BASE}/Articulos/Editar")
    page.select_option("#Form_IdCategoria", "5")
    page.fill("#Form_Nombre", "Bocina con micrófono")
    page.fill("#Form_Descripcion", "Bocina amplificada de 15 pulgadas")
    page.fill("#Form_CantidadTotal", "4")
    page.fill("#Form_PrecioDia", "350")
    page.click("button:has-text('Guardar')")
    page.wait_for_load_state("networkidle")
    registrar("UI-20", "Alta de un artículo nuevo", "Se agrega al catálogo", toast_ok(page), "agregado" in toast_ok(page))

    # ---------- Categorías ----------
    page.goto(f"{BASE}/Categorias")
    page.fill("#Form_Nombre", "Audio")
    page.fill("#Form_Descripcion", "Bocinas y micrófonos")
    page.click("button:has-text('Crear categoría')")
    page.wait_for_load_state("networkidle")
    registrar("UI-21", "Crear categoría Audio", "Se crea", toast_ok(page), "creada" in toast_ok(page))
    page.once("dialog", lambda d: d.accept())
    page.locator("tr:has(td.fw-semibold:text-is('Sillas'))").locator("button[aria-label^='Eliminar']").click()
    page.wait_for_load_state("networkidle")
    msg = texto_alerta(page)
    registrar("UI-22", "Eliminar la categoría Sillas (tiene artículos)", "Rechazo por FK", msg, "No se puede eliminar" in msg)
    foto(page, "19_categorias")

    # ---------- Empleados ----------
    page.goto(f"{BASE}/Empleados/Editar")
    page.fill("#Form_Nombre", "Sofía Encargada Prueba")
    page.fill("#Form_Usuario", "sofia.prueba")
    page.fill("#Form_Contrasena", "Prueba2026!")
    page.fill("#Form_Confirmar", "Prueba2026!")
    page.click("button:has-text('Guardar')")
    page.wait_for_load_state("networkidle")
    registrar("UI-23", "Alta de empleado Encargado con contraseña cifrada", "Se registra",
              toast_ok(page), "registrado" in toast_ok(page))
    foto(page, "20_empleados")

    # ---------- Reportes y auditoría ----------
    page.goto(f"{BASE}/Reportes")
    page.wait_for_timeout(700)
    foto(page, "21_reporte_ingresos")
    page.goto(f"{BASE}/Reportes?Tab=articulos")
    foto(page, "22_reporte_articulos")
    page.goto(f"{BASE}/Reportes?Tab=faltantes")
    filas = page.locator("tbody tr").count()
    registrar("UI-24", "Reporte de faltantes y daños (vista vw_faltantes_danos)", "Lista las devoluciones con daños",
              f"{filas} renglón(es)", filas >= 1)
    foto(page, "23_reporte_faltantes")
    page.goto(f"{BASE}/Reportes?Tab=clientes&Minimo=2")
    foto(page, "24_reporte_clientes")
    with page.expect_download() as d:
        page.click("a:has-text('Exportar CSV')")
    registrar("UI-25", "Exportar reporte a CSV", "Descarga un archivo .csv",
              d.value.suggested_filename, d.value.suggested_filename.endswith(".csv"))
    page.goto(f"{BASE}/Bitacora")
    foto(page, "25_auditoria")
    page.goto(f"{BASE}/Reservaciones/Detalle/{id_res}")
    foto(page, "26_detalle_bitacora")

    # Tema oscuro y móvil
    page.goto(f"{BASE}/")
    page.click("#btnTema")
    page.wait_for_timeout(500)
    foto(page, "27_tablero_oscuro", completa=False)
    page.click("#btnTema")

    logout(page)

    # ---------- Permisos por rol (RN-13) ----------
    login(page, "carlos.ibarra", "Encargado2026!")
    page.goto(f"{BASE}/Empleados")
    denegado = "AccesoDenegado" in page.url
    registrar("UI-26", "Un Encargado intenta abrir Empleados", "Acceso denegado (RN-13)", page.url, denegado)
    foto(page, "28_acceso_denegado", completa=False)
    logout(page)

    login(page, "jorge.pena", "Encargado2026!")
    msg = texto_alerta(page)
    registrar("UI-27", "Empleado inactivo intenta iniciar sesión", "Se niega el acceso", msg, "inactiva" in msg)

    ESTADO.write_text(json.dumps(estado), encoding="utf-8")


def fase2(page: Page):
    estado = json.loads(ESTADO.read_text(encoding="utf-8"))
    login(page, "admin", "Admin2026!")
    page.goto(f"{BASE}/Reservaciones/Detalle/{estado['reservacion']}")
    est = page.locator(".page-header .badge-estado").first.inner_text().strip()
    registrar("UI-28", "Persistencia: tras cerrar y reabrir la aplicación, la reservación creada sigue Finalizada",
              "Los datos se leen de MySQL", f"#{estado['reservacion']} {est}", est == "Finalizada")
    foto(page, "29_persistencia_detalle")
    page.goto(f"{BASE}/Reservaciones/Detalle/{estado['cancelada']}")
    est = page.locator(".page-header .badge-estado").first.inner_text().strip()
    registrar("UI-29", "Persistencia: la reservación cancelada sigue Cancelada", "Cancelada",
              f"#{estado['cancelada']} {est}", est == "Cancelada")
    # Vista móvil
    page.set_viewport_size({"width": 390, "height": 844})
    page.goto(f"{BASE}/")
    foto(page, "30_tablero_movil", completa=False)


def main():
    fase = "fase2" if "fase2" in sys.argv else "fase1"
    with sync_playwright() as p:
        try:
            nav = p.chromium.launch(channel="msedge")
        except Exception:
            nav = p.chromium.launch(channel="chrome")
        ctx = nav.new_context(viewport={"width": 1440, "height": 900}, locale="es-MX", accept_downloads=True,
                              color_scheme="light")
        ctx.add_init_script("try{ if(!sessionStorage.getItem('e2e')){ localStorage.setItem('tema','light'); sessionStorage.setItem('e2e','1'); } }catch(e){}")
        page = ctx.new_page()
        try:
            fase1(page) if fase == "fase1" else fase2(page)
        finally:
            RESULTADOS.write_text(json.dumps(resultados, ensure_ascii=False, indent=2), encoding="utf-8")
            nav.close()
    pasan = sum(r["estado"] == "PASA" for r in resultados)
    print(f"\n{pasan}/{len(resultados)} casos de interfaz pasan")


if __name__ == "__main__":
    main()
