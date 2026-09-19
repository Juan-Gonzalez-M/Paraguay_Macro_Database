# Revisión combinada CDA + TCN — 2026-09-19

## Resultado

El candidato aislado `accepted_for_review_20260919_103853.duckdb` fue aceptado por
el pipeline con cero errores de release. No fue promovido. La base publicada
permanece byte por byte en el producto CDA anterior.

| Artefacto | Identidad |
|---|---|
| Candidato | SHA-256 `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4` |
| Build | `build:6928154663966c1f7d0ee63d` |
| Attempt | `attempt:1441a2cb2abc7fa63b773cd0` |
| Source bundle | `release:a8120d5735c5ec0d32eddf42` |
| Producción sin cambio | SHA-256 `11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876` |

## CDA

- 421 identidades y 21.839 observaciones.
- Las 35 identidades de `CDA_ML_102021` antes creadas como encabezado faltante se
  fusionan con las curvas existentes: H = `BANCOS`, I = `FINANCIERAS`.
- Migración desde producción: 421 idénticas, 35 fusionadas y 15 eliminadas.
- Las 15 eliminadas corresponden exclusivamente a los nodos que el dueño de la
  fuente ordenó omitir: `Monto Capital Original` y el nodo adicional anómalo.
- No quedan identidades `UNLABELED`.

## Tipo de cambio nominal (TCN)

- Fuente exacta: SHA-256
  `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4`.
- Dos identidades continuas, `Compra` y `Venta`, no una identidad por pestaña o
  año.
- 3.502 observaciones por identidad; 7.004 observaciones en total.
- Unidad `PYG_PER_USD`, moneda `PYG/USD`, escala 1.
- Los 4.156 tokens fuente `ND` permanecen en evidencia cruda y no generan hechos:
  representan fines de semana o feriados sin cotización. No se imputan, rellenan
  ni convierten en cero.

## Reconciliación y aislamiento

- Para CDA y TCN: balance de celdas cero, reutilización cero, celdas no mapeadas
  cero, celdas no clasificadas cero y defectos de parser cero.
- Comparación bidireccional contra producción para todos los hechos ajenos a CDA
  y TCN: cero diferencias.
- LRM permanece en 940 identidades y 10.334 hechos.
- CDA y TCN permanecen fuera de `research.*`; esta revisión los admite en la capa
  exploratoria, no los certifica todavía como series de investigación.

## Procedencia y advertencias

Se registra la confirmación del dueño de la fuente de que el archivo TCN fue
descargado directamente del BCP. La URL exacta, la marca temporal verificable de
descarga, la fecha oficial de publicación, la licencia y el permiso de
redistribución siguen sin evidencia independiente y permanecen explícitamente
desconocidos. No se presentan como verificados.

## Pruebas

- Pruebas focalizadas de CDA, TCN, scope y procedencia/missingness: pasan.
- Pruebas actualizadas de capa exploratoria y smoke completo del pipeline: pasan.
- Verificación independiente del candidato (`verify_candidate.R`): pasa.
- 141 de 141 vistas públicas enlazan desde una conexión nueva de solo lectura y
  `search_path` vacío.
- La suite completa sólo conserva el fallo ambiental conocido: seis paquetes R
  cargados directamente no coinciden con las versiones fijadas en `renv.lock`.
  No se instalaron ni actualizaron paquetes.

## Estado para la siguiente decisión

El candidato combinado está listo para una aceptación independiente y, si esa
revisión lo aprueba, para promoción mediante el mecanismo gobernado. No debe
promoverse manualmente ni reconstruirse para esa decisión.
