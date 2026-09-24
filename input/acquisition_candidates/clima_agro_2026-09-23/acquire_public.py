"""Download published source bytes into this acquisition staging directory.

This script does not parse, transform, or register sources in the research DB.
"""

import argparse
import csv
import hashlib
import html.parser
import json
import os
import re
import threading
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent
USER_AGENT = "ParaguayMacroResearch/1.0 (public-data availability check)"
MANIFEST_LOCK = threading.Lock()


class Links(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.hrefs.append(href)


def download(url, relative_path):
    target = ROOT / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    def record_file(status):
        digest = hashlib.sha256()
        with target.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
        record = {
            "retrieved_utc": datetime.fromtimestamp(target.stat().st_mtime, timezone.utc).isoformat(),
            "url": url,
            "path": relative_path,
            "bytes": target.stat().st_size,
            "sha256": digest.hexdigest(),
            "status": status,
        }
        with MANIFEST_LOCK:
            with (ROOT / "downloads.jsonl").open("a", encoding="utf-8") as manifest:
                manifest.write(json.dumps(record, ensure_ascii=False) + "\n")

    if target.exists() and target.stat().st_size > 0:
        record_file("already_present")
        return "present"
    partial = target.with_name(target.name + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=90) as response, partial.open("wb") as out:
            while chunk := response.read(1024 * 1024):
                out.write(chunk)
        if partial.stat().st_size == 0:
            raise ValueError("empty response")
        os.replace(partial, target)
        record_file("downloaded")
        return f"downloaded {target.stat().st_size} bytes"
    except Exception as error:
        partial.unlink(missing_ok=True)
        with MANIFEST_LOCK:
            with (ROOT / "failures.jsonl").open("a", encoding="utf-8") as failures:
                failures.write(json.dumps({"url": url, "path": relative_path, "error": str(error)}, ensure_ascii=False) + "\n")
        return f"ERROR {error}"


def from_catalog(catalog_path, base_url, subdir):
    parser = Links()
    parser.feed((ROOT / catalog_path).read_text(encoding="utf-8"))
    seen = set()
    for href in parser.hrefs:
        url = urllib.parse.urljoin(base_url, href)
        path = urllib.parse.urlsplit(url).path
        if not re.search(r"\.(csv|xlsx?|zip|pdf)$", path, re.I) or url in seen:
            continue
        seen.add(url)
        filename = urllib.parse.unquote(path.rsplit("/", 1)[-1])
        print(subdir, filename, download(url, f"{subdir}/{filename}"), flush=True)


def chirps_monthly():
    base = "https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/latam/tifs/"
    parser = Links()
    parser.feed((ROOT / "chc/monthly_latam_index.html").read_text(encoding="utf-8"))
    names = sorted({href for href in parser.hrefs if re.fullmatch(r"chirps-v3\.0\.\d{4}\.\d{2}\.tif", href)})
    print(f"CHIRPS monthly files listed: {len(names)}", flush=True)
    def fetch_one(name):
        return name, download(base + name, f"chc/monthly_latam/{name}")

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(fetch_one, name) for name in names]
        for future in as_completed(futures):
            name, result = future.result()
            print(name, result, flush=True)


MAG_CATALOGS = {
    "historico_tres_departamentos": "https://www.datos.gov.py/dataset/datos-hist%C3%B3ricos-agropecuarios-dpto-de-misiones-itap%C3%BAa-y-caazap%C3%A1-per%C3%ADodo-2009%E2%80%932024",
    "mercado_abasto": "https://www.datos.gov.py/dataset/hist%C3%B3rico-de-precios-mayoristas-volumen-de-ingreso-y-origen-de-rubros-hort%C3%ADcolas-y-av%C3%ADcolas",
    "arroz_2020_2025": "https://www.datos.gov.py/dataset/producci%C3%B3n-del-arroz-y-sus-derivados-2020-2025",
    "sesamo_2018_2024": "https://www.datos.gov.py/dataset/s%C3%A9samo-en-paraguay-per%C3%ADodo-2018-2024",
    "cultivos_tres_departamentos": "https://www.datos.gov.py/dataset/datos-agropecuarios-y-superficie-por-cultivo-caazap%C3%A1-itap%C3%BAa-y-misiones",
    "censo_agropecuario_2022": "https://www.datos.gov.py/dataset/datos-de-censo-agropecuario-nacional-2022",
    "algodon_historico": "https://www.datos.gov.py/dataset/series-hist%C3%B3ricas-del-algod%C3%B3n-1930-2026",
    "can_2022": "https://www.datos.gov.py/dataset/censo-agropecuario-nacional-can-2022",
}

EXTRA_URLS = {
    "noaa/meiv2.csv": "https://psl.noaa.gov/data/correlation/meiv2.csv",
    "noaa/oni.ascii.txt": "https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt",
    "noaa/RONI.ascii.txt": "https://www.cpc.ncep.noaa.gov/data/indices/RONI.ascii.txt",
    "usda/paraguay_crop_calendar_2024_report.pdf": "https://ipad.fas.usda.gov/highlights/2024/10/Paraguay/index.pdf",
    "iri/enso_forecast_archive.html": "https://iri.columbia.edu/our-expertise/climate/forecasts/enso/archive/",
    "iri/enso_forecast_2012_10.pdf": "https://iri.columbia.edu/our-expertise/climate/forecasts/enso/archive/201210/ENSO_Quick_Look.pdf",
    "dmh/anuario_2025_page.html": "https://www.meteorologia.gov.py/publish/anuario-2025/",
    "dmh/anuario_climatologico_2022.pdf": "https://www.meteorologia.gov.py/wp-content/uploads/2023/05/Anuario_climatologico_2022.pdf",
    "dmh/servicio_publico.html": "https://www.meteorologia.gov.py/servicio-publico/",
    "faostat/Production_Crops_Livestock_E_All_Data_Normalized.zip": "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data_(Normalized).zip",
    "copernicus/era5_land_dataset_page.html": "https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land",
}

GEOGRAPHY_URLS = {
    "ine/DEPARTAMENTOS_PY_CNPV2022.geojson": "https://www.datos.gov.py/sites/default/files/DEPARTAMENTOS_PY_CNPV2022.geojson",
    "ine/DISTRITOS_PY_CNPV2022.geojson": "https://www.datos.gov.py/sites/default/files/DISTRITOS_PY_CNPV2022.geojson",
    "usda/grain_feed_annual_paraguay_2025.pdf": "https://apps.fas.usda.gov/newgainapi/api/Report/DownloadReportByFileName?fileName=Grain+and+Feed+Annual_Buenos+Aires_Paraguay_PA2025-0002.pdf",
    "dmh/niveles_rio_actuales.html": "https://meteorologia.gov.py/nivel-rio/indexconvencional.php",
    "fao/gaez_portal_page.html": "https://www.fao.org/land-water/resources/tools/databases/gaez/en",
}

RIVER_URLS = {
    "dmh/river_asuncion_detail.html": "https://meteorologia.gov.py/nivel-rio/vermas_convencional.php?code=2000086218",
    "dmh/river_pilar_detail.html": "https://meteorologia.gov.py/nivel-rio/vermas_convencional.php?code=2000086255",
}


def finalize_inventory():
    latest = {}
    for line in (ROOT / "downloads.jsonl").read_text(encoding="utf-8").splitlines():
        entry = json.loads(line)
        latest[entry["path"]] = entry
    rows = []
    for relative_path, entry in sorted(latest.items()):
        source = ROOT / relative_path
        if not source.exists():
            entry.update({"hash_matches": False, "format_check": "missing"})
        else:
            digest = hashlib.sha256()
            with source.open("rb") as handle:
                prefix = handle.read(16)
                digest.update(prefix)
                while chunk := handle.read(1024 * 1024):
                    digest.update(chunk)
            entry["hash_matches"] = digest.hexdigest() == entry["sha256"]
            suffix = source.suffix.lower()
            if suffix in {".csv", ".txt", ".html", ".geojson", ".xls"}:
                entry["format_check"] = "not_checked"
            else:
                entry["format_check"] = (
                    "valid_magic" if (
                        suffix == ".pdf" and prefix.startswith(b"%PDF")
                        or suffix in {".zip", ".xlsx"} and prefix.startswith(b"PK")
                        or suffix == ".tif" and prefix[:4] in {b"II*\x00", b"MM\x00*"}
                    ) else "unexpected_magic"
                )
        rows.append(entry)
    columns = ["path", "url", "retrieved_utc", "bytes", "sha256", "hash_matches", "format_check", "status"]
    with (ROOT / "inventory.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=columns)
        writer.writeheader()
        writer.writerows({key: row.get(key, "") for key in columns} for row in rows)
    print(f"files={len(rows)} bytes={sum(row['bytes'] for row in rows)} "
          f"hash_failures={sum(not row['hash_matches'] for row in rows)} "
          f"unexpected_format={sum(row['format_check'] == 'unexpected_magic' for row in rows)}")


if __name__ == "__main__":
    cli = argparse.ArgumentParser()
    cli.add_argument("mode", choices=["mag2020", "mag-more", "chirps-monthly", "extras", "geography", "river", "direct", "finalize"])
    cli.add_argument("--url")
    cli.add_argument("--path")
    args = cli.parse_args()
    if args.mode == "mag2020":
        from_catalog(
            "mag/catalogo_cultivos_2020_2021.html",
            "https://www.datos.gov.py/dataset/superficie-y-producci%C3%B3n-por-a%C3%B1o-agr%C3%ADcola-seg%C3%BAn-cultivo-periodo-2020-al-2021",
            "mag/cultivos_2020_2021",
        )
    elif args.mode == "mag-more":
        for name, url in MAG_CATALOGS.items():
            catalog = f"mag/catalogo_{name}.html"
            print(catalog, download(url, catalog), flush=True)
            if (ROOT / catalog).exists():
                from_catalog(catalog, url, f"mag/{name}")
    elif args.mode == "direct":
        if not args.url or not args.path:
            cli.error("direct requires --url and --path")
        print(args.path, download(args.url, args.path), flush=True)
    elif args.mode == "extras":
        for path, url in EXTRA_URLS.items():
            print(path, download(url, path), flush=True)
    elif args.mode == "geography":
        for path, url in GEOGRAPHY_URLS.items():
            print(path, download(url, path), flush=True)
    elif args.mode == "river":
        for path, url in RIVER_URLS.items():
            print(path, download(url, path), flush=True)
    elif args.mode == "finalize":
        finalize_inventory()
    else:
        chirps_monthly()
