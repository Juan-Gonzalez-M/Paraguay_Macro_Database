# Aceptación y promoción CDA + TCN — 2026-09-19

## Veredicto

**PASS — CDA Y TCN PROMOVIDOS**

El candidato retenido exacto
`database/candidates/accepted_for_review_20260919_103853.duckdb` fue aceptado y
promovido mediante `promote_retained_candidate()`. No fue reconstruido. Los
archivos incorporados posteriormente en `input/current/IMF_Data/` no estaban
registrados, no pertenecían al scope gobernado y no fueron ingeridos.

## Identidad autorizada

| Campo | Valor |
|---|---|
| SHA-256 del candidato y nueva producción | `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4` |
| Bytes | `497823744` |
| Build | `build:6928154663966c1f7d0ee63d` |
| Attempt | `attempt:1441a2cb2abc7fa63b773cd0` |
| Source bundle | `release:a8120d5735c5ec0d32eddf42` |
| Schema | `46` |
| Scope | `schema46_cda_tcn_provisional_20260919` |
| Scope digest | `f0af2f06ba1e6fd342a9e89ea472385c343e201e690d6206b105452829dfa8b7` |
| Hechos canónicos | `1.255.908` |
| Identidades canónicas | `12.265` |

## Resultado económico y de reconciliación

- CDA: 421 identidades, 21.839 hechos y cero identidades `UNLABELED`.
- La migración CDA registra 421 identidades idénticas, 35 fusionadas y 15
  eliminadas conforme a las decisiones documentadas del dueño de la fuente.
- TCN: dos identidades continuas (`Compra`, `Venta`), 3.502 hechos cada una,
  unidad `PYG_PER_USD`, moneda `PYG/USD`, escala 1.
- Los 4.156 tokens `ND` permanecen en la evidencia cruda y no se imputan ni se
  convierten en cero.
- CDA y TCN tienen balance de celdas, reutilización, celdas no mapeadas, celdas
  no clasificadas y defectos de parser iguales a cero.
- La comparación bidireccional contra el producto anterior dio cero diferencias
  para hechos ajenos a CDA y TCN.
- LRM permanece en 940 identidades y 10.334 hechos.
- CDA y TCN permanecen fuera de `research.*` y no se presentan como certificados.

## Promoción gobernada

El promotor verificó el hash de producción anterior, adquirió el bloqueo,
revalidó hash, bytes, build, attempt, bundle, schema, scope y poblaciones del
candidato, creó una copia de promoción byte a byte, hizo backup del producto
anterior, realizó la sustitución atómica, actualizó sidecar y manifest, escribió
el registro durable y ejecutó su smoke test de solo lectura. No fue necesario
rollback.

- SHA-256 anterior: `11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876`.
- SHA-256 nuevo: `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4`.
- Backup: `database/backups/paraguay_macro_pilot_pre_swap_20260919_154550.duckdb`.
- Registro: `database/releases/promotions/build_6928154663966c1f7d0ee63d_20260919_154557.json`.
- El candidato retenido permanece presente y conserva su hash.

## Smoke test posterior independiente

Una nueva conexión de solo lectura verificó el build y bundle activos, estado
`accepted`, cero errores de release, las poblaciones CDA/TCN/LRM anteriores,
cero fuentes IMF ingeridas y cero filas CDA/TCN en `research.*`. Las 141 vistas
públicas enlazaron con `search_path` vacío y cero fallos.

## Evidencia de pruebas y limitaciones

Las pruebas focalizadas CDA, TCN, scope, procedencia y missingness; la capa
exploratoria; el smoke completo del pipeline; y las verificaciones ejecutables
`verify_candidate.R` y `verify_public_views.R` pasaron para este candidato. La
suite completa conserva únicamente el fallo ambiental conocido: seis paquetes
R cargados directamente difieren de `renv.lock`. No se instalaron paquetes.

La URL exacta, timestamp verificable de adquisición, fecha oficial de
publicación, licencia y permiso de redistribución del archivo TCN siguen sin
evidencia independiente. Las tasas y volúmenes CDA no reciben interpretaciones
adicionales más allá de las decisiones documentadas. El siguiente workstream
recomendado es el onboarding aislado de las fuentes IMF, empezando por
preservación, procedencia y un piloto de panel regional; no forma parte de esta
promoción.
