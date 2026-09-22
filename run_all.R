#!/usr/bin/env Rscript
# run_all.R -- end-to-end pipeline.
#
#   Rscript run_all.R            # all 32 entities
#   Rscript run_all.R 20         # one entity
#   Rscript run_all.R 20 09 15   # a subset
#
# Idempotent: cached downloads and finished interim blocks are reused, so a
# re-run after a failure resumes rather than restarting.

for (f in sort(list.files("R", full.names = TRUE, pattern = "\\.R$"))) source(f)

args <- commandArgs(trailingOnly = TRUE)
ents <- if (length(args) == 0) ENTITIES else sprintf("%02d", as.integer(args))

unknown <- setdiff(ents, ENTITIES)
if (length(unknown) > 0) stop("unknown entity code(s): ", paste(unknown, collapse = ", "))

# Each block records its own interim file; if it exists, the block is skipped.
run_block <- function(label, out_file, fn, ent) {
  if (file.exists(out_file)) {
    log_msg("skip ", label, " ", ent, " (already built)")
    return(TRUE)
  }
  fn(ent)
  TRUE
}

process_entity <- function(ent) {
  download_entity(ent)
  run_block("boundaries",   interim_path("ageb_attrs", ent),            run_boundaries,     ent)
  run_block("census_urban", interim_path("census_urban", ent),          build_census_urban, ent)
  run_block("census_rural", interim_path("census_rural", ent),          build_census_rural, ent)
  run_block("coneval",      interim_path("coneval", ent),               build_coneval,      ent)
  run_block("denue",        interim_path("denue", ent),                 build_denue,        ent)
  run_block("hydrology",    interim_path("hydrology", ent),             build_hydrology,    ent)
  run_block("landuse",      interim_path("landuse", ent),               build_landuse,      ent)
  run_block("health",       interim_path("health", ent),                build_health,       ent)
  run_block("terrain",      interim_path("terrain", ent),               build_terrain,      ent)
  run_block("hazard",       interim_path("hazard", ent),                build_hazard,       ent)
  run_block("income",       interim_path("income", ent),                build_income,       ent)
  build_complete(ent)
  build_qc(ent)
  export_entity(ent)
  invisible(TRUE)
}

log_step("pipeline start -- ", length(ents), " entit",
         if (length(ents) == 1) "y" else "ies")
started <- Sys.time()

download_national()

results <- tibble(CVE_ENT = ents, STATUS = NA_character_, MESSAGE = NA_character_)
for (i in seq_along(ents)) {
  ent <- ents[i]
  outcome <- tryCatch({
    process_entity(ent)
    list("OK", "")
  }, error = function(e) {
    log_msg("!! entity ", ent, " failed: ", conditionMessage(e))
    list("FAILED", conditionMessage(e))
  })
  results$STATUS[i]  <- outcome[[1]]
  results$MESSAGE[i] <- outcome[[2]]
}

ok <- results$CVE_ENT[results$STATUS == "OK"]
if (length(ok) > 1) export_national(ok)

# One GeoPackage with every table, rebuilt from all entities on disk (not just
# this run's), so a partial run refreshes its entities inside the national file.
if (length(ok) > 0) {
  tryCatch(build_integrated(), error = function(e) {
    log_msg("!! integrated database failed: ", conditionMessage(e))
  })
}

write_csv(results, file.path(DIR_LOGS, sprintf(
  "run_%s.csv", format(started, "%Y%m%d_%H%M%S"))), na = "")

# Consolidated QC across everything that succeeded.
qc_paths <- file.path(DIR_PROCESSED, sprintf("quality_control_report_%s.csv", ok))
qc_paths <- qc_paths[file.exists(qc_paths)]
if (length(qc_paths) > 0) {
  qc_all <- map_dfr(qc_paths, read_csv, col_types = cols(.default = col_character()))
  write_csv(qc_all, file.path(DIR_PROCESSED, "quality_control_report_MX.csv"), na = "")
  n_fail <- sum(qc_all$STATUS == "FAIL")
  log_step("QC: ", nrow(qc_all) - n_fail, " passed, ", n_fail, " failed")
  if (n_fail > 0) {
    print(as.data.frame(qc_all |> filter(STATUS == "FAIL") |>
                          select(CVE_ENT, CHECK, DETAIL)))
  }
}

log_step("done in ", round(difftime(Sys.time(), started, units = "mins"), 1),
         " min | OK: ", length(ok), " | failed: ", sum(results$STATUS == "FAILED"))
if (any(results$STATUS == "FAILED")) {
  log_msg("failed entities: ",
          paste(results$CVE_ENT[results$STATUS == "FAILED"], collapse = ", "))
}
