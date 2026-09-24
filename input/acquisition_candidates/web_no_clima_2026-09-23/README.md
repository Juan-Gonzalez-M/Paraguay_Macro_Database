# Insumos públicos adicionales, fuera de clima

Adquisición exploratoria del 23 de septiembre de 2026. Esta carpeta está separada de `input/current/`, del archivo de vintages y de DuckDB. Se conservaron los bytes publicados sin interpretar ni modificar valores. **Ningún archivo de esta carpeta está validado para uso econométrico o incorporado a la base.**

`inventory.csv` registra por archivo la página fuente, URL directa, URL final, momento de recuperación UTC, tipo declarado, tamaño y SHA-256. `acquire_public.py` documenta la selección y permite repetir la descarga. `attempts.jsonl` registra también los accesos fallidos. Los archivos fuente de `raw/` y los catálogos HTML de `catalogs/` se mantienen locales y están excluidos de Git mediante `.gitignore`.

## Descargado

| Fuente | Archivos originales | Qué permite revisar | Limitación principal |
|---|---:|---|---|
| [INE, serie comparable EPHC](https://www.ine.gov.py/microdatos/microdatos.php) | 54 archivos: tres CSV, dos diccionarios y un cuestionario para **cada año 2008–2016** | Brecha de microdatos laborales anterior a 2017 (N2, F5). | Los CSV tienen separador `;` y marca UTF-8; cambian nombres de variables. Se debe auditar factores, cobertura y comparabilidad antes de concatenar. |
| [INE, EIGyCV 2011/12](https://www.ine.gov.py/microdato/encuesta-de-ingresos-y-gastos-y-condiciones-de-vida-2011-12) | 4 bases originales `.dta` y 9 documentos PDF | Gastos de hogares y una posible exploración de heterogeneidad. | **No es la EPF 2015/16** usada para construir la canasta del IPC base diciembre 2017. No atribuirle ponderadores oficiales ni cobertura nacional completa sin revisar su diseño. |
| [MEF, bonos](https://www.mef.gov.py/en/node/4605) | 1 Excel de resultados de subastas 2006–2026 y 6 planillas de bonos en circulación | Brecha de emisiones y subastas del Tesoro (C3). | La planilla de subastas tiene hojas por año, pero no hoja individual `2011`; 2024–2026 tienen gran cantidad de columnas formateadas. Se deben verificar cobertura, campos y unidades. No incluye tenencias identificadas como tales. |
| [MEF, ley de presupuesto](https://www.mef.gov.py/marco-legal/ley-de-presupuesto) | Leyes del PGN aprobado 2025 y 2026 en PDF | Presupuesto aprobado para N1; distinguir de ejecución mensual existente. | Dos años y documentos PDF, no una serie histórica estructurada. |
| [INCOOP, balances CAC tipo A](https://www.incoop.gov.py/?page_id=10202) | 9 planillas que abarcan 2017–2025; el archivo de 2025 incluye varios cortes | Panel preliminar por cooperativa para C2. | El INCOOP declara que son estados remitidos por las entidades, **referenciales, no validados ni certificados**. Cobertura solo de cooperativas de ahorro y crédito tipo A; no contiene préstamos individuales. |
| [IPS, anuarios estadísticos](https://portal.ips.gov.py/sistemas/ipsportal/contenido.php?c=289) | 12 PDF, años 2014–2025 | Posible serie de cotizantes del IPS para empleo formal (N2). El anuario 2024 contiene cotizantes y beneficiarios por mes, con valores mensuales de titulares. | El IPS cubre a sus asegurados, no a todo el empleo formal. La definición y comparabilidad entre anuarios aún requieren revisión; los PDF no son una serie estructurada. |
| [MEF, SITUFIN](https://www.mef.gov.py/es/situfin) | 2 Excel de Administración Central: mensual 2003–2026 y anual 2003–2025 | Contrastar y ampliar la documentación de variables fiscales de Administración Central (N1). | **No es una serie consolidada del sector público no financiero (SPNF)**. Hay que revisar hojas, unidades, revisiones y consistencia con la base antes de usarla. |
| [MTESS, reajuste salarial 2025](https://www.mtess.gov.py/?p=30682) y [2026](https://www.mtess.gov.py/?p=36371) | 2 páginas oficiales HTML y la resolución PDF 670/2026 | Evidencia inicial para un calendario de intervenciones salariales; las páginas distinguen fecha de publicación, decreto y vigencia. | Dos episodios no bastan para identificar un efecto causal; falta la cronología completa y un grupo de comparación o diseño de identificación. No se descargó la resolución 677/2025. |

Hay 9 páginas HTML conservadas como evidencia. **Total: 109 archivos, 1.105.527.662 bytes.** La base transaccional EIGyCV pesa 746.020.218 bytes. Todos los SHA-256 del inventario coinciden con los archivos locales; no quedaron descargas `.part`. Las 18 planillas Office modernas pasan la prueba de integridad ZIP. Esas comprobaciones acreditan conservación y legibilidad básica, no calidad estadística. En el anuario IPS 2024 se comprobó directamente la tabla «Cotizantes / beneficiarios por mes» (página impresa 20); para los demás años solo se confirmó la descarga e identidad desde el catálogo.

`attempts.jsonl` conserva fallos iniciales de URLs del INE con espacios sin codificar; se corrigió el método y todos esos archivos figuran luego como descargados en `inventory.csv`. Los intentos BCP 403 sí permanecen pendientes.
Un primer barrido del catálogo IPS también alcanzó enlaces PDF de la navegación general; esos ocho archivos ajenos a los anuarios se retiraron de `raw/` y la selección se limitó a los enlaces asociados explícitamente a «Año» en el catálogo. Los intentos y hashes de ese barrido permanecen en `attempts.jsonl` como registro de la corrección; no aparecen en el inventario actual.
La nota y la resolución MTESS de 2024 figuran en buscadores, pero ambas URLs devolvieron HTTP 404 a este cliente al comprobarlas; no hay copia local y los intentos constan en `attempts.jsonl`. La información que se pudiera leer en resultados de búsqueda no se convirtió en dato adquirido.

## Localizado, pero no descargado

El portal del BCP devuelve **HTTP 403 con desafío Cloudflare** a este cliente tanto en la página como en el enlace directo. Se intentaron y registraron los siguientes recursos sin guardar la respuesta de bloqueo como dato:

- [Metodología IPC base diciembre 2017](https://www.bcp.gov.py/en/web/institucional/w/indice-de-precios-al-consumidor-ipc-metodologia-base-diciembre-2017): su anexo 2 contiene códigos y ponderaciones de la canasta promedio, incluidos artículos. **No se descargó el PDF.** Quedan pendientes ponderadores por grupo de hogares y microprecios.
- [Boletines estadístico-financieros, formato clásico](https://www.bcp.gov.py/en/formato-clasico): el sitio enumera ediciones mensuales 2011–2015 de bancos y financieras. Se probó el boletín bancario de diciembre de 2011; **no se descargó**. Queda por revisar además continuidad de campos y entidades.
- [Serie histórica de operaciones cambiarias del BCP](https://www.bcp.gov.py/operaciones-cambiarias-del-bcp1): enlace a un `.xlsx` oficial, **no descargado**. Su frecuencia, campos y período permanecen sin verificar.
- [Comunicados del CPM](https://www.bcp.gov.py/en/comunicados-del-cpm): catálogo visible en la web, pero sin copias locales por el mismo bloqueo. La fecha y hora de anuncio no se infieren automáticamente de la fecha de reunión.

El acceso por el visor web de consulta no equivale a disponer de los bytes originales. Para completar estos cuatro bloques hará falta descargar manualmente desde un navegador que abra el sitio, o recibir los archivos por un canal institucional; registrar entonces URL, hora UTC de recuperación y SHA-256 antes de cualquier análisis.

## Alcance de procedencia

La hora de recuperación en `inventory.csv` es **evidencia de acceso**, no la fecha original de publicación. Ningún archivo se registró como vintage de la base ni se modificó el historial de fuentes. La comparación con archivos ya integrados, el examen de licencias específicas, los diccionarios de variables, los cambios metodológicos y las pruebas de series quedan para una etapa posterior.
