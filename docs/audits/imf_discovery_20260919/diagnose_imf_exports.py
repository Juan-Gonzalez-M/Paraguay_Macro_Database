#!/usr/bin/env python3
"""Read-only structural census of the IMF CSV exports.

The received files contain an outer one-column CSV serialization.  Each outer
record is itself a comma-delimited CSV record.  This script preserves that
distinction, reports every parse irregularity, and never rewrites source bytes.
Only Python's standard library is used.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


PERIOD_RE = re.compile(r"^(?:\d{4}|\d{4}-Q[1-4]|\d{4}-M(?:0[1-9]|1[0-2])|\d{4}-S[12])$")
DATASET_RE = re.compile(r"^(?P<agency>[^:]+):(?P<dataflow>[^()]+)\((?P<version>[^()]+)\)$")
NUMERIC_RE = re.compile(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?$")


def decode_source(raw: bytes) -> tuple[str, str, bool]:
    bom = raw.startswith(b"\xef\xbb\xbf")
    try:
        return raw.decode("utf-8-sig"), "UTF-8", bom
    except UnicodeDecodeError:
        return raw.decode("cp1252"), "Windows-1252", bom


def csv_row(text: str) -> list[str]:
    return next(csv.reader([text], delimiter=",", quotechar='"', strict=True))


def compact(values: set[str]) -> str:
    return " | ".join(sorted(v for v in values if v))


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def inspect(path: Path) -> tuple[dict, list[dict], list[dict], list[dict], list[dict]]:
    raw = path.read_bytes()
    text, encoding, bom = decode_source(raw)
    physical_lines = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
    outer_reader = csv.reader(io.StringIO(text, newline=""), delimiter=";", quotechar='"', strict=True)
    outer_records: list[tuple[int, int, list[str]]] = []
    prior_line = 0
    outer_error = ""
    try:
        for row in outer_reader:
            outer_records.append((prior_line + 1, outer_reader.line_num, row))
            prior_line = outer_reader.line_num
    except csv.Error as exc:
        outer_error = f"physical_line={outer_reader.line_num}: {exc}"

    outer_widths = Counter(len(row) for _, _, row in outer_records)
    # The export envelope is a quoted inner CSV payload followed, in some
    # files/records, by empty semicolon-delimited fields.
    malformed_outer = sum(1 for _, _, row in outer_records if not row)
    inner_records: list[tuple[int, int, list[str]]] = []
    inner_errors: list[dict] = []
    payloads: list[tuple[int, int, str]] = []
    for record_no, (start, end, outer) in enumerate(outer_records, start=1):
        if not outer:
            inner_errors.append({"file": path.name, "logical_record": record_no,
                                 "physical_start": start, "physical_end": end,
                                 "error": f"outer_width={len(outer)}"})
            continue
        # Semicolons occurring in an inner quoted field are exposed as outer
        # separators by this export. Joining the outer pieces restores them;
        # terminal envelope separators are empty and are removed only at EOF.
        payloads.append((start, end, ";".join(outer).rstrip(";")))

    if payloads:
        try:
            header_row = csv_row(payloads[0][2])
            inner_records.append((payloads[0][0], payloads[0][1], header_row))
        except (csv.Error, StopIteration) as exc:
            inner_errors.append({"file": path.name, "logical_record": 1,
                                 "physical_start": payloads[0][0], "physical_end": payloads[0][1],
                                 "error": f"inner_header_parse: {exc}"})
            header_row = []
        expected = len(header_row)
        i = 1
        while i < len(payloads):
            start, end, payload = payloads[i]
            consumed = 1
            row = None
            last_error = None
            # Four metadata-rich exports place a physical newline between
            # adjacent inner fields. Greedily restore the omitted comma when
            # the fragment is unparsable or narrower than the header.
            while row is None:
                try:
                    candidate = csv_row(payload)
                    if not expected or len(candidate) >= expected:
                        row = candidate
                        break
                except (csv.Error, StopIteration) as exc:
                    last_error = exc
                if i + consumed >= len(payloads):
                    break
                next_start, next_end, next_payload = payloads[i + consumed]
                if next_payload.startswith("IMF."):
                    break
                payload += "," + next_payload
                end = next_end
                consumed += 1
            try:
                if row is None:
                    if last_error:
                        raise last_error
                    row = csv_row(payload)
                inner_records.append((start, end, row))
            except (csv.Error, StopIteration) as exc:
                inner_errors.append({"file": path.name, "logical_record": i + 1,
                                     "physical_start": start, "physical_end": end,
                                     "error": f"inner_parse: {exc}"})
            i += consumed

    if not inner_records:
        raise RuntimeError(f"No parseable records in {path}")
    header = inner_records[0][2]
    header_width = len(header)
    header_index = {name: i for i, name in enumerate(header)}
    period_indices = [i for i, name in enumerate(header) if PERIOD_RE.match(name)]
    dimension_indices = [i for i in range(header_width) if i not in period_indices]
    width_counts = Counter(len(row) for _, _, row in inner_records)
    irregular = []
    multiline = 0
    datasets: Counter[str] = Counter()
    series_codes: Counter[str] = Counter()
    observations = 0
    nonnumeric = Counter()
    dimensions: dict[str, set[str]] = defaultdict(set)
    coverage: dict[tuple[str, str, str], dict] = {}
    metadata_records = 0

    for logical_no, (start, end, row) in enumerate(inner_records[1:], start=2):
        if end > start:
            multiline += 1
        if len(row) != header_width:
            irregular.append({"file": path.name, "logical_record": logical_no,
                              "physical_start": start, "physical_end": end,
                              "actual_columns": len(row), "expected_columns": header_width})
        padded = row[:header_width] + [""] * max(0, header_width - len(row))
        dataset = padded[header_index.get("DATASET", -1)] if "DATASET" in header_index else ""
        series = padded[header_index.get("SERIES_CODE", -1)] if "SERIES_CODE" in header_index else ""
        measure = padded[header_index.get("OBS_MEASURE", -1)] if "OBS_MEASURE" in header_index else ""
        country = padded[header_index.get("COUNTRY", -1)] if "COUNTRY" in header_index else ""
        freq_idx = header_index.get("FREQUENCY", header_index.get("FREQ", -1))
        frequency = padded[freq_idx] if freq_idx >= 0 else ""
        if dataset:
            datasets[dataset] += 1
        if series:
            series_codes[series] += 1
        if measure and measure != "OBS_VALUE":
            metadata_records += 1
        for i in dimension_indices:
            if i < len(padded) and padded[i]:
                dimensions[header[i]].add(padded[i])
        for i in period_indices:
            if i >= len(row) or row[i] == "":
                continue
            value = row[i]
            observations += 1
            if measure == "OBS_VALUE" and not NUMERIC_RE.match(value):
                nonnumeric[value] += 1
            key = (country, frequency, dataset)
            item = coverage.setdefault(key, {"file": path.name, "country": country,
                                             "frequency": frequency, "dataset": dataset,
                                             "period_min": header[i], "period_max": header[i],
                                             "nonempty_cells": 0, "series_codes": set()})
            item["period_min"] = min(item["period_min"], header[i])
            item["period_max"] = max(item["period_max"], header[i])
            item["nonempty_cells"] += 1
            if series:
                item["series_codes"].add(series)

    dataset_rows = []
    for value, rows in sorted(datasets.items()):
        match = DATASET_RE.match(value)
        dataset_rows.append({"file": path.name, "dataset": value,
                             "agency": match.group("agency") if match else "",
                             "dataflow": match.group("dataflow") if match else "",
                             "version": match.group("version") if match else "",
                             "records": rows})
    dimension_rows = [{"file": path.name, "dimension": name,
                       "distinct_count": len(values), "values": compact(values)}
                      for name, values in dimensions.items()]
    coverage_rows = []
    for value in coverage.values():
        value = dict(value)
        value["series_count"] = len(value.pop("series_codes"))
        coverage_rows.append(value)

    record = {
        "file": path.name,
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "encoding": encoding,
        "utf8_bom": bom,
        "line_endings": "CRLF" if b"\r\n" in raw else "LF",
        "physical_lines": physical_lines,
        "logical_records": len(outer_records),
        "outer_widths": json.dumps(dict(sorted(outer_widths.items()))),
        "outer_malformed_records": malformed_outer,
        "outer_parse_error": outer_error,
        "header_columns": header_width,
        "dimension_columns": len(dimension_indices),
        "period_columns": len(period_indices),
        "period_header_min": min((header[i] for i in period_indices), default=""),
        "period_header_max": max((header[i] for i in period_indices), default=""),
        "data_records": max(0, len(inner_records) - 1),
        "distinct_series_codes": len(series_codes),
        "duplicate_series_code_records": sum(n - 1 for n in series_codes.values() if n > 1),
        "potential_observations": observations,
        "metadata_records": metadata_records,
        "multiline_records": multiline,
        "inner_widths": json.dumps(dict(sorted(width_counts.items()))),
        "irregular_inner_records": len(irregular),
        "inner_parse_errors": len(inner_errors),
        "nonnumeric_observation_tokens": sum(nonnumeric.values()),
        "nonnumeric_token_values": json.dumps(nonnumeric.most_common(20), ensure_ascii=False),
        "countries": compact(dimensions.get("COUNTRY", set())),
        "frequencies": compact(dimensions.get("FREQUENCY", dimensions.get("FREQ", set()))),
        "units": compact(dimensions.get("UNIT", set())),
        "scales": compact(dimensions.get("SCALE", set())),
        "transformations": compact(set().union(*(dimensions.get(k, set()) for k in
            ("TYPE_OF_TRANSFORMATION", "DATA_TRANSFORMATION", "TRANSFORMATION"))))
    }
    issues = inner_errors + irregular
    return record, dataset_rows, dimension_rows, coverage_rows, issues


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    inventory, datasets, dimensions, coverage, issues = [], [], [], [], []
    for path in sorted(args.input.glob("*.csv")):
        result = inspect(path)
        inventory.append(result[0]); datasets.extend(result[1]); dimensions.extend(result[2])
        coverage.extend(result[3]); issues.extend(result[4])
    write_csv(args.output / "file_inventory.csv", inventory, list(inventory[0]))
    write_csv(args.output / "dataset_versions.csv", datasets,
              ["file", "dataset", "agency", "dataflow", "version", "records"])
    write_csv(args.output / "dimension_values.csv", dimensions,
              ["file", "dimension", "distinct_count", "values"])
    write_csv(args.output / "country_frequency_coverage.csv", coverage,
              ["file", "country", "frequency", "dataset", "period_min", "period_max",
               "nonempty_cells", "series_count"])
    issue_fields = ["file", "logical_record", "physical_start", "physical_end",
                    "actual_columns", "expected_columns", "error"]
    for row in issues:
        for field in issue_fields:
            row.setdefault(field, "")
    write_csv(args.output / "parse_issues.csv", issues, issue_fields)
    summary = {
        "files": len(inventory), "bytes": sum(r["bytes"] for r in inventory),
        "data_records": sum(r["data_records"] for r in inventory),
        "distinct_series_rows_sum": sum(r["distinct_series_codes"] for r in inventory),
        "potential_observations": sum(r["potential_observations"] for r in inventory),
        "outer_malformed_records": sum(r["outer_malformed_records"] for r in inventory),
        "irregular_inner_records": sum(r["irregular_inner_records"] for r in inventory),
        "inner_parse_errors": sum(r["inner_parse_errors"] for r in inventory),
        "multiline_records": sum(r["multiline_records"] for r in inventory),
    }
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
