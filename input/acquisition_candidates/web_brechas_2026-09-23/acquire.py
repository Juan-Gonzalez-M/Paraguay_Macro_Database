#!/usr/bin/env python3
"""Adquisición de fuentes públicas que cierran brechas del ranking (proyectos/00_resumen_viabilidad.md § 3.3).

Uso (desde esta carpeta):
    python3 acquire.py ine        # INE: EPH serie comparable 1997-98..2007 y 2017..2021 + EPHC anual 2017..2025
    python3 acquire.py argentina  # Tipo de cambio argentino: BCRA oficial + paralelo (argentinadatos, bluelytics)
    python3 acquire.py aduana     # DNA: declaraciones a nivel ítem, mensual 1997..hoy (se guardan en gzip)
    python3 acquire.py documentos # Metodología IPC base 2017 y reporte técnico MTESS (ya descargados)
    python3 acquire.py archivo    # Internet Archive: comunicados del CPM (BCP) y corte de bonos MEF 2025-08
    python3 acquire.py archivo_faltantes  # Internet Archive: evidencia de decisiones del CPM que la página no lista

Todo queda en raw/<fuente>/ con inventory.csv (url, hora UTC, bytes, SHA-256 del contenido ORIGINAL y,
si se comprimió, SHA-256 del .gz). Reanudable: no vuelve a pedir lo que ya está en el inventario.
No se modifica ningún valor publicado. Pausa de 1 s entre pedidos.
"""
import csv, datetime, gzip, hashlib, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
MODO = sys.argv[1] if len(sys.argv) > 1 else ""
# Un inventario por fuente para que descargas simultáneas no se pisen (ine, aduana); el resto en inventory.csv.
INV_MODO = {"archivo_faltantes": "archivo"}.get(MODO, MODO)
INV = os.path.join(ROOT, f"inventory_{INV_MODO}.csv" if INV_MODO in ("ine", "aduana", "archivo") else "inventory.csv")
UA = "Mozilla/5.0 (BCP investigacion; descarga lenta)"
CAMPOS = ["path", "url", "fuente", "retrieved_utc", "bytes", "sha256", "sha256_gz"]


def inventario():
    if not os.path.exists(INV):
        return {}
    with open(INV, newline="") as f:
        return {r["path"]: r for r in csv.DictReader(f)}


def registrar(fila):
    inv = inventario()
    inv[fila["path"]] = {k: fila.get(k, "") for k in CAMPOS}
    with open(INV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CAMPOS)
        w.writeheader()
        w.writerows(inv.values())


def pedir(url, timeout=600):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=timeout)


def bajar(url, rel, fuente, comprimir=False, intentos=4):
    """Descarga url a raw/rel (streaming). Con comprimir=True guarda rel + '.gz' (gzip sin pérdida)."""
    if rel + (".gz" if comprimir else "") in inventario():
        return "ya_estaba"
    dest = os.path.join(ROOT, rel + (".gz" if comprimir else ""))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    for k in range(intentos):
        try:
            h = hashlib.sha256()
            n = 0
            with pedir(url) as r:
                out = gzip.open(dest + ".part", "wb", compresslevel=6) if comprimir else open(dest + ".part", "wb")
                with out:
                    while True:
                        b = r.read(1 << 20)
                        if not b:
                            break
                        h.update(b)
                        n += len(b)
                        out.write(b)
                decl = r.headers.get("Content-Length")
            if decl and int(decl) != n:
                raise IOError(f"tamaño {n} distinto del declarado {decl}")
            os.replace(dest + ".part", dest)
            hgz = hashlib.sha256(open(dest, "rb").read()).hexdigest() if comprimir else ""
            registrar(dict(path=os.path.relpath(dest, ROOT), url=url, fuente=fuente,
                           retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                           bytes=n, sha256=h.hexdigest(), sha256_gz=hgz))
            time.sleep(1)
            return "ok"
        except Exception as e:  # noqa: BLE001
            print(f"  reintento {k + 1}: {url} -> {e}", flush=True)
            time.sleep(10 * (k + 1))
    return "fallo"


# --------------------------------------------------------------------------------------------- INE
def ine():
    html = pedir("https://www.ine.gov.py/microdatos/microdatos.php").read().decode("utf-8", "replace")
    links = sorted(set(re.findall(r'href="(https://www\.ine\.gov\.py/microdatos/register/(?:SERIE-EPHC|EPHC-ANUAL)/[^"]+)"', html)))
    omitir = [f"EPH-{a}/" for a in range(2008, 2017)]  # ya están en web_no_clima_2026-09-23
    sel = [u for u in links if not any(o in u for o in omitir)]
    print(f"INE: {len(links)} enlaces, {len(sel)} a descargar (2008-2016 omitidos: ya descargados)", flush=True)
    res = {}
    for u in sel:
        u_ok = urllib.parse.quote(urllib.parse.unquote(u), safe=":/")
        rel = "raw/ine/" + urllib.parse.unquote(u.split("/microdatos/register/")[1])
        res[u] = bajar(u_ok, rel, "INE microdatos")
        print(res[u], rel, flush=True)
    print({k: list(res.values()).count(k) for k in set(res.values())})


# ---------------------------------------------------------------------------------------- Argentina
def argentina():
    bajar("https://api.argentinadatos.com/v1/cotizaciones/dolares", "raw/argentina/argentinadatos_cotizaciones_dolares.json",
          "argentinadatos.com (agregador; cotizaciones de mercado)")
    bajar("https://api.bluelytics.com.ar/v2/evolution.json", "raw/argentina/bluelytics_evolution.json",
          "bluelytics.com.ar (agregador; oficial y blue)")
    hoy = datetime.date.today()
    for a in range(2002, hoy.year + 1):
        fin = min(datetime.date(a, 12, 31), hoy)
        url = f"https://api.bcra.gob.ar/estadisticascambiarias/v1.0/Cotizaciones/USD?fechadesde={a}-01-01&fechahasta={fin}&limit=1000"
        rel = f"raw/argentina/bcra_cotizaciones_usd_{a}{'_hasta_' + fin.isoformat() if a == hoy.year else ''}.json"
        print(bajar(url, rel, "BCRA API estadisticascambiarias v1.0 (oficial)"), rel, flush=True)


# --------------------------------------------------------------------------------------------- DNA
def aduana(desde=1997):
    lista = json.load(pedir("https://datosabiertos.aduana.gov.py/ddaa/mainctrl/listaArchivos"))
    items = [x for x in lista if x["fileName"].endswith("_Nivel_Item") and x["ext"] == "csv"]
    items = [x for x in items if int(x["separatePath"][1]) >= desde]
    items.sort(key=lambda x: (x["separatePath"][1], x["id"]))
    print(f"DNA: {len(items)} archivos mensuales a nivel ítem", flush=True)
    for x in items:
        url = "https://datosabiertos.aduana.gov.py/" + x["directory"] + urllib.parse.quote(x["fileName"]) + ".csv"
        rel = "raw/aduana/" + x["directory"].replace("all_data/", "") + x["fileName"] + ".csv"
        print(bajar(url, rel, "DNA Paraguay, portal de datos abiertos (SOFIA)", comprimir=True), rel, flush=True)


def documentos():
    bajar("https://informacionpublica.paraguay.gov.py/public/1970350-Metodologa_IPC_Base_Diciembre_2017_ma2pdf-Metodologa_IPC_Base_Diciembre_2017_ma2.pdf",
          "raw/bcp_metodologia_ipc_base_dic2017.pdf", "Portal de Acceso a la Información Pública (copia del documento BCP)")
    bajar("https://www.mtess.gov.py/wp-content/uploads/2026/06/Reporte_Tecnico_Ingresos_Laborales_Salario_Minimo_Paraguay_Final.pdf",
          "raw/mtess_reporte_tecnico_salario_minimo_2026.pdf", "MTESS")


# ----------------------------------------------------------------------------------- Internet Archive
# El sitio del BCP (y el portal de datos del MEF) rechaza clientes automáticos (Cloudflare); NO se sortea.
# Se usan las copias públicas del Internet Archive (Wayback Machine): se pide cada archivo con el sufijo
# id_ (bytes tal como los capturó el archivo, sin reescritura) y se registra la URL de la copia, que lleva
# la marca de tiempo de captura. Pausa de 4 s entre pedidos; ante 429 espera y reintenta.
WB = "https://web.archive.org"
PAG_CPM = "https://www.bcp.gov.py/comunicados-del-cpm"
PAG_CPM_TS = "20260821204752"  # única copia de la página en el archivo (consulta CDX del 2026-09-24)
UUID = re.compile(r"/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})")
MAGIC = {".pdf": b"%PDF", ".xlsx": b"PK"}


def pedir_wb(url, intentos=6):
    for k in range(intentos):
        try:
            with pedir(url, timeout=300) as r:
                b = r.read()
                if r.headers.get("Content-Encoding", "") == "gzip" or b[:2] == b"\x1f\x8b":
                    b = gzip.decompress(b)
                return b
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            print(f"  HTTP {e.code}; espera {60 * (k + 1)} s", flush=True)
            time.sleep(60 * (k + 1))
        except Exception as e:  # noqa: BLE001
            print(f"  reintento {k + 1}: {e}", flush=True)
            time.sleep(20 * (k + 1))
    raise IOError("sin respuesta: " + url)


def guardar_wb(url_wb, rel, fuente, url_original):
    if rel in inventario():
        return "ya_estaba"
    b = pedir_wb(url_wb)
    ext = os.path.splitext(rel)[1].lower()
    if ext in MAGIC and not b.startswith(MAGIC[ext]):
        return "no_es_" + ext[1:]  # p. ej., una página de error capturada con estado 200
    dest = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(b)
    registrar(dict(path=rel, url=url_wb, fuente=f"{fuente}; original: {url_original}",
                   retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   bytes=len(b), sha256=hashlib.sha256(b).hexdigest(), sha256_gz=""))
    time.sleep(4)
    return "ok"


def cdx(consulta):
    txt = pedir_wb(WB + "/cdx/search/cdx?" + consulta).decode("utf-8", "replace")
    time.sleep(4)
    return [l.split() for l in txt.splitlines() if l.strip()]


def archivo():
    # 1) La página del CPM archivada: lista de documentos publicados (evidencia de qué existe).
    rel_pag = f"raw/archivo/bcp_comunicados_del_cpm_{PAG_CPM_TS}.html"
    guardar_wb(f"{WB}/web/{PAG_CPM_TS}id_/{PAG_CPM}", rel_pag, "Internet Archive (copia de la página del BCP)", PAG_CPM)
    html = open(os.path.join(ROOT, rel_pag), encoding="utf-8", errors="replace").read()
    enlaces = []
    for m in re.finditer(r'href="(/documents/[^"]+)"', html):
        h = m.group(1).replace("&amp;", "&")
        if UUID.search(h) and h not in enlaces:
            enlaces.append(h)
    # 2) Copias archivadas de esos documentos (dos consultas CDX; se busca por el UUID del documento).
    filas = cdx("url=bcp.gov.py/documents/20117/2254845/&matchType=prefix&output=text&fl=timestamp,original,statuscode,mimetype&filter=statuscode:200&collapse=urlkey")
    filas += cdx("url=bcp.gov.py/documents/20117/&matchType=prefix&output=text&fl=timestamp,original,statuscode,mimetype&filter=statuscode:200&filter=original:.*(CEOMA|Ceoma|Comunicado|CPM|COPOM).*&collapse=urlkey")
    copias = {}
    for f in filas:
        u = UUID.search(f[1])
        if u and f[3] in ("application/pdf", "application/octet-stream"):
            copias.setdefault(u.group(1), []).append((f[0], f[1]))
    # 3) Descarga + registro de TODOS los documentos de la página (archivados o no).
    control = []
    for h in enlaces:
        u = UUID.search(h).group(1)
        nombre = urllib.parse.unquote_plus(h.split("/")[4])
        idioma = "en" if re.search(r"press|release", nombre, re.I) else "es"
        est, ts, rel = "no_archivado", "", ""
        for ts_c, orig in sorted(copias.get(u, []), key=lambda x: x[0]):
            rel = f"raw/archivo/cpm/{u}_{re.sub(r'[^A-Za-z0-9._-]+', '_', nombre)}"
            if not rel.lower().endswith(".pdf"):
                rel += ".pdf"
            try:
                est = guardar_wb(f"{WB}/web/{ts_c}id_/{orig}", rel, "Internet Archive (copia del documento del BCP)", "https://www.bcp.gov.py" + h)
            except Exception as e:  # noqa: BLE001
                est = f"fallo: {e}"
            ts = ts_c
            if est in ("ok", "ya_estaba"):
                break
        if est not in ("ok", "ya_estaba"):
            rel = ""
        print(est, nombre, flush=True)
        control.append(dict(uuid=u, nombre_publicado=nombre, idioma=idioma, url_bcp="https://www.bcp.gov.py" + h,
                            estado=est, wayback_timestamp=ts, path=rel))
    with open(os.path.join(ROOT, "extraidos/cpm_documentos_control.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(control[0]))
        w.writeheader()
        w.writerows(control)
    print({k: sum(c["estado"] == k for c in control) for k in {c["estado"] for c in control}})
    # 4) MEF: corte de agosto de 2025 de bonos del Tesoro en circulación (los demás cortes ya están).
    orig = "https://www.mef.gov.py/sites/default/files/2025-09/8.%20Bonos_del_Tesoro_en_circulacion%20-%20agosto%202025.xlsx"
    # El índice CDX lista capturas (2025-09-20 y 2025-09-27, estado 200), pero al 2026-09-24 la reproducción
    # responde 404 en ambas (también la versión en inglés): se registra como no recuperable.
    try:
        est = guardar_wb(f"{WB}/web/20250920125747id_/{orig}", "raw/archivo/mef_bonos_del_tesoro_en_circulacion_2025-08.xlsx",
                         "Internet Archive (copia del archivo del MEF)", orig)
    except urllib.error.HTTPError as e:
        est = f"no_recuperable (HTTP {e.code} en la reproducción del archivo)"
    print(est, "MEF bonos 2025-08")


# Evidencia de decisiones del CPM que la página «Comunicados del CPM» (copia 2026-08-21) no lista o cuyo documento
# no se había encontrado. Capturas elegidas a mano en el índice CDX (consultas del 2026-09-24); cada fila es
# (marca de tiempo de la captura, URL original, destino, motivo). Solo copias ya existentes en el archivo: no se usa
# «Save Page Now» (eso haría que el archivo pidiera las páginas al BCP por nosotros). Mayo a julio de 2026 no tienen
# copia archivada: se bajan a mano desde el sitio del BCP.
FALTANTES_CPM = [
    # noviembre de 2011: el documento que lista la página (mismo UUID) y la copia contemporánea del sitio de 2012
    ("20260506035933", "https://www.bcp.gov.py/documents/20117/0/Reunion_de_Politica_Monetaria_03_nov_11.pdf/958842e0-5b6b-9927-563e-8254503148b8",
     "raw/archivo/cpm/958842e0-5b6b-9927-563e-8254503148b8_Reunion_de_Politica_Monetaria_03_nov_11.pdf", "comunicado 2011-11 (listado en la página)"),
    ("20120522121315", "http://www.bcp.gov.py/attachments/article/1051/Reunion_de_Politica_Monetaria_03_11_11.pdf",
     "raw/archivo/cpm_faltantes/2012_attachments_1051_Reunion_de_Politica_Monetaria_03_11_11.pdf", "comunicado 2011-11 (sitio de 2012)"),
    # marzo-abril de 2020: reuniones extraordinarias. Capturas alternativas donde la primera falló el 2026-09-24:
    # «CPM marzo 2020» 20220308081847 no devolvía un PDF; «05Comunicado…30_03_20.pdf» 20230608231913 daba 404. (el corredor se desplaza el 2020-03-31 sin comunicado listado)
    ("20230204000447", "https://www.bcp.gov.py/userfiles/files/CPM%20marzo%202020.pdf", "raw/archivo/cpm_faltantes/CPM_marzo_2020.pdf", "comunicado CPM marzo 2020"),
    ("20220308081936", "https://www.bcp.gov.py/userfiles/files/CPM%20marzo%202020_2.pdf", "raw/archivo/cpm_faltantes/CPM_marzo_2020_2.pdf", "comunicado CPM marzo 2020 (2)"),
    ("20220308081655", "https://www.bcp.gov.py/userfiles/files/CPM_marzo_2_2020(1).pdf", "raw/archivo/cpm_faltantes/CPM_marzo_2_2020_1_.pdf", "comunicado CPM marzo 2020 (2), otra copia"),
    ("20220308081620", "https://www.bcp.gov.py/userfiles/files/CPM_segunda%20extraordinaria_marzo_2020.pdf", "raw/archivo/cpm_faltantes/CPM_segunda_extraordinaria_marzo_2020.pdf", "comunicado segunda reunión extraordinaria marzo 2020"),
    ("20220308081752", "https://www.bcp.gov.py/comunicado-de-prensa-de-cpm-segunda-reunion-extraordinaria-n1304", "raw/archivo/cpm_faltantes/comunicado-de-prensa-de-cpm-segunda-reunion-extraordinaria-n1304.html", "página del comunicado de la segunda extraordinaria"),
    ("20220308081935", "https://www.bcp.gov.py/userfiles/files/Press_release_CPM_March_2020_special.pdf", "raw/archivo/cpm_faltantes/Press_release_CPM_March_2020_special.pdf", "press release (inglés) especial marzo 2020"),
    ("20220619225234", "https://bcp.gov.py/userfiles/files/Minuta_CPM_marzo_2020%281%29.pdf", "raw/archivo/cpm_faltantes/Minuta_CPM_marzo_2020_1_.pdf", "minuta marzo 2020"),
    ("20220619225241", "https://bcp.gov.py/userfiles/files/Minuta_CPM_marzo_2020_extra%282%29.pdf", "raw/archivo/cpm_faltantes/Minuta_CPM_marzo_2020_extra_2_.pdf", "minuta extraordinaria marzo 2020"),
    ("20220308081626", "https://www.bcp.gov.py/userfiles/files/Minuta_CPM_marzo_2020_2_extra.pdf", "raw/archivo/cpm_faltantes/Minuta_CPM_marzo_2020_2_extra.pdf", "minuta segunda extraordinaria marzo 2020"),
    ("20201104103346", "https://www.bcp.gov.py/userfiles/files/Minuta_CPM_marzo_extraordinaria3_13_04_2020%282%29.pdf", "raw/archivo/cpm_faltantes/Minuta_CPM_marzo_extraordinaria3_13_04_2020_2_.pdf", "minuta tercera extraordinaria (13-04-2020)"),
    ("20230204000724", "https://www.bcp.gov.py/userfiles/files/05Comunicado_Medidas_adicionales_30_03_20(1).pdf", "raw/archivo/cpm_faltantes/05Comunicado_Medidas_adicionales_30_03_20.pdf", "comunicado BCP medidas adicionales 30-03-2020"),
    # septiembre de 2023: la página no lista comunicado; se conservan la minuta y su página
    ("20231014000407", "https://www.bcp.gov.py/userfiles/getFile.php?file=userfiles/files/Minuta%20del%20CPM%20septiembre%202023.pdf", "raw/archivo/cpm_faltantes/Minuta_del_CPM_septiembre_2023.pdf", "minuta CPM septiembre 2023"),
    ("20231014031748", "https://www.bcp.gov.py/minuta-de-la-reunion-del-cpm-de-septiembre-n1964", "raw/archivo/cpm_faltantes/minuta-de-la-reunion-del-cpm-de-septiembre-n1964.html", "página de la minuta CPM septiembre 2023"),
]


def archivo_faltantes():
    for ts, orig, rel, motivo in FALTANTES_CPM:
        try:
            est = guardar_wb(f"{WB}/web/{ts}id_/{orig}", rel, f"Internet Archive (copia del BCP; {motivo})", orig)
        except Exception as e:  # noqa: BLE001
            est = f"fallo: {e}"
        print(est, rel, flush=True)


if __name__ == "__main__":
    {"ine": ine, "argentina": argentina, "aduana": aduana, "documentos": documentos, "archivo": archivo,
     "archivo_faltantes": archivo_faltantes}[sys.argv[1]]()
