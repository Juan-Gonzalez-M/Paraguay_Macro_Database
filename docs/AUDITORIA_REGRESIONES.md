> Historical record of one release. The current acceptance rule, run-status vocabulary and data model are in `README.md`, `docs/OPERATIONS.md` and `docs/DATA_MODEL.md`; where this file disagrees with them it is describing an earlier state. Since schema 23 a failing run reports `release_blocked`, not `completed_with_errors`, and since schema 24 a release carries its own lifecycle in `audit.releases`.

# Regression audit register — moved

This file used to duplicate the external audit's regression register with its
own numbering. As of the post-v11 "apply low/medium-risk improvements" pass,
that created two documents assigning different content to the same IDs from
R26 onward — a real risk of someone citing "R27" or "R31" and getting two
different answers depending on which file they opened.

**The canonical, actively maintained regression register is
`/AUDITORIA_REGRESIONES.md`** (project root), not this file. It already
incorporates the useful, correct explanation this file contributed — in
particular, the mechanism behind the bank EEFF row count (worksheet rows
including header vs. curated data rows excluding it), credited there under R30.

If you're looking for the status of a specific regression ID, use the root
file. This file is kept only so old references to `docs/AUDITORIA_REGRESIONES.md`
don't silently 404.
