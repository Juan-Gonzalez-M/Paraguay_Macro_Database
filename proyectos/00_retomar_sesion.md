# Cómo retomar el trabajo (estado al 2026-09-25)

Prompt para iniciar un chat nuevo de Claude Code en esta carpeta:

```text
Retomemos el trabajo de adquisición de datos del repo (ver proyectos/00_retomar_sesion.md y la memoria del proyecto).
Seguí AGENTS.md: fidelidad a la fuente, procedencia con SHA-256, nunca descartar en silencio, nada entra a la DuckDB
sin el flujo de candidatos, y no publicar ni hacer push sin preguntarme.

1. ERA5-Land horario: la descarga corre sola en segundo plano (proceso desvinculado con caffeinate). Verificá el avance
   en input/acquisition_candidates/clima_agro_2026-09-23_faseB/era5land_descarga_horaria.log. Si no está corriendo
   (pgrep -fl 06_era5land.R), relanzala UNA sola vez con:
   caffeinate -i nohup Rscript R/clima/06_era5land.R descargar >> input/acquisition_candidates/clima_agro_2026-09-23_faseB/era5land_descarga_horaria.log 2>&1 &
   Cuando estén los 548 meses: Rscript R/clima/06_era5land.R procesar, luego R/clima/07_spei.R y
   R/clima/99_ejecutar_todo.R; verificá rangos del catálogo, corré 97_inventario_proyectos.R y actualizá los documentos
   de proyectos (ERA5 y SPEI pasan a disponibles). Mostrame el resultado antes de commitear.
2. Pendientes de mi revisión (no los resuelvas solo; prepará la evidencia):
   - eventos_bcp_usuario_2026-09-25 (LOCAL, no publicar): verifico a mano fuentes_a_verificar.csv; después decidimos
     qué cargar en las plantillas datos_manuales de los proyectos 25, 27, 28 y 30.
   - Calendario del CPM completo 2010-01 → 2026-07: cargarlo en proyectos/25_n4_sorpresas_monetarias/datos_manuales/
     calendario_copom.csv solo cuando lo pida, y corregir el cálculo de TPM implícita del proyecto 25 (asume corredor simétrico).
   - boletines_sib_2011_2015: solo quedan los códigos propuestos de los hitos distintos de H03.
3. Yo bajo a mano el portal PGN del MEF (datos.hacienda.gov.py); cuando lo suba, inventarialo como los demás.
Primero decime en qué estado encontraste todo.
```

## Estado resumido

| Frente | Estado | Dónde |
|---|---|---|
| Clima/agro (fase B) | Hecho salvo ERA5-Land y SPEI | `R/clima/`, `data/clima/README.md` |
| ERA5-Land horario | 246/548 meses al 2026-09-25 13:00 (unos 4 meses/hora); proceso desvinculado, retoma solo. Earth Data Hub descartado (pérdida de precisión) | `R/clima/06_era5land.R`, registro de pedidos `…_faseB/era5land/horario/cds_jobs_horario.csv` |
| Calendario del CPM 2010-01 → 2026-07 | Completo (196 decisiones); decisiones del usuario en `extraidos/decisiones_revision_cpm.csv` | `input/acquisition_candidates/web_brechas_2026-09-23/` (README § 4) |
| Boletines SIB 2011–2015 | 60/60 meses; vínculos y alias aprobados (`decisiones_revision.csv`) | `input/acquisition_candidates/boletines_sib_2011_2015/README.md` |
| Calendario institucional del BCP | Compilación del usuario verificada + 11 eventos; **local, no publicar**; 14 fuentes por verificar a mano | `input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/README.md` |
| Priorización de brechas | Actualizada al 2026-09-25 | `proyectos/00_resumen_viabilidad.md` § 3.5 |

**Recordatorios:**
- El token del CDS está solo en `~/.cdsapirc`; conviene rotarlo.
- Los crudos de `boletines_sib_2011_2015/raw/` (247 MB) son locales y conviene respaldarlos: dos meses ya no se pueden bajar del sitio del BCP.
- El repo es público: no se versionan los datos de EM-DAT ni ningún secreto.
