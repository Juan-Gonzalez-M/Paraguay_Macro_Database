"""Retain original public-source bytes outside the ingestion pipeline."""

import argparse
import csv
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parent
UA = "ParaguayMacroResearch/1.0 (research acquisition audit)"


class Anchors(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            url = dict(attrs).get("href")
            if url:
                self.urls.append(html.unescape(url))


def stamp():
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def log(record):
    with (ROOT / "attempts.jsonl").open("a", encoding="utf-8") as out:
        out.write(json.dumps(record, ensure_ascii=False) + "\n")


def fetch(url, relative_path, source_page=None):
    path = ROOT / relative_path
    if path.exists():
        print("PRESENT", relative_path, flush=True)
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    parsed = urllib.parse.urlsplit(url)
    request_url = urllib.parse.urlunsplit((parsed.scheme, parsed.netloc,
        urllib.parse.quote(parsed.path, safe="/%:@"), parsed.query, parsed.fragment))
    request = urllib.request.Request(request_url, headers={"User-Agent": UA, "Accept": "*/*"})
    partial = path.with_name(path.name + ".part")
    try:
        with urllib.request.urlopen(request, timeout=45) as response, partial.open("wb") as out:
            first = response.read(65536)
            if not first:
                raise ValueError("empty response")
            suffix = path.suffix.lower()
            if suffix == ".pdf" and not first.startswith(b"%PDF"):
                raise ValueError("unexpected PDF signature; possible access page")
            if suffix in (".xlsx", ".xlsm", ".zip") and not first.startswith(b"PK"):
                raise ValueError("unexpected ZIP/Office signature; possible access page")
            if suffix in (".xls", ".doc") and not first.startswith(b"\xd0\xcf\x11\xe0"):
                raise ValueError("unexpected legacy Office signature; possible access page")
            if suffix == ".csv" and b"<html" in first[:1000].lower():
                raise ValueError("HTML response instead of CSV")
            out.write(first)
            while block := response.read(1024 * 1024):
                out.write(block)
            final_url = response.url
            content_type = response.headers.get("Content-Type", "")
        partial.replace(path)
        digest = sha256_file(path)
        log({"at_utc": stamp(), "status": "downloaded", "path": relative_path,
             "url": url, "final_url": final_url, "source_page": source_page or "",
             "content_type": content_type, "bytes": path.stat().st_size, "sha256": digest})
        print("OK", relative_path, path.stat().st_size, flush=True)
        return path
    except Exception as error:
        partial.unlink(missing_ok=True)
        log({"at_utc": stamp(), "status": "failed", "path": relative_path,
             "url": url, "source_page": source_page or "", "error": str(error)})
        print("FAIL", relative_path, str(error), flush=True)
        return None


def catalog(name, url):
    path = fetch(url, "catalogs/" + name + ".html")
    if not path:
        return []
    parser = Anchors()
    parser.feed(path.read_text(encoding="utf-8", errors="replace"))
    return [urllib.parse.urljoin(url, link) for link in parser.urls]


def ine():
    page = "https://www.ine.gov.py/microdatos/microdatos.php"
    links = catalog("ine_microdatos", page)
    candidates = []
    for url in links:
        parsed = urllib.parse.urlsplit(url)
        match = re.search(r"/SERIE-EPHC/EPH-(20\d\d)/", parsed.path)
        if not match or not 2008 <= int(match.group(1)) <= 2016:
            continue
        name = urllib.parse.unquote(parsed.path.rsplit("/", 1)[-1])
        if not re.search(r"\.(csv|xls|doc|pdf)$", name, re.I):
            continue
        candidates.append((url, f"raw/ine/ephc_comparable/{match.group(1)}/{name}"))
    for url, path in dict(candidates).items():
        fetch(url, path, page)


def eig():
    page = "https://www.ine.gov.py/microdato/encuesta-de-ingresos-y-gastos-y-condiciones-de-vida-2011-12"
    links = catalog("ine_eigcv_2011_12", page)
    selected = []
    for url in links:
        parsed = urllib.parse.urlsplit(url)
        if "/microdatos/register/eig/" not in parsed.path.lower():
            continue
        name = urllib.parse.unquote(parsed.path.rsplit("/", 1)[-1])
        if re.search(r"\.(dta|pdf)$", name, re.I):
            section = "microdatos" if name.lower().endswith(".dta") else "documentacion"
            selected.append((url, f"raw/ine/eigcv_2011_12/{section}/{name}"))
    for url, path in dict(selected).items():
        fetch(url, path, page)


def mef():
    page = "https://www.mef.gov.py/en/node/4605"
    links = catalog("mef_bonos", page)
    wanted = ("Resultado_de_subastas_2006-2026", "Bonos_del_Tesoro_en_circulacion")
    selected = []
    for url in links:
        name = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1])
        if name.lower().endswith(".xlsx") and any(x.lower() in name.lower() for x in wanted):
            selected.append((url, f"raw/mef/bonos/{name}"))
    for url, path in dict(selected).items():
        fetch(url, path, page)
    budget_page = "https://www.mef.gov.py/marco-legal/ley-de-presupuesto"
    catalog("mef_ley_presupuesto", budget_page)
    fetch("https://www.mef.gov.py/sites/default/files/2026-01/LEY_7609_PGN_2026_OCR.pdf",
          "raw/mef/pgn/LEY_7609_PGN_2026_OCR.pdf", budget_page)
    fetch("https://www.mef.gov.py/sites/default/files/2025-01/LEY%207408-2024%20-%20QUE%20APRUEBA%20EL%20PGN%20PARA%20EL%20EJERCICIO%20FISCAL%202025_1.pdf",
          "raw/mef/pgn/LEY_7408_PGN_2025.pdf", "https://www.mef.gov.py/es/node/2353")


def incoop():
    page = "https://www.incoop.gov.py/?page_id=10202"
    links = catalog("incoop_balances_cac", page)
    selected = []
    for url in links:
        name = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1])
        if (re.search(r"CAC.*\.(xlsx|xlsm|xls)$|Balances-CACs\.xlsx$", name, re.I)
                or name in ("Diciembre-2022.xlsx", "Diciembre-20211.xlsx")):
            selected.append((url, f"raw/incoop/cac_tipo_a/{name}"))
    for url, path in dict(selected).items():
        fetch(url, path, page)


def ips():
    page = "https://portal.ips.gov.py/sistemas/ipsportal/contenido.php?c=289"
    catalog("ips_anuarios", page)
    markup = (ROOT / "catalogs/ips_anuarios.html").read_text(encoding="utf-8", errors="replace")
    selected = []
    for year, url in re.findall(r'A&ntilde;o\s+(20\d{2})[^<]*<a href="(https?://[^"]+\.pdf)"', markup):
        parsed = urllib.parse.urlsplit(url)
        if parsed.netloc != "portal.ips.gov.py":
            continue
        name = parsed.path.rsplit("/", 1)[-1]
        selected.append((parsed._replace(scheme="https").geturl(),
                         f"raw/ips/anuarios/{name}"))
    for url, path in dict(selected).items():
        fetch(url, path, page)


def situfin():
    page = "https://www.mef.gov.py/es/situfin"
    links = catalog("mef_situfin", page)
    selected = []
    for url in links:
        name = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1])
        if (name.lower().endswith(".xlsx") and "ADMINISTRACI" in name.upper()
                and ("2003-2026" in name or "2003-2025" in name)):
            selected.append((url, f"raw/mef/situfin/{name}"))
    for url, path in dict(selected).items():
        fetch(url, path, page)


def wage():
    page_2025 = "https://www.mtess.gov.py/?p=30682"
    page_2026 = "https://www.mtess.gov.py/?p=36371"
    catalog("mtess_salario_2025", page_2025)
    catalog("mtess_salario_2026", page_2026)
    fetch("https://www.mtess.gov.py/wp-content/uploads/2026/07/Resolucion-MTESS-N%C2%B0-670-REGLAMENTACION-SALARIO-2026.pdf",
          "raw/mtess/salario_minimo/Resolucion-MTESS-N°-670-REGLAMENTACION-SALARIO-2026.pdf", page_2026)


def bcp():
    pages = {
        "bcp_formato_clasico": "https://www.bcp.gov.py/en/formato-clasico",
        "bcp_fx_operaciones": "https://www.bcp.gov.py/operaciones-cambiarias-del-bcp1",
        "bcp_ipc_metodologia": "https://www.bcp.gov.py/en/web/institucional/w/indice-de-precios-al-consumidor-ipc-metodologia-base-diciembre-2017",
        "bcp_cpm_comunicados": "https://www.bcp.gov.py/en/comunicados-del-cpm",
    }
    for name, url in pages.items():
        catalog(name, url)
    direct = [
        ("https://www.bcp.gov.py/documents/20117/213049/Metodolog%C3%ADa%2BIPC%2BBase%2BDiciembre%2B2017%281%29.pdf/8206389c-f533-40ba-b9aa-68f6dca5b04a?t=1750439877630", "raw/bcp/ipc/Metodologia_IPC_base_2017.pdf"),
        ("https://www.bcp.gov.py/documents/20117/2673193/Hist%C3%B3rico%2B-%2BOperaciones%2BCambiarias.xlsx/c9aea713-8f52-1428-d41a-42ac8c9b5d2e?t=1789499877388", "raw/bcp/fx/Historico_Operaciones_Cambiarias.xlsx"),
        ("https://www.bcp.gov.py/documents/20117/1356955/BOLB%2B122011.xls/75a05403-25c2-ed55-d095-b9b4e565d47e?t=1750443785083", "raw/bcp/boletines/BOLB_2011_12.xls"),
    ]
    for url, path in direct:
        fetch(url, path, "BCP official source pages")


def inventory():
    records = {}
    if (ROOT / "attempts.jsonl").exists():
        for line in (ROOT / "attempts.jsonl").read_text(encoding="utf-8").splitlines():
            record = json.loads(line)
            if record["status"] == "downloaded":
                records[record["path"]] = record
    columns = ["path", "source_page", "url", "final_url", "at_utc", "content_type", "bytes", "sha256", "hash_matches"]
    present = 0
    with (ROOT / "inventory.csv").open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=columns)
        writer.writeheader()
        for path, record in sorted(records.items()):
            source = ROOT / path
            if not source.exists():
                continue
            actual = sha256_file(source)
            present += 1
            writer.writerow({key: record.get(key, "") for key in columns[:-1]} |
                            {"hash_matches": actual == record["sha256"]})
    print("INVENTORY", present, "files", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["ine", "eig", "mef", "incoop", "ips", "situfin", "wage", "bcp", "all", "inventory"])
    mode = parser.parse_args().mode
    if mode in ("ine", "all"):
        ine()
    if mode in ("eig", "all"):
        eig()
    if mode in ("mef", "all"):
        mef()
    if mode in ("incoop", "all"):
        incoop()
    if mode in ("ips", "all"):
        ips()
    if mode in ("situfin", "all"):
        situfin()
    if mode in ("wage", "all"):
        wage()
    if mode in ("bcp", "all"):
        bcp()
    inventory()
