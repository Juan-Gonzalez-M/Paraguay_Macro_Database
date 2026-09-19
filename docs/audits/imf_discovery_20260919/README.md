# Paquete de auditoría IMF

- `REPORT.md`: diagnóstico, diseño y decisiones pendientes.
- `IMPLEMENTATION_STATUS.md`: decisiones aprobadas y estado del parser piloto.
- `diagnose_imf_exports.py`: censo reproducible, sólo lectura sobre las fuentes.
- `file_inventory.csv`: nombre, bytes, SHA-256, encoding, estructura y conteos.
- `dataset_versions.csv`: `DATASET`, agencia, dataflow y versión.
- `dimension_values.csv`: valores distintos de cada dimensión por archivo.
- `country_frequency_coverage.csv`: cobertura efectiva por país/agregado y frecuencia.
- `economic_classification.csv`: clasificación económica y capa recomendada.
- `parse_issues.csv`: incidencias no resueltas; sólo contiene encabezado cuando es cero.
- `summary.json`: totales del censo.

Reproducción desde la raíz del repositorio:

```text
python3 docs/audits/imf_discovery_20260919/diagnose_imf_exports.py \
  --input input/current/IMF_Data \
  --output docs/audits/imf_discovery_20260919
```

El script usa únicamente la biblioteca estándar de Python y no escribe en
`input/current/IMF_Data`.
