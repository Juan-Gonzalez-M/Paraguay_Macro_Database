# C1 Panel bancario por moneda y actividad

## Pregunta admisible en esta etapa

¿Cómo varían la composición monetaria del balance y la calidad de cartera entre bancos, sectores y actividades? El paquete permite descripción y forma reducida a nivel banco–mes. No identifica el descalce cambiario ni el default de prestatarios individuales.

## Unidad y cobertura

- Unidad principal: banco × mes × moneda de origen × sector.
- Extensión: banco × mes × moneda de origen × actividad detallada.
- Moneda: `6200` identifica operaciones originadas en moneda extranjera y reportadas en PYG; `6900`, operaciones originadas y reportadas en PYG.
- Cobertura esperada del boletín actual: enero de 2016 a julio de 2026.

## Variables fuente

- EEFF completos desde `research.entity_panel`.
- Cartera vigente, vencida, renovada, refinanciada y reestructurada desde `main.v_banks_carteras_documented`.
- Cartera vigente y vencida por sector desde `main.v_banks_credito_sector_documented`.
- El mismo desglose por actividad desde `main.v_banks_credito_actividad_documented`.
- Capital, patrimonio, morosidad y otros ratios publicados desde `main.v_banks_ratios_documented`.

## Transformaciones permitidas

La primera muestra sólo calcula `credito_total = cartera_vigente + cartera_vencida` y `ratio_vencida = cartera_vencida / credito_total`. No convierte los saldos `6200` a USD y no suma monedas antes de conservar el código de origen.

## Compuertas pendientes

- Identificar y validar los rubros exactos de fondeo externo antes de declarar alcanzado el nivel suficiente.
- Revisar entradas, salidas y fusiones de entidades antes de construir un panel balanceado.
- Definir el shock externo y congelar la exposición antes de cualquier ejercicio dinámico.
- No afirmar riesgo del prestatario, cobertura natural, madurez residual ni oferta causal de crédito.

