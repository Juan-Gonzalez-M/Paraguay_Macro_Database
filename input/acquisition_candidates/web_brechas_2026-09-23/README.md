# Verificación de brechas prioritarias: carpeta `web_no_clima_2026-09-23` y fuentes en línea

*2026-09-23. Referencia: ranking de datos faltantes de `proyectos/00_resumen_viabilidad.md` (§ 3.3). Nada de esto está integrado a DuckDB ni validado para uso econométrico.*

Esta carpeta guarda solo los dos documentos que se descargaron durante la verificación (ver `inventory.csv`: URL, hora UTC y SHA-256). El resto de las fuentes quedó **comprobado en su acceso**, pero no se descargó.

## 1. Qué cubre la carpeta `web_no_clima_2026-09-23`

Integridad: los 109 archivos coinciden con el SHA-256 de su inventario y no hay archivos fuera de él. Las subcarpetas `raw/bcp/*` están **vacías** (bloqueo de Cloudflare).

| Rango (brecha) | Archivo(s) | Qué contiene (verificado) | Cobertura de la brecha |
|---|---|---|---|
| **9. Subastas del Tesoro, *security master* y tenencias** (C3, N1, A1) | `raw/mef/bonos/Resultado_de_subastas_2006-2026…xlsx` | Una hoja por año (2006–2010 y 2012–2026; el propio archivo aclara: «En el 2011 no se realizó ninguna subasta»). Por subasta: fecha, ISIN, monto licitado, propuesto y adjudicado, tasa o precio de corte, TIR (hasta 2017), rango de ofertas y cantidad de ofertas. La hoja `C.F.` tiene las condiciones financieras de 194 emisiones: ISIN, plazo, fechas de emisión y vencimiento, moneda, cupón y amortización. | **Alta.** Subastas y *security master* completos. |
| ídem | `raw/mef/bonos/…en_circulacion…` (dic-2023, dic-2024, dic-2025, ago-2026) | Hojas Stock, Perfil de amortizaciones, **Tenencias**, Condiciones financieras y Flujos-BCP. La hoja *Tenencias* identifica al tenedor por nombre: bancos, FGD, aseguradoras, BNY (DR) y «Inversor institucional». | **Parcial.** Tenencias por tenedor en 4 cortes, no una serie mensual. El README de esa carpeta dice que no hay tenencias; **sí las hay**. |
| **10. Microdatos EPH antes de 2017** (N2, F5) | `raw/ine/ephc_comparable/2008…2016` | EPH anual con R01 (vivienda), R02 (personas) e INGREFAM; entre 4.400 y 10.200 hogares por año; factor `Factor`. Departamento solo desde 2015. | **Parcial.** Faltan 1997–2007 y la EPHC 2017–2025, que el INE sí publica (§ 2). |
| **5. Ponderadores del IPC** (F5, D4, F2) | `raw/ine/eigcv_2011_12/microdatos/*.dta` | EIGyCV 2011/12: 5.417 hogares, 2,04 millones de transacciones de gasto, `fex`, `dptorep` y `area`. | **Parcial y con cautela.** Permite estimar canastas por quintil o área, pero la canasta del IPC base 2017 usa la **EPF 2015/16** (confirmado en la metodología oficial). **Eliminado** a pedido del usuario el 2026-09-23. |
| **14. Cooperativas por entidad** (C2, D5, C1) | `raw/incoop/cac_tipo_a/*` | Balances por cooperativa de ahorro y crédito tipo A (≈ 70 entidades × 35–55 rubros): diciembre 2017–2024 y marzo, junio, septiembre y diciembre de 2025. | **Parcial.** Panel anual (trimestral en 2025); estados «referenciales, no validados» según el INCOOP. |
| **12. PGN aprobado** (N1) | `raw/mef/pgn/*.pdf` | Leyes del PGN 2025 y 2026 (88 y 95 páginas, con texto). | **Baja.** Dos años en PDF. **Eliminado** a pedido del usuario. |
| N2: empleo formal | `raw/ips/anuarios/*.pdf` (12 anuarios, 2014–2025) | Cotizantes y beneficiarios. La tabla **mensual** «Titulares / Beneficiarios» se encontró en los anuarios 2021, 2024 y 2025; en los demás años el formato es otro. | **Parcial.** |
| N1 (control) | `raw/mef/situfin/*.xlsx` | MEFP 2001 Administración Central, mensual 2003–2026 y anual 2003–2025 (hojas Serie, % PIB, % Var.). | El **mensual** era un duplicado exacto (mismo SHA-256) de `input/current/MEFP…serie mensual.xlsx` y **se eliminó**. El **anual** (Serie, % PIB, % Var.) no está en la base y se conserva: el % del PIB usa el PIB del MEF. |
| **1. Calendario (salario mínimo)** (N11) | `raw/mtess/salario_minimo/Resolucion…670…2026.pdf` | Reglamentación de 2026. | **Eliminado** a pedido del usuario: lo reemplaza la tabla completa de decretos (§ 2 y § 3). |
| 3, 4, 6b, 7, 8 (datos internos del BCP) | `raw/bcp/*` | Vacío. | Nada. |

## 2. Fuentes en línea verificadas

| Brecha (rango) | Fuente | Acceso probado | Qué aporta | Acción sugerida |
|---|---|---|---|---|
| **5. Ponderadores del IPC** | Metodología IPC base dic-2017 (copia en el portal de Acceso a la Información Pública) | **Descargado** (`raw/bcp_metodologia_ipc_base_dic2017.pdf`, 97 páginas) | Anexo 2 con el **ponderador oficial de los 465 artículos** y la jerarquía de códigos (p. ej., alimentos 26,865; carnes 9,491). Fuente: EPF 2015/16. | Extraer el Anexo 2 a CSV: jerarquía estable del IPC para D4 y F5. Siguen faltando ponderadores por grupo de hogares (EPF 2015/16 por quintil, no ubicada en línea). |
| **1. Calendario: salario mínimo** | MTESS, *Reporte técnico: ingresos laborales y salario mínimo* (2026) | **Descargado** | Tabla 1: **los 33 ajustes 1989–2025** con número y fecha de decreto, porcentaje y vigencia (según la Gaceta Oficial). El ajuste 2026 (Decreto 6225, 5 %, vigente desde el 1/7/2026) figura en la web del MTESS. | Completa la plantilla `32_n11…/datos_manuales/decretos_salario_minimo.csv`. |
| **10. Microdatos EPH** | INE, serie comparable EPH | HTTP 200 en archivos de prueba (1997-98 y 2025) | EPH/EIH **1997-98 a 2021** (CSV y SAV, con diccionarios) y EPHC anual 2017–2025, más la trimestral. | Descargar los años faltantes (1997–2007 y 2017–2025). |
| **13. Aduanas por transacción** | DNA, portal de datos abiertos (endpoint público `/ddaa/mainctrl/listaArchivos`) | HTTP 200 y lectura parcial de un CSV | **356 meses (1997 → 2026-08)** a nivel ítem y subítem: despacho cifrado, régimen, aduana, país de origen y de procedencia, posición NCM a 10 dígitos, cantidad, kg, FOB, flete, seguro e impuestos. ≈ 300 MB por mes a nivel ítem. | Descarga selectiva (años, capítulos o aduanas de frontera) para F2 y N5. Sin importador identificado ni moneda de factura. |
| **13b. Tipo de cambio paralelo argentino** | API argentinadatos.com; API bluelytics | HTTP 200, JSON | Diario: blue, oficial y mayorista desde 2011; CCL desde 2013; MEP desde 2018. | Usar para N5, contrastando el oficial con la API del BCRA. Son agregadores privados de cotizaciones de mercado. |
| Clima: Yacyretá | EBY: PDF «Energías mensuales desde la puesta en marcha» y comunicados mensuales | HTTP 200 | Los PDF son **gráficos** (1994–2019, solo valores anotados, no series). Los comunicados mensuales (≈ 2022 →) dan la energía del mes, el reparto ANDE/ENARSA y el caudal, en texto. ANDE (*Compilación Estadística 2001–2021*) es anual y agregada. | Extracción de texto de comunicados posible pero frágil. Mejor pedir la serie a la EBY o a la ANDE. |
| Clima: IRI desde 2025-05 | IRI Data Library | Pide inicio de sesión (GitHub o Google) | Posibles probabilidades ENSO como dato estructurado. **No verificado.** | Requiere registro. |
| 1. Combustibles (N10) | Petropar | HTTP 200 | Solo precios **vigentes**, sin historial. | No sirve; pedir la serie a Petropar o usar resoluciones. |
| 12. PGN histórico | Portal de datos del MEF (`datos.hacienda.gov.py`, `datos.mef.gov.py`) | **HTTP 403** | Presupuesto aprobado, vigente y ejecutado 2011→ (según el catálogo). | Descarga manual desde el navegador. |
| 1, 3, 4, 6b (BCP) | bcp.gov.py (comunicados del CPM, operaciones cambiarias, boletines 2011–2015) | **HTTP 403 (Cloudflare)** para clientes automáticos, WebFetch incluido | *Corrección 2026-09-24:* el xlsx de operaciones cambiarias **ya está en la base** (`input/current/fx_operations`). El Internet Archive guarda 336 de los 360 documentos que lista la página del CPM (agosto de 2026): **descargados** el 2026-09-24 (§ 4). No guarda los boletines 2011–2015. | Boletines: descarga desde el navegador (en curso, a cargo del usuario). |
| 15. EMBI | JP Morgan | No público | — | Sin alternativa pública equivalente. |

## 3. Segunda ronda de descargas (aprobada por el usuario, 2026-09-23)

Script reproducible: `acquire.py` (modos `ine`, `argentina`, `aduana`, `documentos`; el modo `archivo` es de la tercera ronda, § 4). Hay un inventario por fuente: `inventory.csv` para documentos y Argentina, `inventory_ine.csv` e `inventory_aduana.csv`. En aduana, el `.gz` es una compresión sin pérdida del CSV publicado: `sha256` corresponde al contenido original y `sha256_gz` al archivo comprimido.

| Fuente | Contenido | Brecha y proyectos |
|---|---|---|
| INE (`raw/ine/SERIE-EPHC`, `raw/ine/EPHC-ANUAL`) | EPH/EIH comparable 1997-98 → 2007 y 2017 → 2021, y EPHC anual 2017 → 2025 (CSV, SAV, diccionarios, cuestionarios). 2008–2016 no se repite: ya está en `web_no_clima_2026-09-23`. | 10 · N2, F5 |
| DNA (`raw/aduana/AAAA/MES/*_Nivel_Item.csv.gz`) | Declaraciones a nivel ítem, mensuales 1997 → 2026-08. | 13 · F2, N5, F3 |
| BCRA (`raw/argentina/bcra_*`) | Dólar oficial diario (API estadísticas cambiarias v1.0), 2002 → 2026, 6.054 días. | 13b · N5 |
| argentinadatos, bluelytics (`raw/argentina/`) | Blue, MEP, CCL y otros, diarios desde 2011. Son agregadores privados. | 13b · N5 |

**Nota de calidad (DNA):** en los CSV publicados la «Ñ» aparece como «\\» (p. ej., «ES - ESPA\A»). Es un artefacto de codificación de la fuente: se conserva tal cual y se corrige solo en una capa de interpretación explícita.

### Tablas extraídas (`extraer_tablas.R` → `extraidos/`)

- `ipc_base2017_canasta_ponderaciones.csv`: Anexo 2 completo, con **12 divisiones, 56 grupos, 155 subgrupos y 465 artículos**, igual a lo que declara la metodología. Los artículos suman 99,984 (redondeo publicado a 3 decimales) y la mayor diferencia entre la suma de los hijos y su padre es 0,003. Las divisiones 10–12 usan códigos de 9 dígitos. Seis filas tienen la descripción partida en dos líneas del PDF (marcadas en `nota`).
- `salario_minimo_decretos_1989_2025.csv`: Tabla 1 del MTESS, **33 episodios (0–32)** con número y fecha de decreto, porcentaje y vigencia, más las fechas en formato ISO. 2020: decreto sin ajuste (vigencia «-»). El ajuste 2026 (Decreto 6225, 5 %, vigente desde el 1/7/2026) no está en esa tabla: consta en https://www.mtess.gov.py/?p=36166. No se sobrescribió la plantilla manual del proyecto 32.

## 4. Tercera ronda: comunicados del CEOMA/CPM y bonos del MEF desde el Internet Archive (2026-09-24)

Aprobada por el usuario. El sitio del BCP rechaza clientes automáticos (Cloudflare) y **no se sortea**: se usan las copias públicas del Internet Archive. Cada archivo se pide con el sufijo `id_`, que devuelve los bytes capturados sin reescritura. El inventario `inventory_archivo.csv` registra la URL de la copia (con la marca de tiempo de captura), la URL original del BCP y el SHA-256. Se descargó con `python3 acquire.py archivo` y se extrajo con `Rscript extraer_cpm.R` (requiere `pdftotext`, de poppler).

**Qué se bajó** (`raw/archivo/`, 40 MB, local):
- La página «Comunicados del CPM», en su única copia archivada (2026-08-21), como evidencia de qué documentos existían.
- **336 de los 360 documentos que lista esa página**: 190 comunicados en español y 146 en inglés. El idioma se decide por el texto, no por el nombre del archivo. Cubren de enero de 2010 a abril de 2026.
- `extraidos/cpm_documentos_control.csv` lista los 393 enlaces de la página (361 documentos distintos, incluido un ícono) con su estado: `ok`, `ya_estaba` (el mismo documento enlazado dos veces) o `no_archivado`.
  - **Sin copia archivada:** 20 comunicados en inglés y, en español, noviembre de 2011 y mayo a julio de 2026. Estos se pueden bajar a mano desde https://www.bcp.gov.py/comunicados-del-cpm.

**Calendario extraído** (`extraidos/cpm_calendario_decisiones.csv`): una fila por comunicado en español (190).

Contenido de cada fila:
- La fecha tal como se publicó y en formato ISO.
- La **frase de la decisión textual**.
- Lo que se lee de ella: instrumento, acción, tasa anterior (solo si el texto la dice), tasa nueva, cambio en puntos básicos (solo si el texto lo dice) y votación.
- Archivo, UUID, URL del BCP, captura del archivo y SHA-256.

Reglas de lectura:
- **Nada se calcula a partir de otras filas.**
- Lo que no se puede leer queda NA, con una marca en `revisar`.
- Los comunicados **no traen la hora del anuncio**, así que la hora no se infiere.

Resultado:
- **Instrumento.** 167 comunicados hablan de la tasa de política monetaria (`tpm`), desde junio de 2012.
  - Antes el BCP anunciaba otras tasas y el calendario no las mezcla con la TPM: los IRM a 14 días, curvas de plazos de IRM o la tasa de la FLIR.
- **A revisar.** 15 filas, todas de 2010–2011 (régimen anterior): textos narrativos, curvas con varias tasas o dos documentos con la misma fecha (enero de 2010).
- **Coherencia interna de la TPM.** Cada «mantener» repite la tasa anterior, cada «reducir» o «aumentar» va en la dirección correcta, y cada «de X% a Y%» coincide con la fila previa. La única excepción es octubre de 2023, que dice «de 8,00% a 7,75%»: la fila previa (agosto) dejó la tasa en 8,25% y **la página no lista un comunicado de septiembre de 2023**.
- **Contraste independiente con el corredor** (proyecto 25, `fechas_candidatas_cambio_tpm.csv`, inferido de las tasas diarias FPD y FPL de la base):
  - Los 38 cambios de TPM posteriores a abril de 2015 coinciden con un desplazamiento del corredor 1 a 3 días después del comunicado (la vigencia empieza al día hábil siguiente).
  - Los 2 desplazamientos del corredor sin comunicado son el **31 de marzo de 2020 (TPM implícita 2,25%)** y el **21 de septiembre de 2023 (8,00%)**. Son decisiones que la página del CPM no lista, probablemente una reunión extraordinaria y la de septiembre de 2023.
  - Los cambios previos a abril de 2015 no se pueden contrastar porque el corredor diario empieza después.
- **Meses sin comunicado en español** (enero de 2011 a abril de 2026): junio y noviembre de 2011 y septiembre de 2023.

**Uso sugerido:** poblar `proyectos/25_n4_sorpresas_monetarias/datos_manuales/calendario_copom.csv` con estas fechas y tasas. Esa plantilla **no se tocó**: su campo `estado_verificacion` requiere revisión humana.

**Bonos del MEF, agosto de 2025:** el índice del Internet Archive lista dos capturas (2025-09-20 y 2025-09-27, estado 200), pero la reproducción responde 404 en ambas, también en la versión en inglés. **No recuperable** por esta vía; queda registrado en `acquire.py`. Las tenencias siguen en 4 cortes: diciembre de 2023, 2024 y 2025, y agosto de 2026.
