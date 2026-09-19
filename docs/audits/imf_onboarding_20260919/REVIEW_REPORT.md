# Revisión del candidato IMF — 2026-09-19

## Veredicto previo a promoción

**PASS — candidato apto para promoción gobernada.**

Se revisó el archivo retenido `accepted_for_review_20260919_203133.duckdb`,
SHA-256 `e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616`.
El candidato es esquema 49, tiene decisión `accepted`, cero errores y 37
advertencias. Ninguna advertencia está asociada a una fuente IMF; corresponden a
controles ya visibles del producto nacional y no fueron debilitadas ni eximidas.

## Población incorporada

- 24 dataflows IMF, cada uno con `source_id`, `DATASET`, versión y vintage propios.
- 22.455 identidades de preservación, incluidas las medidas textuales de FSI.
- 2.558.738 observaciones numéricas de 20.042 identidades con valores.
- 101.095 valores textuales de metadatos FSI en 195 identidades.
- 192.910 filas de dimensiones publicadas, 43 nombres de dimensión y cobertura
  de las 22.455 identidades preservadas.
- 2.558.289 observaciones en `explore.observations`. Las 449 observaciones que no
  aparecen en esa interfaz pertenecen a 257 series con historia escalar
  insuficiente; permanecen completas en staging y tienen exclusión explícita.
- RSUI: 16 identidades y 6.992 observaciones exploratorias.
- WPFXI: 186 identidades y 34.541 observaciones exploratorias.

IMTS bilateral no fue ingerido. Ninguna serie IMF fue admitida a `research.*` y
no se declaró equivalencia con una serie BCP. RSUI se conserva como indicador de
investigación y WPFXI como conjunto de datos de documento de trabajo, datos
públicos y proxies; no se presentan como estadísticas oficiales homogéneas.

## Integridad y comparabilidad

La comparación bidireccional contra producción dio cero diferencias en los
hechos no IMF. CDA permanece en 421 identidades, TCN en dos y LRM en 940. Los
valores, períodos publicados, coordenadas, frecuencia, unidad, escala,
transformación y dimensiones IMF permanecen separados. No se aplicaron
conversiones, imputaciones, desestacionalizaciones, agregaciones ni empalmes.

La similitud nominal entre dataflows y fuentes nacionales no se interpreta como
equivalencia económica. Los productos agregados mundiales/regionales conservan
su identidad; los metadatos FSI no se coercionan a números; las series con poca
historia se preservan aunque no sean expuestas por la interfaz escalar general.

## Evidencia técnica

La suite completa pasó. La única advertencia de pruebas fue el fixture deliberado
de ZIP corrupto que valida aislamiento de fallos. El entorno coincide con
`renv.lock`. `verify_candidate.R` y `verify_public_views.R` verifican el objeto
exacto; las 141 vistas enlazan desde una conexión nueva, de solo lectura y con
`search_path` vacío.

## Limitaciones conservadas

La licencia y el permiso de redistribución por producto siguen requiriendo una
matriz jurídica documentada antes de distribuir externamente los bytes fuente o
un artefacto que los contenga. La promoción local no certifica comparabilidad,
concordancias BCP, aptitud econométrica ni admisión a `research.*`.
