# Paquetes de preparación empírica

Esta carpeta convierte las fichas del portafolio en muestras reproducibles sin modificar la base publicada. Cada paquete contiene un contrato económico, un manifiesto de variables y un script de extracción de solo lectura.

Principios:

- la base es la fuente analítica principal;
- los Excel son evidencia para interpretar y auditar, no entradas manuales recurrentes;
- `period_start` es la clave temporal normalizada;
- una variable provisional puede usarse si el contrato registra su definición y limitaciones;
- los archivos producidos son muestras del proyecto, no nuevas fuentes canónicas;
- ninguna extracción implica identificación causal ni selección de modelo.

Pilotos actuales:

- `c1_bank_fx_exposure`: panel banco–mes–moneda–sector/actividad y calidad de cartera;
- `b2_fx_multihorizon`: archivo doméstico inicial por frecuencia para el marco PYG/USD.

Los scripts reciben un directorio de salida explícito. Para una prueba aislada:

```sh
Rscript --vanilla research_projects/c1_bank_fx_exposure/build_sample.R /private/tmp/c1-sample
Rscript --vanilla research_projects/b2_fx_multihorizon/build_sample.R /private/tmp/b2-sample
```

