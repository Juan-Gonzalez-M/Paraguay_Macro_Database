# Índice de revisiones

Cada archivo de esta carpeta es el **registro de una revisión concreta**: qué se encontró, qué se
cambió y qué se descartó, medido contra la base de datos tal como estaba ese día. Son evidencia, no
documentación operativa, y no se actualizan cuando el proyecto avanza.

**La guía vigente está en `README.md`, `docs/OPERATIONS.md` y `docs/DATA_MODEL.md`.** Si una nota de
esta carpeta contradice a alguno de ellos, gana el documento operativo y la nota está describiendo un
estado anterior. En particular, las notas anteriores a la revisión 4 hablan de `completed_with_errors`
como estado de ejecución; el vocabulario vigente desde el esquema 23 es `release_blocked`, y desde el
esquema 24 una release además tiene un ciclo de vida propio en `audit.releases`.

| Archivo | Registra | Estado |
|---|---|---|
| `REVISION_AUDITORIA_6_P0_P1_P2.md` | Sexta auditoría técnica, P0/P1/P2 — esquemas 30, 31 y 32 | **Vigente** |
| `REVISION_AUDITORIA_5_P0_P1_P2.md` | Quinta auditoría técnica, P0/P1/P2 — esquemas 27, 28 y 29 | Histórico |
| `REVISION_AUDITORIA_4_P0_P1_P2.md` | Cuarta auditoría técnica, P0/P1/P2 — esquemas 24, 25 y 26 | Histórico |
| `REVISION_AUDITORIA_3_P0_P1_P2.md` | Tercera auditoría, P0/P1/P2 — esquemas 22 y 23 | Histórico |
| `REVISION_AUDITORIA_2_P0_P1_P2.md` | Segunda auditoría, P0/P1/P2 | Histórico |
| `REVISION_AUDITORIA_P0_P1_P2.md` | Primera auditoría, P0/P1/P2 | Histórico |
| `REVISION_AUDITORIA_EXTERNA.md` | Revisión externa de diseño | Histórico |
| `REVISION_v8_errores_ingesta.md` … `REVISION_v11.md` | Reparaciones por versión, v8 a v11 | Histórico |
| `MEJORAS_v11.md` | Mejoras de riesgo bajo y medio posteriores a v11 | Histórico |
| `RECOVERED_CELLS_SAMPLE_CHECK.md` | Verificación muestral de celdas recuperadas | Histórico |
| `CANONICAL_CORE_PROPOSAL.md` | Propuesta de núcleo canónico, regenerada en cada ejecución | **Generado** |
| `INVENTARIO_SERIES.md`, `series_inventory.csv`, `series_observations/` | Inventario de series y exportación larga | **Generado** |

El historial acumulado por versión está en `CHANGELOG.md`; la tabla de migraciones de esquema, con
las fuentes que cada una vuelve a leer, se genera en `docs/SCHEMA_MIGRATIONS.md` a partir de la propia
base de datos.
