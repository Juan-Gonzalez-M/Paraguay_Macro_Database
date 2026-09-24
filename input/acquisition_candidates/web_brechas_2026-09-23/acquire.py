#!/usr/bin/env python3
"""Adquisición de fuentes públicas que cierran brechas del ranking (proyectos/00_resumen_viabilidad.md § 3.3).

Uso (desde esta carpeta):
    python3 acquire.py ine        # INE: EPH serie comparable 1997-98..2007 y 2017..2021 + EPHC anual 2017..2025
    python3 acquire.py argentina  # Tipo de cambio argentino: BCRA oficial + paralelo (argentinadatos, bluelytics)
    python3 acquire.py aduana     # DNA: declaraciones a nivel ítem, mensual 1997..hoy (se guardan en gzip)
    python3 acquire.py documentos # Metodología IPC base 2017 y reporte técnico MTESS (ya descargados)

Todo queda en raw/<fuente>/ con inventory.csv (url, hora UTC, bytes, SHA-256 del contenido ORIGINAL y,
si se comprimió, SHA-256 del .gz). Reanudable: no vuelve a pedir lo que ya está en el inventario.
No se modifica ningún valor publicado. Pausa de 1 s entre pedidos.
"""
import csv, datetime, gzip, hashlib, json, os, re, sys, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
MODO = sys.argv[1] if len(sys.argv) > 1 else ""
# Un inventario por fuente para que descargas simultáneas no se pisen (ine, aduana); el resto en inventory.csv.
INV = os.path.join(ROOT, f"inventory_{MODO}.csv" if MODO in ("ine", "aduana") else "inventory.csv")
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


if __name__ == "__main__":
    {"ine": ine, "argentina": argentina, "aduana": aduana, "documentos": documentos}[sys.argv[1]]()
