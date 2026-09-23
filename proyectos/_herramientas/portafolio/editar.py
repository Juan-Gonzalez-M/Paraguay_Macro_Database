# Genera la versión 2 del portafolio: fichas nuevas, programa G, mapa de datos, priorización
# y tabla de evaluación contra la base. Replica el formato XML de las fichas originales.
from xml.sax.saxutils import escape as esc

X = open('u/word/document.xml', encoding='utf-8').read()

def p_body(t):
    return ('<w:p><w:pPr><w:spacing w:after="100" w:line="259" w:lineRule="auto"/></w:pPr>'
            f'<w:r><w:t xml:space="preserve">{esc(t)}</w:t></w:r></w:p>')

def p_lead(bold, t):
    return ('<w:p><w:pPr><w:spacing w:after="100" w:line="259" w:lineRule="auto"/></w:pPr>'
            f'<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">{esc(bold)}</w:t></w:r>'
            f'<w:r><w:t xml:space="preserve"> {esc(t)}</w:t></w:r></w:p>')

def p_sec(t):
    return ('<w:p><w:pPr><w:spacing w:before="140" w:after="40"/></w:pPr><w:r><w:rPr><w:b/>'
            f'<w:color w:val="000000"/><w:sz w:val="21"/></w:rPr><w:t>{esc(t)}</w:t></w:r></w:p>')

def h2(t):
    return ('<w:p><w:pPr><w:pStyle w:val="Heading2"/><w:keepNext/><w:spacing w:before="280"/></w:pPr>'
            f'<w:r><w:rPr><w:color w:val="000000"/></w:rPr><w:t xml:space="preserve">{esc(t)}</w:t></w:r></w:p>')

def h1(t):
    return f'<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>{esc(t)}</w:t></w:r></w:p>'

def p_prog(bold, t):
    return ('<w:p><w:pPr><w:spacing w:after="80"/></w:pPr>'
            f'<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">{esc(bold)} </w:t></w:r>'
            f'<w:r><w:t>{esc(t)}</w:t></w:r></w:p>')

SECS = ["1. Motivación y contribución potencial", "2. Objetivo, pregunta y estimando",
        "3. Ejercicios empíricos posibles", "4. Escalera de datos",
        "5. Amenazas y requisitos de credibilidad", "6. Ruta de crecimiento"]

def ficha(titulo, factib, textos, carpeta, viab):
    out = h2(titulo) + p_lead("Clasificación de factibilidad:", factib)
    for s, t in zip(SECS, textos):
        out += p_sec(s) + p_body(t)
    out += p_lead("Datos y viabilidad (septiembre 2026):", f"{viab} Carpeta de trabajo: proyectos/{carpeta}.")
    return out

F = {}
F['A2'] = ficha("A2  Sorpresas de política monetaria de alta frecuencia (nueva)",
 "Listo para ser diseñado empíricamente una vez fechado el calendario del COPOM; es infraestructura que habilita causalidad en A1, A3, C2, C3, E3 y B2.",
 ["Problema: la TPM responde a la inflación y a la actividad, por lo que su nivel no es un shock. Sin una medida de sorpresa, todos los proyectos de transmisión quedan en forma reducida. La contribución es una serie oficial de sorpresas monetarias para Paraguay, reutilizable en toda la agenda.",
  "Pregunta: ¿qué parte de cada decisión del COPOM fue sorpresiva para el mercado y cómo se transmite a tasas interbancarias, LRM, bonos y tipo de cambio? Estimando: sorpresa = cambio de tasas de mercado en la ventana del anuncio; respuesta de tasas y tipo de cambio a la sorpresa. Mecanismo: expectativas de trayectoria de la TPM. Evidencia: causal en sentido de alta frecuencia.",
  "Inicial: calendario del COPOM y ventanas diarias en el interbancario (call + REPO + tripartito) y en las facilidades; validación con días placebo. Intermedio: descomposición en sorpresa de nivel y de trayectoria usando LRM y curvas de bonos; proyecciones locales diarias. Frontera: ventanas intradía y forwards. Unidad: reunión-día; horizonte 0 a 60 días.",
  "Mínimamente necesario: fechas y horas de anuncio del COPOM y tasas diarias del interbancario. Suficiente: subastas de LRM, curvas de bonos en PYG, TCN diario y expectativas EVE. Ideal: tasas intradía y rendimientos secundarios de bonos del Tesoro. Óptimo: futuros o swaps de tasas. Metadatos: hora del anuncio, fecha de vigencia del nuevo corredor, reuniones sin cambio.",
  "Mercado interbancario poco profundo, días sin operaciones y anuncios fuera de horario. Exigir: sorpresas grandes en fechas COPOM y nulas en placebos, no predictibilidad con información pública previa, robustez a la definición de ventana. Un resultado de sorpresas pequeñas indica alta previsibilidad de la política y es informativo en sí mismo.",
  "Construir primero el calendario y la serie; publicarla como activo común. Luego usarla como instrumento de la TPM en A1, A3, C2, C3, E3 y B2."],
 "25_n4_sorpresas_monetarias",
 "Media-alta. Interbancario diario desde 2011; 40 fechas de cambio de TPM reconstruidas de los movimientos paralelos del corredor (2015–2026). Falta el calendario oficial del COPOM.")
F['A3'] = ficha("A3  Canal de crédito bancario de la política monetaria (nueva)",
 "Listo para ser diseñado en forma reducida; causal en la heterogeneidad cuando se combine con las sorpresas de A2.",
 ["Problema: el efecto agregado de la TPM sobre el crédito mezcla oferta y demanda. La heterogeneidad entre bancos (liquidez, capital, fondeo) permite aislar el componente de oferta si la demanda se absorbe con efectos fijos.",
  "Pregunta: ¿contraen más el crédito, ante una sorpresa contractiva, los bancos con menos liquidez, menos capital o fondeo más sensible a tasas? Estimando: interacción sorpresa × característica predeterminada del banco. Mecanismo: fricciones de financiamiento bancario. Evidencia: causal en la heterogeneidad, no en el nivel.",
  "Inicial: panel banco × sector × moneda × mes con características en t−1 y TPM/sorpresa EVE. Intermedio: sorpresas de alta frecuencia de A2 y efectos fijos sector × moneda × mes. Frontera: registro de crédito con prestatarios en varios bancos. Horizonte 0 a 12 meses.",
  "Mínimamente necesario: balance por banco y moneda, crédito por sector y TPM. Suficiente: sorpresas de A2, tasas implícitas por banco. Ideal: originaciones y tasas por banco-producto. Óptimo: registro de crédito. Metadatos: fusiones, cambios de clasificación y altas/bajas de entidades.",
  "Características bancarias correlacionadas con la cartera de clientes; pocos bancos (≈ 29). Exigir exposición predeterminada, efectos fijos de demanda, wild bootstrap, pre-tendencias. Heterogeneidad nula es evidencia de un canal de crédito débil.",
  "Depende de A2 para el tratamiento; comparte panel con C1, C2 y C5."],
 "29_n8_canal_credito_bancario",
 "Media (media-alta con A2). Panel completo de balance, crédito por sector y ratios por entidad desde 2016.")
F['C5'] = ficha("C5  Cambios regulatorios con exposición bancaria heterogénea (nueva)",
 "Listo para ser diseñado en el módulo de encaje; el módulo de tope a tarjetas requiere datos bancarios previos a 2016.",
 ["Problema: el crédito agregado no identifica oferta. Los cambios regulatorios fechados (encaje legal, tope a tasas de tarjetas) afectan de forma distinta a bancos con distinta exposición previa, lo que ofrece un diseño de diferencias en diferencias con tratamiento continuo.",
  "Pregunta: ¿cuánto crédito adicional otorga un banco más liberado por una reducción del encaje? ¿qué efecto tuvo el tope sobre precio, cantidad y acceso a tarjetas? Estimandos: elasticidad del crédito a la liquidez liberada; efecto del tope sobre tasas y saldos. Mecanismo: restricción de liquidez y racionamiento por precio. Evidencia: causal en el módulo de encaje.",
  "Inicial: calendario de cambios de encaje por moneda y plazo; exposición = Δ tasa × base encajable previa. Intermedio: Khwaja-Mian con efectos fijos sector × moneda × mes. Módulo tarjetas: serie interrumpida en el quiebre de octubre de 2015; DiD por banco si hay boletines previos. Horizonte 0 a 12 meses.",
  "Mínimamente necesario: fechas y valores de cada cambio, encaje y depósitos por banco y moneda. Suficiente: crédito por banco-sector-moneda. Ideal: base encajable por plazo residual y tasas por banco. Óptimo: registro de crédito. Metadatos: fecha de anuncio vs. vigencia, remuneración del encaje, excepciones.",
  "Cambios de encaje coincidentes con política monetaria (2020); pocos bancos. Exigir exposición predeterminada, placebos en fechas sin cambio, efectos fijos de demanda. En tarjetas, sin período previo por banco solo se sostiene una serie interrumpida del sistema.",
  "Cargar el calendario regulatorio (activo común con A1 y C2) y los boletines SIB 2011–2015."],
 "27_n6_regulacion_bancaria_did",
 "Media-alta (encaje) / media-baja (tarjetas). El tope se observa en octubre de 2015 (tasa promedio de tarjetas 48% → 17%), pero los paneles por banco empiezan en 2016.")
F['C6'] = ficha("C6  Medidas de alivio COVID, reprogramaciones y mora posterior (nueva)",
 "Requiere acotar el estimando por selección; viable como event study por banco con exposición sectorial previa.",
 ["Problema: las reprogramaciones masivas de 2020 pudieron evitar quiebras o sólo postergar la mora y reducir el crédito nuevo. La base publica la cartera acogida a la medida excepcional por banco, lo que permite medirlo.",
  "Pregunta: ¿los bancos que más reprogramaron tuvieron luego más mora, más reestructuraciones y menos crédito nuevo? Estimando: efecto de la intensidad de reprogramación (dic-2020) sobre resultados 2021–2024. Mecanismo: puente de liquidez vs. evergreening. Evidencia: forma reducida con selección.",
  "Inicial: trayectorias de la cartera COVID vigente y vencida por banco. Intermedio: event study con intensidad instrumentada por la exposición sectorial de 2019. Frontera: préstamo-prestatario con marca de reprogramación. Horizonte 0 a 48 meses.",
  "Mínimamente necesario: cartera COVID por banco, mora y crédito por sector. Suficiente: resoluciones de alivio fechadas, categorías de riesgo, previsiones. Ideal: registro de crédito con reprogramaciones. Óptimo: resultados de las empresas. Metadatos: plazos de las medidas, medidas posteriores por sequía.",
  "Bancos con clientes más frágiles reprogramaron más. Exigir pre-tendencias 2016–2019, instrumento sectorial, placebos entre bancos y financieras. Un efecto nulo sobre la mora sugiere que la medida funcionó como puente.",
  "Complementa D5 y C1; se fortalece con el registro de crédito."],
 "28_n7_alivio_covid",
 "Media. Cartera COVID ≈ 20 billones de Gs. en dic-2020 (≈ 11% del crédito) en 23 entidades; período previo desde 2016.")
F['D6'] = ficha("D6  Precios administrados de combustibles, inflación y expectativas (nueva)",
 "Requiere fechas exactas de ajustes; viable como estudio de eventos con componente discrecional.",
 ["Problema: los ajustes de combustibles son discretos y visibles para los hogares; su traspaso a la subyacente y a las expectativas es central para la política monetaria, pero responden al petróleo y al tipo de cambio.",
  "Pregunta: ¿cuánto y a qué velocidad se trasladan los ajustes a inflación total, subyacente y expectativas? Estimando: traspaso directo, indirecto y de segunda vuelta; respuesta de expectativas. Mecanismo: costos y señales de precios salientes. Evidencia: forma reducida; causal con componente discrecional.",
  "Inicial: cronología de ajustes y función de reacción del precio a Brent y tipo de cambio. Intermedio: LP mensuales sobre el componente discrecional; asimetría subas/bajas. Frontera: microprecios de transporte y fletes. Horizonte 0 a 12 meses.",
  "Mínimamente necesario: fechas y montos de ajustes, IPC por componentes. Suficiente: EVE, Brent, tipo de cambio. Ideal: subsidios y fondos de estabilización. Óptimo: precios por estación de servicio. Metadatos: producto, empresa, fecha de vigencia.",
  "Endogeneidad al petróleo y a la política. Exigir residualización, placebos sin ajuste, controles de estacionalidad. Traspaso nulo a expectativas de largo plazo indica anclaje.",
  "Comparte insumos con D4 y E3."],
 "31_n10_combustibles_expectativas",
 "Media. 41 variaciones mensuales del gasoil mayores a 3% desde 2015 (Cuadro 13 a, índice del gasoil).")
F['F6'] = ficha("F6  Shocks cambiarios de Argentina y economía fronteriza (nueva)",
 "Listo para ser diseñado como estudio de eventos agregado; el mecanismo geográfico requiere precios regionales.",
 ["Problema: F2 no puede identificar el arbitraje fronterizo con agregados. Las devaluaciones y controles cambiarios argentinos son shocks grandes, fechados y externos, un experimento natural para el canal fronterizo.",
  "Pregunta: ¿cómo afectan los saltos del peso al comercio bilateral, la reexportación bajo régimen de turismo, los precios transables y las remesas? Estimando: respuestas acumuladas por episodio frente a placebos (Brasil, no transables). Mecanismo: arbitraje de precios y demanda de no residentes. Evidencia: forma reducida con shocks externos.",
  "Inicial: cronología de episodios (oficial y paralelo) y estudio de eventos mensual. Intermedio: dosis-respuesta con Δ ARS/USD; heterogeneidad cepo vs. liberalización. Frontera: IPC por ciudad y aduanas por producto. Horizonte −6 a +12 meses.",
  "Mínimamente necesario: fechas de eventos, PYG/ARS, comercio con Argentina y Brasil. Suficiente: régimen de turismo, IPC por componentes, remesas por origen. Ideal: tipo de cambio paralelo, IPC regional. Óptimo: aduanas y cruces fronterizos. Metadatos: gap oficial-paralelo, fechas de medidas del BCRA.",
  "Shocks regionales simultáneos (Brasil, commodities). Exigir placebos, controles regionales, episodios omitidos uno a uno. Sin concentración en bienes fronterizos, renombrar como pass-through regional.",
  "Alimenta F2 y G5; requiere IPC regional para el mecanismo geográfico."],
 "26_n5_shocks_argentina",
 "Media-alta. 15 meses con devaluación oficial > 10% (2002–2024); comercio bilateral, régimen de turismo, precios y remesas disponibles.")
F['F7'] = ficha("F7  SPI y demanda de efectivo (nueva)",
 "Piloto descriptivo; no hay variación para causalidad con los datos actuales.",
 ["Problema: el SPI puede sustituir efectivo, cheques y ACH, con implicancias para la demanda de dinero y la transmisión. Medirlo complementa el tablero de F4.",
  "Pregunta: ¿cuánto sustituyó el SPI a otros medios de pago y al efectivo? Estimando: quiebre en tendencias y participaciones tras 2022-05 y tras cada hito. Mecanismo: menor costo de transferir. Evidencia: descriptiva.",
  "Inicial: participaciones por riel y demanda de efectivo proyectada fuera de muestra. Intermedio: hitos múltiples (QR, alias, iniciadores). Frontera: adopción por entidad y cliente. Horizonte mensual.",
  "Mínimamente necesario: volúmenes por riel y M0. Suficiente: hitos fechados y datos por entidad. Ideal: entidad-día. Óptimo: cliente-día. Metadatos: límites, horarios y precios.",
  "Una sola fecha nacional, coincidente con el ciclo de 2022. Exigir contrafactual con controles y bandas; no afirmar causalidad.",
  "Integrar a F4 como módulo si no aparece variación entre entidades."],
 "30_n9_spi_efectivo",
 "Media (descriptivo) / baja (causal). SPI desde 2022-05; todos los rieles desde 2013.")
F['G1'] = ficha("G1  Política fiscal: ciclicidad, estabilizadores y multiplicadores (nueva)",
 "Listo para ser diseñado empíricamente; la identificación con ingresos binacionales requiere defender su exogeneidad.",
 ["Problema: la agenda no cubre la política fiscal, que opera bajo una regla de déficit con suspensiones. La base tiene 23 años de datos fiscales mensuales y las regalías de Itaipú y Yacyretá son un ingreso poco ligado al ciclo doméstico.",
  "Pregunta: ¿es el gasto procíclico, cambia con la regla y cuál es el multiplicador? Estimandos: elasticidad del gasto al ciclo; multiplicador acumulado por tipo de gasto; respuesta a ingresos binacionales. Mecanismo: estabilizadores y demanda. Evidencia: forma reducida; causal con supuestos de rezago o ingresos externos.",
  "Inicial: hechos estilizados y ciclicidad con brecha del IMAEP sin agro ni binacionales. Intermedio: LP mensuales con shocks de gasto (Blanchard-Perotti) e instrumentos binacionales. Frontera: presupuesto vs. ejecución y SPNF consolidado. Horizonte 0 a 24 meses.",
  "Mínimamente necesario: ingresos y gastos mensuales, actividad, precios. Suficiente: binacionales, deuda, cronología de la regla. Ideal: presupuesto aprobado y SPNF. Óptimo: datos por programa y región. Metadatos: cambios de clasificación, suspensiones de la regla.",
  "Estacionalidad fuerte; gasto endógeno. Exigir desestacionalización, supuestos explícitos de identificación, robustez sin 2020–2021.",
  "Abre un programa fiscal; dialoga con A1 (Tesoro), C3 (deuda) y F3 (energía)."],
 "22_n1_politica_fiscal",
 "Media-alta. Estado de operaciones mensual MEFP 2001 (2003–2026) y binacionales desde 1994.")
F['G2'] = ficha("G2  Mercado laboral, informalidad y ciclo (nueva)",
 "Listo para una versión descriptiva; muestra corta.",
 ["Problema: con ≈ 60% de informalidad, el ajuste laboral al ciclo se da por composición más que por desempleo, lo que cambia la medida de holgura relevante para la política monetaria.",
  "Pregunta: ¿por qué margen se ajusta el empleo y qué holgura explica la inflación? Estimandos: coeficientes de Okun por margen; elasticidad de la informalidad al ciclo; pendiente de Phillips con holgura ampliada. Evidencia: descriptiva.",
  "Inicial: hechos estilizados trimestrales 2017–2026. Intermedio: Okun por margen y Phillips con subocupación. Frontera: microdatos y transiciones. Horizonte trimestral.",
  "Mínimamente necesario: tasas y ocupados por formalidad. Suficiente: sectores, categorías, horas, ingresos. Ideal: microdatos EPHC. Óptimo: registros IPS. Metadatos: cambios de marco muestral.",
  "38 trimestres y pandemia. Exigir robustez sin 2020 y bandas amplias.",
  "Puente entre D1/G1 y D4/F5."],
 "23_n2_mercado_laboral",
 "Media. Anexo EPHC completo (2017–2026); desagregaciones por sexo e ingresos no comprobadas.")
F['G3'] = ficha("G3  Ajustes del salario mínimo: precios de servicios e informalidad (nueva)",
 "Viable como estudio de eventos; anticipación por fórmula limita la causalidad.",
 ["Problema: los ajustes del salario mínimo son eventos fechados con intensidad variable, relevantes para la inflación de servicios y la informalidad.",
  "Pregunta: ¿cuánto se trasladan los ajustes a precios de servicios, salarios y formalidad? Estimando: elasticidad de precios de servicios vs. bienes; cambio en la formalidad. Evidencia: estudio de eventos.",
  "Inicial: 12 ajustes desde 2010 y LP de IPC por componente. Intermedio: exposición sectorial y sorpresa respecto de la fórmula. Frontera: microdatos. Horizonte 0 a 12 meses.",
  "Mínimamente necesario: fechas y montos (en la base). Suficiente: decretos y fórmula, IPC por componente, EPHC. Ideal: distribución salarial por sector. Óptimo: IPS. Metadatos: anuncio vs. vigencia.",
  "Anticipación y ciclo. Exigir placebos en bienes, comparación de ajustes cercanos y alejados de la fórmula.",
  "Módulo natural de G2."],
 "32_n11_salario_minimo",
 "Media. Tramos de vigencia del salario mínimo en la base (1980–2026).")
F['G4'] = ficha("G4  Paraguay en el panel regional: shocks globales y vulnerabilidad (nueva)",
 "Listo para ser diseñado empíricamente con datos del FMI ya incorporados.",
 ["Problema: todas las fichas son de un país. Nueve países sudamericanos con datos homogéneos permiten separar shocks globales de respuestas específicas y ubicar a Paraguay.",
  "Pregunta: ¿cómo responden flujos, tipo de cambio, inflación y bancos a shocks globales y qué los amortigua? Estimando: respuestas medias y heterogéneas en LP de panel. Evidencia: forma reducida con shocks comunes.",
  "Inicial: benchmarking. Intermedio: LP de panel con interacciones (reservas, intervención, dolarización). Frontera: flujos de alta frecuencia y EMBI. Horizonte trimestral y mensual.",
  "Mínimamente necesario: balanza de pagos, reservas, tipo de cambio, IPC. Suficiente: FSI, intervención proxy, términos de intercambio. Ideal: EMBI. Óptimo: intervención oficial diaria de pares. Metadatos: definiciones del FMI.",
  "Heterogeneidad institucional (Ecuador dolarizado, Argentina con inflación alta). Exigir submuestras y Driscoll-Kraay.",
  "Complementa B1, B2 y C1."],
 "24_n3_panel_regional",
 "Media-alta. 192 de 198 combinaciones país-indicador disponibles.")
F['G5'] = ficha("G5  Remesas familiares y shocks en los países de origen (nueva)",
 "Módulo acotado; útil dentro de F6 o G4.",
 ["Problema: las remesas por origen permiten un diseño shift-share, aunque su peso macro es pequeño.",
  "Pregunta: ¿cómo responden las remesas a los ciclos de origen y cuánto amortiguan el consumo? Estimando: elasticidades y efecto IV en consumo. Evidencia: forma reducida.",
  "Inicial: descomposición por origen. Intermedio: shift-share con desempleo de España y EE.UU. y tipo de cambio argentino. Frontera: remesas por departamento. Horizonte mensual y trimestral.",
  "Mínimamente necesario: remesas por origen y shocks de origen. Suficiente: consumo privado. Ideal: remesas por destino. Óptimo: microdatos de hogares receptores.",
  "Peso macro pequeño; instrumento débil en consumo. Exigir primera etapa fuerte.",
  "Integrar como módulo de F6 o G4."],
 "33_n12_remesas",
 "Media-baja. Remesas por origen 2008–2026.")

def insertar_antes(marca, contenido):
    global X
    i = X.find(marca); assert i > 0, marca
    s = X.rfind('<w:p>', 0, i)
    X = X[:s] + contenido + X[s:]

insertar_antes('B1  Intervención cambiaria', F['A2'] + F['A3'])
insertar_antes('D1  ENSO no lineal', F['C5'] + F['C6'])
insertar_antes('E1  Combinación y reconciliación', F['D6'])
insertar_antes('>Mapa transversal de datos<', F['F6'] + F['F7'] + F['G1'] + F['G2'] + F['G3'] + F['G4'] + F['G5'])

# Programas
def reemplazar(a, b):
    global X
    assert a in X, a[:70]; X = X.replace(a, b, 1)
reemplazar('Fusiona F1 y F4, preservando su separación de estimandos.',
           'Fusiona F1 y F4, preservando su separación de estimandos. Versión 2: agrega A2 (sorpresas de alta frecuencia) y A3 (canal de crédito bancario).')
reemplazar('Reúne F2, F6, F9, F11, N2, N3, N6 y N7.', 'Reúne F2, F6, F9, F11, N2, N3, N6 y N7. Versión 2: agrega C5 (regulación bancaria con exposición heterogénea) y C6 (alivio COVID y mora).')
reemplazar('Reúne C1-C6.', 'Reúne C1-C6. Versión 2: agrega D6 (precios administrados de combustibles).')
reemplazar('Reúne F7-F8 y N1, N4-N11.', 'Reúne F7-F8 y N1, N4-N11. Versión 2: agrega F6 (shocks cambiarios argentinos) y F7 (SPI y efectivo).')
i = X.find('F. Digitalización y microtransmisión.'); e = X.find('</w:p>', i) + 6
X = X[:e] + p_prog('G. Política fiscal, mercado laboral y sector externo (nuevo).',
    'Ciclicidad y multiplicadores fiscales, informalidad y holgura laboral, salario mínimo, benchmarking regional con nueve países y remesas. Reúne G1-G5, nuevas en la versión 2; aprovecha el estado de operaciones del MEF, la EPHC y los datos del FMI ya incorporados a la base.') + X[e:]

# Nota de versión después del propósito
i = X.find('Propósito.'); e = X.find('</w:p>', i) + 6
X = X[:e] + p_lead('Versión 2 (septiembre 2026).',
    'Esta versión contrasta la agenda con la base de datos macro-financiera del BCP (esquema 49) y agrega doce fichas nuevas (A2, A3, C5, C6, D6, F6, F7 y el programa G), seleccionadas por usar datos disponibles no aprovechados o por ofrecer una fuente de identificación causal (shocks fechados, cambios regulatorios con exposición heterogénea, sorpresas de alta frecuencia). Cada ficha, nueva o existente, tiene una carpeta de trabajo en proyectos/ con datos, script de extracción y evaluación de viabilidad. Nota: los códigos entre paréntesis en "Reúne ..." (p. ej. G1-G7, N1-N11) remiten a la agenda original de 35 títulos, no a las fichas.') + X[e:]

# Mapa transversal: dos filas nuevas
i = X.find('Vintages y calendario'); s = X.rfind('<w:tr>', 0, i); e = X.find('</w:tr>', i) + 7
fila_tpl = X[s:e]
import re
def fila(celdas):
    partes = re.split(r'(<w:t>[^<]*</w:t>)', fila_tpl)
    k = 0; out = []
    for pz in partes:
        if pz.startswith('<w:t>'):
            out.append(f'<w:t>{esc(celdas[k])}</w:t>'); k += 1
        else: out.append(pz)
    return ''.join(out)
tbl_end = X.find('</w:tbl>', i)
X = X[:tbl_end] + fila(["Calendario institucional", "COPOM (fecha y hora), encaje, tope de tarjetas, alivio crediticio, combustibles, salario mínimo, hitos SPI; evento", "anuncio vs. vigencia, norma, valor anterior y nuevo", "A1 A2 A3 B1 C5 C6 D6 E3 F7 G1 G3", "Mínimo", "fechar por vigencia y no por anuncio"]) \
    + fila(["Fiscal, laboral y regional", "estado de operaciones MEF mensual, EPHC trimestral, FMI 9 países, remesas por origen", "clasificación MEFP, marco muestral EPHC, definiciones FMI", "G1 G2 G3 G4 G5 F6", "Mínimo/suficiente", "series posicionales sin verificar"]) + X[tbl_end:]

# Priorización
reemplazar('Combinan pregunta clara, valor de política y producto útil aun sin causalidad fuerte.',
    'Combinan pregunta clara, valor de política y producto útil aun sin causalidad fuerte. Versión 2: se agregan A2 (sorpresas de alta frecuencia, que vuelve causales a otros proyectos), C5 módulo de encaje, F6 (shocks argentinos) y G1 (política fiscal); E1 y E2 quedan condicionados al archivo de vintages en construcción.')
reemplazar('Son prometedores, pero su título debe ajustarse al nivel de datos alcanzado.',
    'Son prometedores, pero su título debe ajustarse al nivel de datos alcanzado. Versión 2: se agregan A3 (tras A2), C6, D6, G2, G3 y G4.')
reemplazar('y sustitución micro de C2.', 'y sustitución micro de C2. Versión 2: se agregan F7 (SPI y efectivo, descriptivo) y G5 (remesas, como módulo).')

# Evaluación contra la base (tabla) antes de "Decisión de arquitectura"
filas = [
 ("A1 Reservas y liquidez FX", "Media", "Reservas bancarias diarias; calendario del corredor", "01_a1_reservas_liquidez"),
 ("A2 Sorpresas de alta frecuencia (nueva)", "Media-alta", "Calendario del COPOM", "25_n4_sorpresas_monetarias"),
 ("A3 Canal de crédito bancario (nueva)", "Media (media-alta con A2)", "Sorpresas de A2; originaciones", "29_n8_canal_credito_bancario"),
 ("B1 Intervención cambiaria", "Media", "Tipo y hora diarios de operaciones", "02_b1_intervencion_fx"),
 ("B2 Marco multi-horizonte PYG/USD", "Alta", "DXY; forwards", "03_b2_tc_multihorizonte"),
 ("B3 Flujo de órdenes FX", "Baja", "Flujo firmado por agente", "sin carpeta"),
 ("C1 Liquidez USD y descalce", "Media", "Registro de crédito; plazo residual", "05_c1_liquidez_usd_descalce"),
 ("C2 Depósitos y sustitución", "Media-alta / Baja (coop.)", "Tasas por banco; INCOOP", "06_c2_depositos_credito"),
 ("C3 Bonos y deuda pública", "Media", "Subastas del Tesoro", "07_c3_bonos_deuda_publica"),
 ("C4 Repricing y riesgo", "Baja", "Contratos y reset", "sin carpeta"),
 ("C5 Regulación bancaria DiD (nueva)", "Media-alta / Media-baja", "Calendario regulatorio; boletines pre-2016", "27_n6_regulacion_bancaria_did"),
 ("C6 Alivio COVID (nueva)", "Media", "Resoluciones; registro de crédito", "28_n7_alivio_covid"),
 ("D1 ENSO no lineal", "Alta", "Clima físico (robustez)", "09_d1_enso_no_lineal"),
 ("D2 Clima por calendario agrícola", "Baja (media con datos públicos)", "Clima en grilla; producción", "sin carpeta"),
 ("D3 Pronósticos ENSO", "Baja (media con datos públicos)", "Vintages IRI", "sin carpeta"),
 ("D4 Inflación climática", "Media-alta", "Clima; ponderadores IPC", "12_d4_inflacion_climatica"),
 ("D5 Clima y riesgo de crédito", "Media / Baja (causal)", "Geografía de cartera", "13_d5_clima_riesgo_credito"),
 ("D6 Combustibles (nueva)", "Media", "Fechas de ajustes", "31_n10_combustibles_expectativas"),
 ("E1 Combinación del PIB", "Pendiente", "Vintages de cuentas (en construcción)", "sin carpeta"),
 ("E2 Vintages y nowcasting", "Pendiente", "Vintages (en construcción)", "sin carpeta"),
 ("E3 Anclaje de expectativas", "Media", "Dispersión EVE; historia de la meta", "16_e3_expectativas_anclaje"),
 ("F1 Facturación electrónica", "Baja", "SIFEN", "sin carpeta"),
 ("F2 Pass-through e importaciones", "Media / Baja (frontera)", "Aduanas; IPC regional", "18_f2_pass_through_frontera"),
 ("F3 Río y logística", "Baja / Media (energía)", "Niveles del río; fletes", "sin carpeta"),
 ("F4 Pagos instantáneos", "Media (monitoreo)", "SPI entidad-día", "20_f4_pagos_instantaneos"),
 ("F5 Inflación desigual (N9)", "Media / Baja (N10)", "Ponderadores EIGH", "21_f5_inflacion_desigual"),
 ("F6 Shocks argentinos (nueva)", "Media-alta", "Tipo de cambio paralelo; IPC regional", "26_n5_shocks_argentina"),
 ("F7 SPI y efectivo (nueva)", "Media (descriptivo)", "Hitos del SPI", "30_n9_spi_efectivo"),
 ("G1 Política fiscal (nueva)", "Media-alta", "Presupuesto; SPNF", "22_n1_politica_fiscal"),
 ("G2 Mercado laboral (nueva)", "Media", "Microdatos EPHC", "23_n2_mercado_laboral"),
 ("G3 Salario mínimo (nueva)", "Media", "Decretos; exposición sectorial", "32_n11_salario_minimo"),
 ("G4 Panel regional (nueva)", "Media-alta", "EMBI; datos FMI actualizados", "24_n3_panel_regional"),
 ("G5 Remesas (nueva)", "Media-baja", "Remesas por departamento", "33_n12_remesas"),
]
W = 2541
def celda(t, bold=False):
    rpr = '<w:rPr><w:b/><w:sz w:val="15"/></w:rPr>' if bold else '<w:rPr><w:sz w:val="15"/></w:rPr>'
    return (f'<w:tc><w:tcPr><w:tcW w:type="dxa" w:w="{W}"/><w:vAlign w:val="center"/><w:tcMar><w:top w:w="90" w:type="dxa"/>'
            '<w:start w:w="90" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:end w:w="90" w:type="dxa"/></w:tcMar></w:tcPr>'
            f'<w:p><w:r>{rpr}<w:t xml:space="preserve">{esc(t)}</w:t></w:r></w:p></w:tc>')
tbl = ('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:type="dxa" w:w="10164"/><w:jc w:val="center"/>'
       '<w:tblLook w:firstColumn="1" w:firstRow="1" w:lastColumn="0" w:lastRow="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>'
       '<w:tblGrid>' + ('<w:gridCol w:w="%d"/>' % W) * 4 + '</w:tblGrid>'
       '<w:tr>' + ''.join(celda(h, True) for h in ("Ficha", "Viabilidad con datos actuales", "Brecha principal", "Carpeta en proyectos/")) + '</w:tr>'
       + ''.join('<w:tr>' + ''.join(celda(c) for c in f) + '</w:tr>' for f in filas) + '</w:tbl>')
eval_sec = (h1('Evaluación contra la base de datos (septiembre 2026)')
    + p_body('Viabilidad del ejercicio inicial de cada ficha con los datos disponibles en la base del BCP (esquema 49) más índices ENSO (NOAA), variables globales (FRED) y comercio por socio (FMI). Alta: variable central y controles disponibles; media: variable central disponible con limitaciones de frecuencia, cobertura o calidad; baja: falta la variable central. El detalle, las brechas y la priorización de datos faltantes están en proyectos/00_resumen_viabilidad.md.')
    + tbl
    + p_body('Prioridad de datos faltantes (resumen): (1) calendario institucional fechado —COPOM, encaje, tope de tarjetas, alivio, combustibles, salario mínimo—, que beneficia a catorce fichas a costo muy bajo; (2) clima físico y vintages ENSO públicos; (3) tasas y originaciones por banco; (4) operaciones y liquidez diarias del BCP; (5) ponderadores del IPC por grupo de hogares; (6) registro de crédito, de mayor beneficio total pero con costo de acceso alto.'))
insertar_antes('>Decisión de arquitectura<', eval_sec)

open('u/word/document.xml', 'w', encoding='utf-8').write(X)
print('ok', len(X))
