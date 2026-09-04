# The seventh audit's F-09. Two halves, and the second is the one that bites:
#
#   - run_update.R did not enforce the environment it records;
#   - build identity hashed the *file* renv.lock, never a running version, so two
#     builds against different libraries produced the same build_id.
#
# The second makes the first unrecoverable after the fact. A build whose id
# cannot distinguish the library it ran against cannot be reproduced from its own
# record, however carefully the record was written.

testthat::test_that("build identity records the library that ran, not only the one declared", {
  build <- build_identity_record(project_test_root, "release:test", 35L)
  testthat::expect_true("package_versions_digest" %in% names(build))
  testthat::expect_false(is.na(build$package_versions_digest))

  packages <- attr(build, "package_versions")
  # The whole lockfile, not the nineteen names the installer lists. Schema 35
  # recorded only the declared set on the argument that a transitive difference
  # is not actionable from a failure message -- a good argument for not failing
  # and none at all for not looking. The re-audit's RA2-09.
  declared <- sort(read_required_packages(project_test_root))
  testthat::expect_true(all(declared %in% packages$package))
  testthat::expect_gt(nrow(packages), length(declared))
  testthat::expect_setequal(packages$package[packages$is_direct], declared)
  testthat::expect_false(any(is.na(packages$version)))
  # Whatever else is true, the running duckdb has to be in there: it decides the
  # storage format of the file being produced.
  testthat::expect_true("duckdb" %in% packages$package)

  # And the field that exposes the thing version strings cannot: a package built
  # under a different R than the one running. Every package in this library is,
  # including DBI and duckdb, which write the database.
  testthat::expect_true("built_under" %in% names(packages))
  testthat::expect_false(all(is.na(packages$built_under)))

  # The machine, which nothing recorded at all before: an arm64 macOS build and
  # an x86 Linux build produced identical identities.
  testthat::expect_false(is.na(build$platform))
  testthat::expect_equal(build$platform, R.version$platform)
})

testthat::test_that("a different library is a different build", {
  # The defect stated as a test. Before schema 35 the only environment input to
  # build_id was a hash of renv.lock, so this assertion could not have been made
  # at all -- there was nothing to vary.
  build <- build_identity_record(project_test_root, "release:test", 35L)
  digest_of <- function(packages) substr(digest::digest(
    paste(paste0(packages$package, ":", packages$version, ":", packages$built_under),
          collapse = "|"),
    algo = "sha256", serialize = FALSE
  ), 1, 24)
  observed <- attr(build, "package_versions")
  testthat::expect_equal(build$package_versions_digest, digest_of(observed))

  moved <- observed
  moved$version[moved$package == "duckdb"] <- "0.0.0-not-installed"
  testthat::expect_false(identical(digest_of(moved), build$package_versions_digest))

  # A package rebuilt under a different R is also a different build, and this is
  # the difference schema 35 could not see: the version string is unchanged.
  rebuilt <- observed
  rebuilt$built_under[rebuilt$package == "duckdb"] <- "R 0.0.0"
  testthat::expect_equal(rebuilt$version, observed$version)
  testthat::expect_false(identical(digest_of(rebuilt), build$package_versions_digest))
})

testthat::test_that("the loaded namespace graph is recorded but not hashed into the identity", {
  # A deliberate departure from the re-audit's wording, and the reason is the
  # property the whole release model rests on: loadedNamespaces() differs between
  # run_update.R and run_tests.R, so folding it into build_id would make the same
  # sources on the same machine produce two identities depending on which entry
  # point ran. It is recorded beside the identity instead of inside it.
  build <- build_identity_record(project_test_root, "release:test", 35L)
  testthat::expect_false(is.na(build$loaded_namespaces_digest))
  source_text <- paste(readLines(
    file.path(project_test_root, "scripts", "01_utils.R"), warn = FALSE
  ), collapse = "\n")
  identity_call <- regmatches(source_text, regexpr(
    "build_id <- paste0\\(\"build:\".*?\\), 1, 24\\)\\)", source_text
  ))
  testthat::expect_length(identity_call, 1L)
  testthat::expect_false(grepl("loaded_namespaces_digest", identity_call, fixed = TRUE))
  testthat::expect_true(grepl("package_versions_digest", identity_call, fixed = TRUE))
})

testthat::test_that("the recorded versions and the digest describe one library", {
  path <- withr::local_tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)

  build <- build_identity_record(project_test_root, "release:test", 35L)
  DBI::dbWriteTable(con, "build_identity", build, append = TRUE)
  testthat::expect_gt(record_build_environment(con, build), 0L)
  # Idempotent: re-recording the same build must not double the rows or abort on
  # the primary key.
  record_build_environment(con, build)

  stored <- DBI::dbGetQuery(con, paste(
    "SELECT package, version, built_under, is_direct FROM audit.build_environment",
    "WHERE build_id =", sql_string(build$build_id), "ORDER BY package"
  ))
  testthat::expect_equal(nrow(stored), nrow(attr(build, "package_versions")))
  testthat::expect_equal(
    substr(digest::digest(
      paste(paste0(stored$package, ":", stored$version, ":", stored$built_under), collapse = "|"),
      algo = "sha256", serialize = FALSE
    ), 1, 24),
    build$package_versions_digest
  )
  # The stored list distinguishes what the gate can fail on from what it only
  # reports, so an operator reading the table knows which drift is actionable.
  testthat::expect_setequal(
    stored$package[stored$is_direct], sort(read_required_packages(project_test_root))
  )
  testthat::expect_true(any(!stored$is_direct))

  # The ordering behind the digest is byte order, not the operator's locale.
  # `sort()` puts "DBI" before "bit" under C and after it under en_US, and that
  # ordering feeds build_id -- so a locale would otherwise have changed the
  # identity of a build. Radix matches DuckDB's ORDER BY, which is why the
  # digest recomputed from the stored rows above agrees at all.
  testthat::expect_equal(
    stored$package, sort(stored$package, method = "radix")
  )
})

testthat::test_that("the update entry point enforces the environment before it builds", {
  # A static check, like the isolation one: whether the entry point calls the
  # gate is a property of the source, and nothing in the database can observe it.
  source_text <- paste(readLines(
    file.path(project_test_root, "run_update.R"), warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(source_text, "check_environment(root, strict = TRUE)", fixed = TRUE)
  # And the override exists, is explicit, and records itself rather than passing
  # silently -- a gate with a silent bypass is not a gate.
  testthat::expect_match(source_text, "PARAGUAY_MACRO_ALLOW_ENV_DRIFT", fixed = TRUE)
  testthat::expect_match(source_text, "environment_drift_overridden", fixed = TRUE)
})

testthat::test_that("check_environment can fail rather than warn", {
  # strict = TRUE has existed since the first audit and nothing called it. This
  # asserts the branch works, using a lockfile that cannot match anything.
  root <- withr::local_tempdir()
  dir.create(file.path(root, "scripts"))
  file.copy(
    file.path(project_test_root, "scripts", "00_install_packages.R"),
    file.path(root, "scripts", "00_install_packages.R")
  )
  jsonlite::write_json(
    list(R = list(Version = "1.0.0"), Packages = list(
      duckdb = list(Package = "duckdb", Version = "0.0.0")
    )),
    file.path(root, "renv.lock"), auto_unbox = TRUE
  )
  testthat::expect_error(check_environment(root, strict = TRUE), "differs from renv.lock")
  testthat::expect_warning(check_environment(root, strict = FALSE), "differs from renv.lock")
})
