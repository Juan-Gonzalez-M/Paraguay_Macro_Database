# Boletines estadístico-financieros de la SIB, 2011–2015 (formato clásico)

*2026-09-24. Brecha 6b del ranking (`proyectos/00_resumen_viabilidad.md`). Fuera de la base DuckDB: nada de esto está integrado ni tiene revisión humana.*

La base ya trae los boletines de bancos y financieras como panel largo (fecha × entidad × rubro × moneda) desde **2016-01**. Estos archivos cubren **2011-01 → 2015-12** con datos por entidad, pero con el formato del boletín impreso (una hoja por página). La extracción los lleva a formato largo **sin cambiar ningún valor**.

## 1. Origen, cobertura y archivos

**Origen:**
- 223 archivos bajados a mano por el usuario desde https://www.bcp.gov.py/en/formato-clasico. Se registran como obtenidos el 2026-09-24, a pedido del usuario. Están en `raw/manual_usuario/`.
- 2 meses faltantes en el sitio: bancos 2015-09 y casas de cambio 2014-03. El enlace existe, pero entrega el archivo del mes anterior. Se recuperaron de la copia del sitio anterior del BCP (`/userfiles/files/`) que guarda el Internet Archive, de julio de 2017. Ver `raw/internet_archive/` y la URL de cada copia en `inventory.csv`.
  - Se verificó la fecha de corte interna de ambos: 30/09/2015 y 31/03/2014 (esta última en número de serie de Excel, 41729).

**Cobertura** (fecha de corte leída **dentro** de cada archivo, no del nombre):

| Boletín | Meses | Diseño |
|---|---|---|
| Bancos | 60/60 | clásico 2011-01 → 2013-12, nuevo 2013-09 → 2015-12 |
| Financieras | 60/60 | ídem |
| Casas de cambio | 60/60 | ídem |
| Ficha técnica / «Otros datos» (totales del sistema, tasas, cuentas inhabilitadas) | 36/60 | 2011-01 → 2013-12; no existe en 2014–2015 |

En 2013-09, 2013-10 y 2013-11 hay **dos versiones del mismo mes**: la clásica («quereemplaza») y la nueva («_N», «propuesto»). Se conservan ambas, marcadas en `version`, y sirven de puente entre los diseños (control C).

**Eliminados** a pedido del usuario (`eliminados_2026-09-24.csv`, con SHA-256):
- 5 duplicados exactos (se verificó el hash contra el original antes de borrar).
- El único mes del boletín de almacenes generales (2015-04).

**Archivos de la carpeta:**

| Archivo | Qué es | En Git |
|---|---|---|
| `inventario.R` → `inventory.csv` | Ruta, origen, URL, fecha de obtención, bytes, SHA-256, tipo, diseño, fecha de corte interna y versión. Si se vuelve a correr, verifica los hashes. | Sí |
| `extraer_celdas.R` → `extraidos/celdas_*.parquet`, `control_celdas.csv` | **Capa 1:** todas las celdas, con coordenadas y etiquetas publicadas. | Scripts y control sí; parquet no |
| `extraer_panel.R` → `extraidos/panel_entidades.parquet`, `diccionario_entidades.csv`, `control_panel.csv`, `tasas_ficha_tecnica.csv` | **Capa 2:** panel por entidad y tasas de la ficha técnica. | CSV sí; parquet no |
| `alias_entidades.csv` | Alias de nombres que la normalización automática no resuelve. Revisable. | Sí |
| `validar.R` → `extraidos/validacion_*.csv` | Controles A–D (§ 3). | Sí |
| `sugerir_codigos.R` → `vinculo_codigos_sugerido.csv` | Vínculo **sugerido** con los códigos de entidad de la base. Lee la base en modo solo lectura. | Sí |

Orden de ejecución, desde esta carpeta (requiere R con readxl, data.table, arrow, stringi y duckdb):
`Rscript inventario.R && Rscript extraer_celdas.R && Rscript extraer_panel.R && Rscript validar.R && Rscript sugerir_codigos.R`

Los crudos (247 MB) y los parquet (38 MB, regenerables) quedan locales. **Conviene respaldar `raw/`**: al menos dos meses ya no se pueden bajar del sitio del BCP.

## 2. Cómo se extrae

**Capa 1** (1.411.155 celdas numéricas y 239.027 de texto en 4.597 hojas; el control cierra exacto: celdas leídas = numéricas + texto):
- Cada número conserva el valor publicado (texto) y el numérico.
- Las etiquetas son solo posicionales:
  - **título:** fila con un solo texto antes de los datos;
  - **encabezado de columna:** ruta de los rótulos del bloque, unida con « > », con herencia de celdas combinadas hacia la derecha;
  - **etiqueta de fila;**
  - **sección:** rótulos de grupo como «SUCURSALES DIRECTAS EXTRANJERAS»;
  - **nota:** textos largos al pie.
- Una hoja puede tener varios bloques verticales, y cada bloque toma el encabezado que tiene justo arriba.

**Capa 2** (1.239.331 celdas, el 88% de las de bancos y financieras y el 94% de las de casas de cambio):
- **Entidad.** Se detecta en la fila (diseño clásico, hojas evolutivas) o en el encabezado (balance y resultados del diseño nuevo, casas de cambio).
  - Los nombres se normalizan: mayúsculas, sin acentos, sin numeración «3- », sin «(*)», sin siglas entre paréntesis y sin forma societaria.
  - Quedan **78 entidades**: 22 bancos, 18 financieras (incluido el Fondo Ganadero) y 38 casas de cambio, más los agregados publicados (sistema, subtotales por grupo de propiedad).
  - **Rareza de la fuente:** en el boletín clásico de financieras, la hoja «EVOL ACTIV VIVIENDA» trae filas de bancos (parece copiada del boletín de bancos). Se conserva tal cual, con `tipo = financieras`, y explica las mayores fallas del control B en esa hoja.
  - Los «SUB-TOTAL» llevan el nombre de su grupo.
- **Herencia por columna.** Si una hoja del diseño nuevo trae el nombre de la entidad una sola vez arriba, las celdas de los bloques de abajo lo heredan, marcadas como `heredada_columna`, pero solo cuando la columna tiene una única entidad.
- **Período.** Es la fecha de corte, salvo en las hojas evolutivas, donde el encabezado nombra el mes. Ahí se guarda el texto publicado y el mes; nada se deriva.
- **Qué queda sin asignar.** Queda en la capa 1, contado en `control_panel.csv`:
  - tablas auxiliares sin ningún rótulo debajo de las notas (datos de gráficos);
  - la columna de numeración;
  - la ficha técnica, que no tiene entidades.
- **Tasas de la ficha técnica** (`tasas_ficha_tecnica.csv`): 3.038 valores, 34 meses (2011-01 → 2013-12) y 15 productos, para bancos y financieras, en M/L y M/E, nominal y efectiva. Incluye tarjetas de crédito: la tasa efectiva en M/L de los bancos va de 44,1% (2011-01) a 50,5% (2013-12). El mes sale del título de la hoja.

## 3. Controles (`validar.R`)

| Control | Resultado |
|---|---|
| A. MN + ME = TOTAL (entidad en columnas) | 169.551 de 169.666 cierran. Los 115 que no cierran vienen de los borradores «propuesto» (un bloque auxiliar con códigos de cuenta cae en la columna MN del BNF) y de un rubro de El Comercio en los meses de transición. Listados en `validacion_A_moneda.csv`. |
| B. Σ entidades = sistema (solo montos) | Bancos nuevo 99,6%, financieras nuevo 98,1%, bancos clásico 91,3%, financieras clásico 92,0%, casas de cambio nuevo 82,6%. En casas de cambio las diferencias son chicas (mediana 0,8%) y están en pocos rubros de resultados («Egresos», «Otros activos»), así que parecen de la fuente. En el diseño clásico, las diferencias se concentran en hojas evolutivas y de participación. Detalle en `validacion_B_agregacion.csv`. El Fondo Ganadero se publica fuera del «Total sistema financieras» y no se suma. |
| C. Total activo clásico = nuevo (2013-09..11) | 84 de 84 iguales (diferencia 0,0000%). |
| D. Mismo mes en varios boletines | 102 de 15.569 meses cambian entre boletines: son **revisiones** (vintages), no errores. |
| Continuidad con la base | Los 17 bancos y 9 financieras de 2015-12 se emparejan con los de la base en 2016-01, con variaciones mensuales del activo de −10% a +12% en MN o ME. Sistema bancario: 106,1 → 108,3 billones de Gs. (`vinculo_codigos_sugerido.csv`). |

## 4. Revisión humana

**Decisiones del usuario (2026-09-24)** en `decisiones_revision.csv`:
- R01–R26: los 26 vínculos de código.
- R27–R29: la unificación de Solar.
- R30: la fecha del hito H03.
- R31–R38: los alias previos.
- R39: «Banco Sudameris» 2011–12.

Solo quedan pendientes las claves y códigos propuestos para los hitos (columnas `*_propuestas` de `hitos_usuario.csv`, § 5). `sugerir_codigos.R` lee ese registro: una sugerencia regenerada queda «aprobado (Rnn)» solo si coincide con el código aprobado.

- **`vinculo_codigos_sugerido.csv`** (**aprobado**, R01–R26): nombre de 2015 → código de la base. Se asigna comparando por separado el activo en MN y en ME (el total solo cruzaba al BNF con Sudameris). Varias entidades cambiaron de nombre, por ejemplo: Amambay → Basa, Itapúa → Río, BBVA → 1007 («GNB Fusión»), El Comercio Financiera → 2007 (UENO).
  - Las entidades que dejaron de existir antes de 2015-12 no tienen sugerencia: HSBC, Integración, Interbanco, ABN AMRO, Banco Sudameris 2011–12, Brios, Santa Ana, Ara, Fondo Ganadero, entre otras.
- **`alias_entidades.csv`** (todos **aprobados**): 7 alias (más una fila de control) por orden de palabras, errores tipográficos («Viscaya», «Financier») o siglas. Ninguno aparece junto a su nombre canónico en la misma hoja. Se suman 3 alias de Solar (R27–R29) y «Banco Sudameris» (R39), ver § 5.
- **Interfisa** figura como financiera hasta 2014 y como banco después. Se usa la misma clave: es la misma razón social.
- **Nada entra a la base** sin pasar por el flujo de candidatos, revisión y publicación (AGENTS.md).

## 5. Hitos del sistema (fusiones, cambios de nombre, liquidaciones)

**Insumos:**
- `hitos_usuario.csv` transcribe la tabla que aportó el usuario el 2026-09-24. La imagen original está en `hitos_usuario_2026-09-24.png` (SHA-256 `37a43661…`). La tabla no cita fuente primaria.
- Las columnas `*_publicado` copian la tabla; las flechas «$\rightarrow$» de la imagen se transcriben como «→».
- Las columnas `*_propuestas` / `*_propuestos` (claves del boletín y códigos de la base) son **interpretación nuestra**, pendiente de revisión.

**Evidencia** (`Rscript hitos.R`): cruza cada hito con el primer y último mes en que la entidad reporta su propio balance. Salidas: `extraidos/hitos_evidencia.csv`, `altas_bajas_boletines.csv` (2011–2015) y `altas_bajas_base.csv` (2016 → 2026-07).

| Hito | Lectura de la evidencia |
|---|---|
| H01 Regional/ABN AMRO (2009), H02 Interbanco → Itaú (2010) | Coherente. En 2011–2015 ABN AMRO e Interbanco solo aparecen en tablas históricas, nunca con balance propio. |
| **H03 Atlas/Integración (2010)** | **Difiere.** Integración reporta balance hasta **2011-09**, y los boletines traen la nota «(*) Entidad fusionada con Banco Atlas S.A. **a partir de octubre/2011**». **Aprobado (R30): se usa 2011-10**; `hitos_usuario.csv` conserva «2010» tal como se publicó en la tabla. |
| H04 GNB/HSBC (2012–2013) | Coherente y más preciso: HSBC hasta 2013-11, GNB desde 2013-12. |
| H05 Ara (2015), H06 Santa Ana (2015) | Coherentes: Ara reporta hasta 2015-03 y Santa Ana hasta 2015-08. |
| H07 Amambay → Basa (2018) | Coherente: misma serie, el código 1030 no se interrumpe. |
| H08 Itapúa + Financiera Río → Banco Río (2019) | Coherente: Financiera Río (2077) reporta hasta 2019-01; el banco sigue con el código 1040. |
| H09 GNB/BBVA (2021–2022) | Coherente: BBVA (1007, «GNB Fusión») reporta hasta 2022-06. |
| H10–H12, H14–H15 (El Comercio/ueno, Solar, Cefisa, ueno banco, Finexpar → Zeta) | Coherentes. Los pasos de financiera a banco se ven al mes: Solar 2022-10 → 2022-11, ueno 2023-11 → 2023-12, Finexpar/Zeta 2024-02 → 2024-03. Cefisa reporta hasta 2022-11. |
| H13 Sudameris/Regional (2023) | Coherente: Regional reporta hasta 2023-06. |
| H16 ueno/Visión (2024) | Coherente: Visión reporta hasta 2024-05. |
| H17 Atlas/Familiar (2024–2025, cancelada) | Coherente: ambos siguen reportando hasta 2026-07. |
| H18 Continental/Río (2025) | Coherente: Río reporta hasta 2025-07. |

**Altas y bajas en 2011–2015 que la tabla no incluye:**
- **Brios de Finanzas:** hasta 2012-04.
- **Bancop:** desde 2012-07.
- **FIC de Finanzas:** desde 2014-07.
- **Casas de cambio:**
  - Salen: New Exchange y Paraguay Express (2011-05), Multi (2012-02), Master Exchange (2013-11), Sudacam (2013-12, tras entrar en 2013-06), Tayí (2014-05) y Forex (2015-11).
  - Entran: Mas (2012-04), Global (2012-08), Panorama (2014-02) y Uniexpress (2014-06).
- **Solar:** aparece con tres nombres que se superponen (Solar S.A. hasta 2013-05; «de Ahorro y Préstamo para la Vivienda» 2013-06 → 2015-03; «Ahorro y Finanzas» desde 2015-02), más una variante con error tipográfico («de Ahora y Préstamos», boletines 2013-10 y 2013-11). **Unificado** (R27–R29) bajo `SOLAR AHORRO Y FINANZAS` → `finance_company:2081`: la serie cubre 2011-01 → 2015-12 sin huecos. `entidad_publicada` conserva el nombre original de cada celda y `metodo_clave` = `alias_revisable`. No hay colisiones propias de Solar. La única superposición (hoja 8 de 2_BOLF_072015.xls, julio de 2014) viene de dos bloques de morosidad de la misma hoja (filas 14–31 y 52–69) que el panel no distingue, y afecta a todas las financieras.
- **Banco Sudameris** (2011-01 a 2012-05, solo en 3 hojas: CART-ACTIV, CART-ACTIV Part y PAG17 (2)): **unificado** con Sudameris Bank (R39). En los 17 meses, el total de cartera de CART-ACTIV es idéntico al valor de Sudameris Bank en CART-CLASIS del mismo boletín, y a ninguna otra entidad.

Las fechas oficiales requieren la resolución del BCP o de la SIB. Esta evidencia solo acota en qué mes deja de reportar o empieza a reportar cada entidad.
