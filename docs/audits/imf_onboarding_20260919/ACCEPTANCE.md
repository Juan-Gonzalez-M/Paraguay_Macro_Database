# Aceptación y promoción IMF — 2026-09-19

## Veredicto

**PASS — 24 COLECCIONES IMF PROMOVIDAS**

El candidato retenido exacto
`database/candidates/accepted_for_review_20260919_203133.duckdb` fue revisado y
promovido mediante `promote_retained_candidate()`. No fue reconstruido durante
la promoción. IMTS bilateral permanece fuera del producto.

## Identidad autorizada

| Campo | Valor |
|---|---|
| SHA-256 | `e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616` |
| Bytes | `1081356288` |
| Build | `build:190aeb8320eaecd238c8d75b` |
| Attempt | `attempt:a9e93ae220bdfebea12073a4` |
| Source bundle | `release:42753eb4fa49d2dbedd73b07` |
| Schema | `49` |
| Scope | `schema49_imf_experimental_20260919` |
| Scope digest | `6b9238b3ed09bbb45d38cf82f228f9e34401765ed5a2fff67b62ae9658956d95` |
| Hechos canónicos activos | `3.814.646` |
| Identidades canónicas | `32.732` |

## Resultado IMF

- 24 dataflows preservados con identidad y vintage propios.
- 22.455 identidades en el snapshot IMF; 20.042 tienen observaciones numéricas.
- 2.558.738 observaciones numéricas preservadas.
- 101.095 valores textuales FSI en 195 identidades, sin coerción numérica.
- 192.910 filas de dimensiones publicadas, que cubren las 22.455 identidades.
- 2.558.289 observaciones disponibles en `explore.observations`; las 449
  restantes siguen preservadas y su exclusión por historia insuficiente es
  explícita.
- RSUI: 16 identidades y 6.992 observaciones exploratorias.
- WPFXI: 186 identidades y 34.541 observaciones exploratorias.
- Cero filas IMF en `research.series_catalog`.
- Cero filas IMTS ingeridas.

La comparación bidireccional confirmó que ningún hecho no IMF cambió. CDA,
TCN y LRM conservaron sus poblaciones. No se declararon concordancias IMF/BCP,
conversiones, imputaciones, agregaciones, empalmes ni transformaciones
implícitas.

## Promoción gobernada

El promotor revalidó hash, bytes, build, attempt, bundle, schema, scope y
poblaciones; comprobó el hash de la producción anterior; creó una copia de
promoción; hizo backup; efectuó la sustitución atómica; actualizó el sidecar; y
ejecutó su smoke test de solo lectura.

- SHA-256 anterior: `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4`.
- Backup: `database/backups/paraguay_macro_pilot_pre_swap_20260919_204354.duckdb`.
- Registro: `database/releases/promotions/build_190aeb8320eaecd238c8d75b_20260919_204408.json`.
- El candidato retenido permanece presente y coincide byte a byte con producción.

## Evidencia de verificación

La suite completa pasó. `verify_candidate.R` comprobó poblaciones, dimensiones,
aislamiento de `research.*`, exclusión de IMTS, continuidad CDA/TCN/LRM y cero
diferencias no IMF. `verify_public_views.R` comprobó las 141 vistas tanto en el
candidato como en la producción publicada desde conexiones nuevas de solo
lectura con `search_path` vacío. El sidecar y el registro de promoción coinciden
con el hash publicado.

## Limitaciones vigentes

Esta promoción habilita preservación, catálogo y exploración; no certifica
comparabilidad económica, aptitud para estimación ni equivalencia con BCP. RSUI y
WPFXI permanecen experimentales. Antes de redistribuir externamente los bytes
fuente o una base que los contenga debe cerrarse la matriz de licencia,
atribución y permiso por producto.
