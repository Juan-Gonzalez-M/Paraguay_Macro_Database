# 20 · F4 — Pagos instantáneos, competencia y movilidad de depósitos

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

## 1. Resumen y pregunta de investigación

El volumen agregado del Sistema de Pagos Instantáneos (SPI, operativo desde mayo de 2022) no muestra la adopción por cliente, la movilidad de depósitos ni las externalidades de red. La ficha pide tratarlo como **piloto de monitoreo**, sin inferir estrés a partir del crecimiento normal.

- **Pregunta:** ¿la adopción y la participación en el SPI alteran el uso de efectivo, la movilidad de depósitos, la competencia entre entidades y la gestión intradía de reservas?
- **Estimando (factible):** descripción de la adopción agregada y por entidad (alias registrados/operativos, montos SPI por entidad), sustitución entre rieles (SPI vs. ACH, LBTR, cheques, tarjetas) y asociación con el efectivo y los depósitos transaccionales.
- **Estimando (no factible con estos datos):** efecto causal del acceso o la adopción en resultados de cliente o entidad; requiere rollout exógeno o datos cliente-día.

## 2. Estrategia empírica propuesta

1. **Tablero de monitoreo mensual (2022-05 → 2026):** operaciones e importes SPI (totales, por día, franja horaria y funcionalidad), alias registrados y operativos por entidad, participantes vía servicio patrocinador.
2. **Sustitución entre rieles:** descomposición de la participación de cada riel (SPI, ACH, LBTR cliente-cliente, cheques compensados, tarjetas de débito/crédito/prepagas) en el valor y el número de pagos; event study alrededor del lanzamiento del SPI (2022-05) y de nuevas funcionalidades (QR, iniciadores de pago).
3. **Efectivo y depósitos:** relación entre la adopción del SPI y la demanda de efectivo (M0/M1) y los depósitos a la vista por entidad (panel), con controles de ciclo y TPM.
4. **Competencia:** concentración (HHI) de los alias operativos por entidad frente a la cuota de depósitos a la vista; cambios en canales físicos (cajeros, corresponsales) por entidad.

## 3. Series extraídas

Boletín de sistemas de pago completo (38 hojas), bancarización y agregados monetarios.

{{TABLA_SERIES}}

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_depositos_entidad_mes.csv` | Depósitos por tipo (vista, cuenta corriente, plazo fijo, CDA) × moneda × entidad (millones de Gs.) | {{RANGO:panel_depositos_entidad_mes.csv}} | Panel provisional |
| `panel_canales_personal_entidad_mes.csv` | Cajeros automáticos, dependencias, terminales de autoservicio, corresponsales no bancarios y personal por entidad | {{RANGO:panel_canales_personal_entidad_mes.csv}} | Panel provisional |
| `panel_tarjetas_credito_entidad_mes.csv` | Tarjetas de crédito: cantidad y saldo por entidad | {{RANGO:panel_tarjetas_credito_entidad_mes.csv}} | Panel provisional |
| `entidades.csv` | `entity_id` → nombre y tipo de propiedad | 29 entidades | Referencia |

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Nombres:** las series se nombran `pag_<hoja>_<etiqueta>`; el mapa completo hoja → descripción está en `diccionario_series.csv`. En `SIPAP_07` las etiquetas vienen vacías en la base: `column_3` = cantidad de operaciones y `column_4` = importe en Gs. (identificados por magnitud).
- **Transformaciones:** `log` de cantidades e importes; importes en PYG deflactados por el IPC; participaciones por riel sobre el total de pagos electrónicos; variaciones interanuales por la estacionalidad (diciembre).
- **Entidades:** los montos SPI por entidad (`SIPAP_08`) son **no comprobados** (identidad posicional); verificar el orden de entidades contra el Excel antes de unirlos a los paneles. Los alias por entidad (`SIPAP_14`, `SIPAP_15`) sí son preliminares.
- **Muestra:** el SPI tiene ~50 observaciones mensuales; cualquier regresión es exploratoria.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Transacciones SPI por entidad-día (y remitente-receptor anonimizado) | Movilidad de depósitos y estrés; nivel "suficiente/óptimo" | BCP – Sistemas de Pago (SIPAP) |
| Fechas de incorporación de cada entidad, límites, horarios y precios del SPI | Variación de rollout para un event study | BCP – normativa y comunicados del SPI |
| Adopción por cliente/comercio (QR), ubicación | Externalidades de red | BCP; entidades participantes; Bancard |
| Saldos intradía de reservas | Liquidez intradía (vínculo con A1) | BCP – LBTR |
| Retiros de efectivo en cajeros por entidad | Sustitución de efectivo | Bancard / Infonet; SIB |

## 6. Evaluación de viabilidad

**Media como piloto de monitoreo**: el boletín de pagos ofrece el SPI desde 2022-05 con desagregaciones por día, horario, funcionalidad y entidad, además de todos los rieles alternativos desde 2013 y los paneles de depósitos y canales. **Baja para inferencia causal**: no hay datos cliente o entidad-día ni una variación de rollout documentada.

## 7. Supuestos que debes revisar

1. `pag_sipap_07_*_column_3/column_4` = cantidad e importe del SPI (inferido por magnitud; la base no tiene etiqueta).
2. Varias series de montos del boletín tienen unidad no resuelta; las leo como guaraníes (o USD/EUR según la hoja).
3. Las series por entidad del boletín identifican a la entidad por posición en la hoja; no las uní con los códigos SIB.
4. El SPI comenzó en mayo de 2022; valores anteriores de SIPAP_07 a SIPAP_12 no existen (no son ceros).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pagos instantáneos y bancos

| Referencia | Qué respalda en este proyecto |
|---|---|
| Duarte, A., Frost, J., Gambacorta, L., Koo Wilkens, P. y Shin, H. S. (2022). "Central Banks, the Monetary System and Public Payment Infrastructures: Lessons from Brazil's Pix." BIS Bulletin 52. **[DT]** | Descripción de la adopción de Pix y de sus efectos en competencia e inclusión. Es el **modelo de tablero** (paso 1) y el caso regional más comparable. |
| Sarkisyan, S. "Instant Payment Systems and Competition for Deposits." SSRN 4176990. **[DT]** | Con variación por municipio en la exposición a Pix, encuentra que los **depósitos de bancos pequeños crecen frente a los grandes**. Respalda la pregunta de competencia (paso 4, HHI de alias frente a cuota de depósitos) y muestra qué datos harían falta para una versión causal. |

### 8.2 Adopción, externalidades de red y efectivo

| Referencia | Qué respalda |
|---|---|
| Higgins, S. (2024). "Financial Technology Adoption: Network Externalities of Cashless Payments in Mexico." *American Economic Review*, 114(11), 3469–3512. **[Revista]** | Externalidades de red en la adopción de pagos electrónicos, con un despliegue escalonado como fuente de variación. Muestra el tipo de rollout que la ficha pide para identificar. |
| Crouzet, N., Gupta, A. y Mezzanotti, F. (2023). "Shocks and Technology Adoption: Evidence from Electronic Payment Systems." *Journal of Political Economy*, 131(11), 3003–3065. **[Revista]** | Complementariedades en la adopción de billeteras tras la desmonetización india. Respalda medir la adopción como fenómeno de red (alias operativos por entidad). |
| Chodorow-Reich, G., Gopinath, G., Mishra, P. y Narayanan, A. (2020). "Cash and the Economy: Evidence from India's Demonetization." *Quarterly Journal of Economics*, 135(1), 57–103. **[Revista]** | Relación entre efectivo, pagos electrónicos y actividad. Respalda la relación SPI–M0 (paso 3). |
| Alvarez, F. y Lippi, F. (2009). "Financial Innovation and the Transactions Demand for Cash." *Econometrica*, 77(2), 363–402. **[Revista]** | Modelo de demanda de efectivo con innovación financiera. Respalda la especificación de la demanda de M0/M1 con tasa, actividad y tecnología de pagos. |
| Jack, W. y Suri, T. (2014). "Risk Sharing and Transactions Costs: Evidence from Kenya's Mobile Money Revolution." *American Economic Review*, 104(1), 183–223. **[Revista]** | Referencia clásica de efectos de una tecnología de pagos con variación geográfica en el acceso. Útil para la brecha "datos cliente-día o por localidad". |

### 8.3 Antecedentes para Paraguay

No encontré evaluaciones académicas del SPI. Según cifras del BCP difundidas por la prensa, el SPI procesó pagos por ≈ 5% del PIB en 2022, 14% en 2023 y 24% en 2024, y concentra más del 97% de las transacciones del SIPAP. El proyecto sería la **primera descripción sistemática**, pero sin variación exógena queda como monitoreo, igual que Duarte et al. (2022) para Pix.
