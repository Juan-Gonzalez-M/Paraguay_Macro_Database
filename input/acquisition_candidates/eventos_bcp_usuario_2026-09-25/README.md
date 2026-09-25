# Calendario institucional del BCP 2011–2026 (compilación del usuario)

*2026-09-25. Brecha 1 del ranking (`proyectos/00_resumen_viabilidad.md` § 3.5). Fuera de la base DuckDB: nada de esto está integrado ni pasó por el flujo de candidatos, revisión y publicación.*

## 1. Qué hay

| Archivo | Qué es |
|---|---|
| `raw/BCP_eventos_politica_2011_2026.xlsx` | Libro del usuario tal como lo entregó (solo lectura; SHA-256 en `inventory.csv`). 111 eventos y 10 hojas vinculadas por `event_id`. |
| `raw/Informe_eventos_BCP_2011_2026.docx` | Informe del usuario que acompaña el libro. |
| `BCP_eventos_politica_2011_2026_v2.xlsx` | **Versión 2**: el mismo libro más 11 eventos agregados al verificarlo (§ 3). No se modificó ninguna celda original: 3.902 celdas comparadas, 0 diferencias. |
| `Informe_eventos_BCP_2011_2026_v2.docx` | El mismo informe más el «Anexo C» con los eventos agregados. |
| `agregar_eventos.py` | Genera la versión 2 desde `raw/`. Cada fila nueva está escrita en el script, con su evidencia. |
| `fuentes_a_verificar.csv` | 14 fuentes para abrir en el navegador, por prioridad, con columnas para anotar el resultado. |
| `verificacion/` | Evidencia del contraste (§ 2) y los scripts que la generan. |

Para regenerar: `~/.venvs/edh/bin/python agregar_eventos.py` (desde esta carpeta; requiere `openpyxl` y `python-docx`).

## 2. Verificación (2026-09-25)

**Estructura:**
- 111 `event_id` únicos, todos con al menos una fuente.
- Las hojas secundarias solo remiten a eventos que existen.
- Los conteos por familia coinciden con la tabla del informe.
- Solo `REL_2021_EXT` entra en vigor antes de anunciarse, y es un reemplazo retroactivo declarado.

**Estado de verificación:** los rótulos `verificado_fuente_BCP` / `verificado_indice_BCP` **los puso quien compiló el libro**. No son una verificación independiente ni una revisión humana de este repositorio.

**Contraste con fuentes independientes:**

| Afirmación | Contraste | Resultado |
|---|---|---|
| Meta 5% → 4,5% → 4% → 3,5% (INF_*) | Comunicados del CPM (`web_brechas_2026-09-23`): 4,5% hasta el 22-02-2017 y 4,0% desde el 22-03-2017; el 19-12-2024 el comunicado dice que el Directorio «decidió recientemente» bajarla a 3,5% | Coincide |
| Rango de 5% ± 2,5% en 2011 | Comunicado del CEOMA del 06-07-2011 (nota al pie) | Coincide |
| Ley 5476/15 promulgada el 25-08-2015 | Fuente jurídica secundaria (Vouga Abogados), que además da vigencia desde el 25-09-2015 | Coincide |
| SPI: piloto el 23-05-2022, 24/7 desde el 04-07-2022 | BCP y prensa | Coincide |
| Pautas compensatorias 2016–2018 (FX_*) | Ventas diarias del BCP al sector financiero en la base (`verificacion/fx_pauta_vs_ventas_2016_2018.csv`) | Mixto, como se esperaba: la pauta es oferta, no ejecución. Coinciden enero de 2016 (USD 8 millones × 20 días) y el segundo semestre de 2018 (moda de USD 5 millones); en otros meses la venta difiere mucho. |

**Fuentes citadas** (`verificacion/fuentes_en_internet_archive.csv`):
- Solo 3 de las 96 URLs tienen copia en el Internet Archive. Eso no prueba que no existan: casi todas son del sitio nuevo del BCP (subidas en 2025), que el archivo casi no tiene, y el BCP bloquea a los clientes automáticos (no se sortea).
- Una URL tiene el identificador mal copiado (`…aa4d8f69-4a09-4d15-c6279e94ee20`). La correcta figura en otra fila, así que es un error de copia, no una fuente inventada.
- La verificación real queda en `fuentes_a_verificar.csv`.

## 3. Eventos agregados en la versión 2

Hay dos tipos de evidencia, anotados en `verification_status` (y explicados en la hoja «Guía»):
- **`verificado_fuente_BCP_archivo`**: comunicado del BCP leído en una copia del Internet Archive. El SHA-256 está en `web_brechas_2026-09-23/inventory_archivo.csv`.
- **`inferido_serie_diaria_BCP`**: deducido de las tasas diarias FPD/FPL de la base y del calendario del CPM (`verificacion/corredor_vs_tpm.csv`). **No hay documento; no es una verificación.**

| event_id | Fecha | Qué | Evidencia |
|---|---|---|---|
| REL_2020_0316_PKG | anuncio 2020-03-16 | Primeras medidas COVID: renovación, refinanciación y reestructuración, bienes adjudicados, encaje, FPL, LRM | comunicado |
| RES_2020_0316_USE | 2020-03-16 | Uso de un porcentaje del encaje para liquidez (el porcentaje no se publica) | comunicado |
| COR_2020_0316_FPL | anuncio 03-16, vigencia 03-17 | FPL a 1 día de 4,50% a 3,50%; tramos de TPM + 200/300 a TPM + 75/125 pb | comunicado |
| COR_2020_0316_LRM | 2020-03-16 | Menor penalidad por cancelación anticipada de LRM (valores no publicados) | comunicado |
| RES_2020_0330_RELEASE | 2020-03-30 | Liberación de encaje MN y ME, ~USD 740 millones | comunicado |
| REL_2020_0330_WINDOW | 2020-03-30 | Ventanilla de liquidez hasta 12 meses, USD 760 millones (probablemente la FCE ya registrada: relación `mismo_acto_probable`) | comunicado |
| COR_2013_0411_FPD | vigencia 2013-04-11 | FPD fijada en TPM − 100 pb | inferido |
| COR_2015_0320 | 2015-03-20 | Corredor de ± 100 a ± 75 pb | inferido |
| COR_2015_0916 | 2015-09-16 | Corredor de ± 75 a − 25 / + 100 pb, sin cambio de TPM | inferido |
| COR_2019_0610 | 2019-06-10 | FPL de TPM + 100 a + 50 pb, sin cambio de TPM | inferido |
| COR_2020_0323 | 2020-03-23 → 24 | La FPD sube 50 pb un día y vuelve (sin decisión conocida; puede ser un error de la serie) | inferido |

La familia **«Corredor»** es nueva: facilidades permanentes y LRM, separadas de las decisiones de TPM. Esas decisiones siguen en el calendario del CPM (`web_brechas_2026-09-23/extraidos/`), completo de 2010-01 a 2026-07, y no se duplican en el libro.

## 4. Qué sigue faltando

- **Pautas cambiarias:** faltan 2011–2013 y 2019–2026 (`FX_2019_FRAME` no aclara si siguieron los anuncios mensuales).
- **Matriz completa de encaje** por moneda, plazo y fecha (pendiente según el propio libro).
- **Documentos de los cambios del corredor inferidos:** resoluciones del Directorio de 2013, 2015 y 2019.
- **Eventos fuera del BCP** que usan varios proyectos: regla fiscal (Ley 5098/2013, emergencia de 2020), reforma tributaria de 2019, combustibles.

## 5. Uso

- Es una compilación secundaria. Antes de usar un evento como shock en un estudio de eventos, verificar su fuente (`fuentes_a_verificar.csv`) y la fecha efectiva.
- No mezclar filas `inferido_serie_diaria_BCP` con eventos documentados sin decirlo.
- **No se publica** (decisión del usuario, 2026-09-25): ni los originales, ni la versión 2, ni la evidencia que reproduce su contenido (`fuentes_a_verificar.csv`, `verificacion/fuentes_en_internet_archive.csv`, `verificacion/fx_pauta_vs_ventas_2016_2018.csv`). Todo queda local (ver `.gitignore`). El repositorio versiona este README, el inventario con los SHA-256, `agregar_eventos.py` y los scripts de verificación, que permiten regenerar todo a partir de los originales.
