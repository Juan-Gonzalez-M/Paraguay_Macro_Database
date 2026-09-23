# Descubrimiento y diseño: MEF Administración Central e INE EPHC

Fecha del diagnóstico: 2026-09-19. Alcance: inspección reproducible y de solo lectura. No se registró ninguna fuente, no se modificó la base publicada, no se construyó candidato y no se promovió nada.

## Estado productivo verificado

El workspace y el `git` toplevel son `Paraguay_Macro_Database`. La producción fue comprobada independientemente en el archivo, sidecar, `outputs/build_manifest.json`, registro de promoción y tablas internas de DuckDB. Todos coinciden en SHA-256 `e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616`, 1.081.356.288 bytes, esquema 49, build `build:190aeb8320eaecd238c8d75b`, attempt `attempt:a9e93ae220bdfebea12073a4` y bundle `release:42753eb4fa49d2dbedd73b07`. `audit.active_data_release` apunta a ese build/bundle; la decisión es `accepted`, el attempt terminó `completed_with_warnings`, con 48 fuentes, cero errores y 37 warnings. El registro durable es `database/releases/promotions/build_190aeb8320eaecd238c8d75b_20260919_204408.json`. La aceptación IMF coincide. No apareció una interacción que justificara reabrir CDA, TCN, LRM o IMF.

## Inventario exacto

| Fuente | Ruta | Bytes | SHA-256 | Formato | Propiedades OOXML |
|---|---|---:|---|---|---|
| MEF | `input/current/MEFP 2001 ADMINISTRACIÓN CENTRAL 2003-2026 serie mensual.xlsx` | 320.984 | `0b6be44e1e243a43eeacafbe4da06925f49b06e0fca1df3d150c1d40d103c2a7` | XLSX/OOXML | creador `DGPMF`; última modificación por `Luis Alberto Benítez`; propiedad modified `2026-09-11T17:35:08Z` |
| INE | `input/current/Anexo_EPHC_2017-2026.xlsx` | 545.980 | `04bf76173d73c5e99e7ecea6f64bd1284adc6dfefbacf9815a9a3b4003c7311d` | XLSX/OOXML | creadora/modificadora `Griselda Ramirez`; propiedad modified `2026-07-23T17:57:14Z` |

Las fechas del filesystem son evidencia operativa local, no fecha oficial ni vintage. Ninguno de los dos hashes aparece en los contratos, manifests, archivo inmutable o base publicada. La fecha/vintage oficial sigue sin establecerse.

## MEF: diagnóstico estructural y económico

Una hoja visible, `Serie`, dimensión declarada `A3:JZ132`; el rango con contenido materializado es 109 x 286. Publica 284 meses consecutivos de enero de 2003 a agosto de 2026, 84 filas con valores y 23.676 celdas numéricas potenciales. Hay 568 celdas con fórmula/caché, principalmente resultados fiscales y partidas adicionales; deben preservarse como cálculos publicados, con fórmula y valor cacheado, no confundirse con datos fuente primarios. El XML marca 15 filas ocultas, que incluyen partidas con datos; no pueden descartarse. No hay celdas combinadas ni columnas ocultas.

El propio libro dice `ESTADO DE OPERACIONES DEL GOBIERNO - Administración Central`, `EJECUCIÓN AÑO 2003 - 2026*` y `(En miles de millones de guaraníes)`. Por tanto, “Administración Central” es el subsector institucional declarado por el editor para este estado de operaciones, no una etiqueta suficiente para equipararlo automáticamente con Gobierno Central, Gobierno General, presupuesto de la Administración Central o cobertura MEF de otra publicación. El texto `2001` solo aparece en el nombre externo del archivo: no aparece en hojas, títulos, notas, strings compartidos ni propiedades. Puede ser un código de cuadro/serie o un fragmento de nombre, pero no hay evidencia para asignarle significado económico.

Contenido: ingreso total; ingresos tributarios y desglose; contribuciones sociales; donaciones; otros ingresos; gasto total **obligado** y desglose; balance operativo neto; adquisición neta de activos no financieros; préstamo/endeudamiento neto; adquisición neta de activos financieros; incurrimiento neto de pasivos; deuda flotante; variación de caja; diferencia de período de registro; gasto corriente primario y resultado primario. No publica columnas separadas de presupuesto inicial, vigente/modificado o pagado: la etapa explícita del gasto total es `obligado`; contribuciones sociales se registran en base devengado. No se observan clasificaciones institucional, funcional, por objeto del gasto o fuente de financiamiento separadas; la jerarquía visible corresponde a un estado de operaciones con clasificación económica/fiscal.

Unidad y escala: guaraníes corrientes, `miles de millones`; no se declara ajuste estacional ni precios constantes. Son flujos mensuales y partidas de financiamiento/variación; no deben tratarse como acumulados ni derivarse meses. El libro marca 2025 y 2026 como preliminares y advierte que ingresos tributarios serán distribuidos posteriormente. Esto implica revisabilidad y posible cambio futuro de composición.

Calidad/comparabilidad: no hay notas explícitas que documenten rupturas 2003–2026. Sí hay señales que requieren revisión: jerarquía expresada mediante sangría significativa; filas ocultas con datos; fórmulas compartidas; valores negativos legítimos; fuerte volatilidad de algunas subpartidas; y una cobertura incompleta de 2026. La ausencia de una nota no prueba continuidad de clasificación o metodología. Deben compararse identidades, sumas y fórmulas por regímenes/años antes de afirmar continuidad.

## INE EPHC: diagnóstico estructural y estadístico

El libro tiene 16 hojas: 15 tablas visibles y `Hoja2` oculta y vacía. Hay 581 rangos combinados, usados en encabezados multinivel; cero filas/columnas ocultas con datos. La cobertura efectiva es trimestral, 2017-Q1 a 2026-Q2, no anual, semestral ni móvil. Los cuadros de 40 columnas usan período por columna; los de 116 usan período por grupos de tres (Total/Hombres/Mujeres o tres medidas de formalidad). El inventario detallado de dimensiones, fórmulas, merges y conteos está en los CSV del paquete.

Se identificaron 846 series candidatas y 27.212 observaciones numéricas potenciales en regiones de datos. Son conteos diagnósticos, no identidades productivas. Los dominios son: tasas laborales; características de la población ocupada; sector económico; categoría ocupacional; tamaño de empresa; horas habituales; experiencia; promedio de años de estudio; ingresos mensuales y por hora; ingresos por sector y ocupación; población total/clasificación laboral; formalidad; y promedio de horas. No hay cuadros de hogares ni pobreza en este libro.

Las medidas mezclan, explícitamente y por cuadro, estimaciones de cantidades poblacionales, porcentajes/tasas, promedios de años, promedios de horas e ingresos corrientes en miles de guaraníes. No se publican errores estándar, intervalos de confianza ni coeficientes de variación. Las celdas con valores entre paréntesis son estimaciones basadas en menos de 30 casos muestrales y deben portar una bandera de insuficiencia muestral; no son valores suprimidos. El token `-` aparece principalmente donde un concepto no está disponible/no aplica para períodos anteriores, y requiere clasificación gobernada antes de coerción.

Advertencias obligatorias: factores de ponderación ajustados a nuevas estimaciones y proyecciones (revisión 2025); exclusión de Boquerón, Alto Paraguay, comunidades indígenas y viviendas colectivas; ruptura especial del segundo trimestre de 2020; subocupación recalculada desde 2019 con una sola ocupación; ingresos cero excluidos en cuadros de ingreso; imputación de atípicos por mediana; formalidad excluye unidades económicas fuera del país. Son estimaciones muestrales, nunca conteos administrativos.

Las fórmulas (192 celdas, en `SECTORECONÓMICO` y `CATEGORÍAOCUPACIONAL`) son derivados publicados y deben conservar fórmula/caché y distinguirse de estimaciones cargadas directamente. El segundo trimestre de 2026 figura preliminar en los cuadros de ingresos. No se observa ajuste estacional.

## Modelo de datos e identidades propuestas

Primera capa recomendada para ambos: preservación raw + staging provisional. Solo después de reconciliación completa podrían pasar a catálogo/explore; `research.*` queda fuera de alcance.

MEF natural key propuesta: `(source_id, vintage_sha256, source_sheet, source_row, source_column)` en raw y, en staging, `(vintage_id, published_account_path_exact, period_published, accounting_stage, measure_role)`. `published_account_path_exact` debe conservar sangría y coordenadas; una identidad económica estable puede usar un path gobernado, pero no debe deducirse solo de etiquetas repetidas. Campos separados: subsector institucional, clasificación económica, flujo/stock, etapa `obligado`, moneda `PYG`, escala `billions`, precios corrientes, ajuste estacional `not_stated`, preliminar, fórmula y derivación publicada.

INE natural key propuesta: raw por coordenada y staging por `(vintage_id, source_sheet, table_number, published_row_path_exact, period_published, area, sex, measure, domain_dimension_values)`. La identidad no debe incluir el valor. Debe separar población de referencia, área, sexo, edad/sector/categoría/tamaño/horas/experiencia/educación/ocupación, tipo de estadístico (`estimate_count`, `percent`, `rate`, `mean`), unidad/escala y bandera de precisión. Total, Hombres y Mujeres son dimensiones publicadas, no agregaciones a reconstruir.

Missingness: preservar celda vacía, `-`, paréntesis de baja precisión, cero publicado y no aplicable como estados distintos. No imputar. Para MEF, conservar preliminar y cálculo publicado; para INE, conservar revisión de ponderadores, insuficiencia muestral, preliminar e imputación editorial de atípicos como metadatos de observación/metodología.

## Solapamientos

MEF se solapa conceptualmente con series fiscales de `economic_annex`, incluida la familia de ingresos tributarios mensuales 2015–2026, pero no se ha probado equivalencia de cobertura, etapa contable, clasificación o vintage. Debe tratarse como posible solapamiento, no duplicado.

EPHC se solapa conceptualmente con cualquier serie laboral/ingreso/población existente o futura, pero la búsqueda del repositorio no mostró una fuente EPHC ya registrada. Las estimaciones revisadas con ponderadores 2025 no deben empalmarse con otras vintages ni geografías sin evidencia.

## Procedencia, licencia y atribución

La atribución interna del INE está explícita en cada cuadro. En MEF, la institución se infiere del nombre aportado y las propiedades `DGPMF`, pero el libro no contiene una línea de fuente completa. Ningún archivo incluye licencia, términos de redistribución, URL oficial, identificador de release ni fecha oficial verificable. Estado recomendado: `license_status=unverified`, redistribución de bytes bloqueada hasta conservar página oficial/términos y evidencia de adquisición. Atribución mínima provisional: nombre institucional completo, publicación/título exacto, hoja/cuadro, período, hash y fecha de acceso comprobada por el propietario; no inventar URL o vintage.

## Piloto y pruebas propuestas

1. Registrar primero evidencia de adquisición/licencia y resolver los nombres/source IDs.
2. Archivar por SHA solo en una fase autorizada del pipeline.
3. Implementar parser aislado por fuente, con matriz raw por celda y coordenadas A1.
4. MEF: probar 284 períodos exactos, 84 filas valoradas, 23.676 valores, 568 fórmulas, filas ocultas, jerarquía/sangría, preliminares y reconciliación de identidades fiscales sin derivar meses.
5. INE: probar las 16 hojas, `Hoja2` vacía, merges, encabezados multinivel, 846 series candidatas, 27.212 valores numéricos, tokens y banderas; validar Q2-2020 y revisión 2025.
6. Comparar totales/subtotales solo como controles, sin reemplazar observaciones ni declarar equivalencias.
7. Ejecutar pruebas focales y suite completa sobre base aislada; revisar catálogo/explore antes de cualquier promoción. Research requiere autorización económica separada.

## Decisiones requeridas del propietario

1. Confirmar el significado de `2001` y aportar evidencia oficial; el archivo no lo explica.
2. Confirmar la definición institucional de Administración Central y la etapa/criterio contable por cuenta, especialmente financiamiento y caja.
3. Autorizar o rechazar el tratamiento de fórmulas publicadas como observaciones derivadas separadas.
4. Definir source IDs y nombres de publicación.
5. Aportar URL oficial, fecha de descarga/release, licencia y permiso de redistribución de cada libro.
6. Confirmar el significado gobernado del token `-` y de paréntesis INE; el diagnóstico recomienda `not_available/not_applicable` pendiente y `low_sample_precision`, respectivamente.
7. Decidir si el piloto puede llegar a `catalog/explore` o debe permanecer solo en preservación/staging.

## Reproducibilidad

Ejecutar `Rscript --vanilla docs/audits/mef_ine_discovery_20260919/inspect_workbooks.R`. El script solo lee los dos XLSX y escribe este directorio. `file_inventory.csv`, `sheet_inventory.csv`, `structural_counts.csv`, `merged_ranges.csv`, `hidden_rows.csv`, `hidden_columns.csv`, `formulas.csv`, `notes_and_footnotes.csv` y `nonempty_cells.csv` contienen la evidencia detallada.

## Implementación y promoción autorizadas

El propietario resolvió las decisiones económicas el 2026-09-19 y confirmó las fechas oficiales el 2026-09-20. `MEFP 2001` identifica el manual estadístico, no el año inicial; Administración Central se gobierna como Gobierno Central sin municipios; los valores MEF son flujos; la continuidad publicada se acepta como total; y las fórmulas se conservan en raw pero se excluyen de observaciones. EPHC usa trimestres calendario y 2020-Q2 conserva una advertencia explícita por el cierre/cuarentena de COVID.

Las descargas oficiales fueron comparadas byte a byte con los archivos recibidos. MEF coincide con SHA-256 `0b6be44e1e243a43eeacafbe4da06925f49b06e0fca1df3d150c1d40d103c2a7` y fecha oficial confirmada `2026-09-15`; INE coincide con `04bf76173d73c5e99e7ecea6f64bd1284adc6dfefbacf9815a9a3b4003c7311d` y fecha `2026-07-30`. INE queda sujeto a la Licencia de Uso de la Información Pública (Decreto 4064, Ley 5282/2014); los derechos específicos MEF permanecen pendientes, por lo que ambas fuentes continúan provisionales y fuera de `research.*`.

El parser produce 23.108 observaciones MEF en 82 series, de 2003-01 a 2026-08, y 27.017 observaciones EPHC en 1.088 series, de 2017-Q1 a 2026-Q2. La celda aislada MEF `FN89`, sin etiqueta y fuera de cualquier fila tabular, se conserva en raw y está clasificada explícitamente como `out_of_scope_block`. No se derivaron meses, diferencias acumuladas ni fórmulas.

La primera regresión completa detectó que la exclusión de fórmulas se había aplicado también a `economic_annex` y `bcp_fx_daily`. La implementación se corrigió para limitarla a MEF e INE; una reconstrucción dirigida de ambas fuentes históricas fue aceptada y el smoke test completo pasó después de la corrección. Las pruebas focalizadas MEF/INE pasan 15/15. El candidato estándar final fue aceptado con cero errores y 44 advertencias provisionales.

La promoción atómica autorizada publicó el esquema 49 con build `build:481cb2d5c90afff4f1964f7f`, attempt `attempt:3f3ebc8b67a619e396a77ac1`, source bundle `release:90ecbb654ed9413352a4e028` y SHA-256 `c902c77fcddd3050641c50243c9244f4f77e9814ebdaa4582f14aed11a4b4f50`. El registro durable es `database/releases/promotions/build_481cb2d5c90afff4f1964f7f_20260920_042547.json`; el backup previo es `database/backups/paraguay_macro_pilot_pre_swap_20260920_041008.duckdb`. El smoke test posterior a la promoción pasó y el candidato aceptado fue preservado.
