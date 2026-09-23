# B2 Archivo inicial para el marco PYG USD

## Pregunta admisible en esta etapa

¿Qué variables se asocian con el nivel y los cambios del PYG/USD a horizontes diarios y mensuales, y qué contenido predictivo tienen frente a referencias simples? El paquete sólo prepara datos; no elige modelos ni interpreta coeficientes como causales.

## Separación por frecuencia

- Diario: cotización referencial y operaciones FX del BCP.
- Mensual: PYG/USD promedio, inflación, IMAEP, tasas, forwards y expectativas.
- Variables externas: deben incorporarse sólo después de seleccionar explícitamente país, indicador, transformación y fecha de disponibilidad. No se elige automáticamente una serie IMF por similitud de nombre.

## Convenciones

- Las series mensuales se alinean por el primer día del mes derivado de la frecuencia, no por la fecha impresa.
- Compra y venta permanecen separadas.
- Nivel, retorno y variación interanual son objetos diferentes.
- La intervención se conserva por dirección y sector; no se interpreta automáticamente como shock exógeno.

## Compuertas pendientes

- Seleccionar y documentar dólar amplio, Brasil, Argentina, commodities, comercio y tasas externas.
- Verificar el estadístico de EVE y la fecha efectiva de disponibilidad.
- Resolver el horario y concepto de cierre para la cotización diaria.
- Definir una regla económica explícita antes de convertir datos diarios a frecuencia mensual.

