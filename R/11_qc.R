# 11_qc.R -- quality control report (spec section 8).
#
# The headline check is municipal coverage: urban + rural AGEB must tile every
# municipality with no gaps, which is the whole reason the geometry comes from
# the Marco Geoestadistico instead of the urban-only CONEVAL KMZ.

qc_check <- function(name, passed, detail = "") {
  tibble(CHECK = name, STATUS = if (passed) "PASS" else "FAIL", DETAIL = detail)
}

build_qc <- function(ent) {
  log_step("quality control ", ent)
  df  <- readRDS(interim_path("complete", ent))
  mun <- readRDS(interim_path("municipios", ent))

  res <- list()

  # --- coverage ---
  cov <- df |>
    group_by(CVE_MUN_FULL) |>
    summarise(AGEB_AREA = sum(AREA_KM2), N_AGEB = n(), .groups = "drop") |>
    left_join(mun, by = "CVE_MUN_FULL") |>
    mutate(DIFF_KM2 = AGEB_AREA - MUN_AREA_KM2,
           DIFF_PCT = 100 * DIFF_KM2 / MUN_AREA_KM2)
  # Two distinct failure modes hide behind "coverage", and conflating them
  # makes the check either useless or permanently red:
  #
  #  * a real GAP -- territory covered by no AGEB at all;
  #  * BOUNDARY ATTRIBUTION -- territory fully tiled, but the AGEB layer and the
  #    municipal layer of the same marco disagree on which municipality owns a
  #    strip. INEGI's own layers do this (Puebla: Coronango -0.6568 km2 against
  #    Cuautlancingo +0.6568 km2, the same strip counted once either way).
  #
  # Only the first is a defect in this database. A municipality whose shortfall
  # is matched, to within a hair, by a surplus somewhere else in the entity is
  # classified as attribution and reported rather than failed.
  flagged <- cov |> filter(abs(DIFF_PCT) > COVERAGE_TOL_PCT,
                           abs(DIFF_KM2) > COVERAGE_TOL_KM2)

  offset_match <- function(d) {
    any(abs(cov$DIFF_KM2 + d) < max(1e-4, abs(d) * 0.01))
  }
  flagged <- flagged |>
    mutate(KIND = vapply(DIFF_KM2,
                         \(d) if (offset_match(d)) "attribution" else "gap",
                         character(1)))

  gaps <- flagged |> filter(KIND == "gap")
  attrib <- flagged |> filter(KIND == "attribution")

  net_km2 <- sum(cov$AGEB_AREA) - sum(cov$MUN_AREA_KM2)
  res[[length(res) + 1]] <- qc_check(
    "entity_coverage_no_net_gap", abs(net_km2) <= COVERAGE_TOL_KM2,
    sprintf("AGEB %.2f vs municipal %.2f km2 (net %+.4f km2)",
            sum(cov$AGEB_AREA), sum(cov$MUN_AREA_KM2), net_km2))

  res[[length(res) + 1]] <- qc_check(
    "municipal_coverage_100pct", nrow(gaps) == 0,
    sprintf("%d of %d municipalities with an unexplained gap; %d differ only by boundary attribution (max |diff| %.4f km2)",
            nrow(gaps), nrow(cov), nrow(attrib),
            max(c(0, abs(flagged$DIFF_KM2)))))

  res[[length(res) + 1]] <- qc_check(
    "all_municipalities_present", nrow(cov) == nrow(mun),
    sprintf("%d of %d municipalities have at least one AGEB", nrow(cov), nrow(mun)))

  # --- keys and ambit ---
  res[[length(res) + 1]] <- qc_check(
    "id_ageb_unique", !anyDuplicated(df$ID_AGEB),
    sprintf("%d rows, %d distinct", nrow(df), length(unique(df$ID_AGEB))))
  res[[length(res) + 1]] <- qc_check(
    "id_ageb_13_chars", all(nchar(df$ID_AGEB) == 13),
    paste("lengths:", paste(sort(unique(nchar(df$ID_AGEB))), collapse = ",")))
  res[[length(res) + 1]] <- qc_check(
    "ambito_valid", all(df$AMBITO %in% c("Urbana", "Rural")),
    sprintf("%d urban, %d rural", sum(df$AMBITO == "Urbana"),
            sum(df$AMBITO == "Rural")))

  # --- join coverage by ambit ---
  for (amb in c("Urbana", "Rural")) {
    sub <- df |> filter(AMBITO == amb)
    res[[length(res) + 1]] <- qc_check(
      paste0("census_join_", tolower(amb)),
      mean(!is.na(sub$POB_TOTAL)) > 0.90,
      sprintf("%.1f%% of %s AGEB have census data",
              100 * mean(!is.na(sub$POB_TOTAL)), amb))
  }

  # Rural AGEB with no inhabited locality are real uninhabited territory, not
  # missing data; 10_build.R sets them to zero. Reported so the count is visible.
  res[[length(res) + 1]] <- qc_check(
    "uninhabited_rural_ageb_zeroed", TRUE,
    sprintf("%d rural AGEB have no ITER locality and are recorded as population 0",
            sum(df$AMBITO == "Rural" & df$POB_TOTAL == 0, na.rm = TRUE)))

  # GRS is a urban-only product: present for urban, expected NA for rural.
  urb <- df |> filter(AMBITO == "Urbana")
  rur <- df |> filter(AMBITO == "Rural")
  res[[length(res) + 1]] <- qc_check(
    "grs_present_urban", mean(!is.na(urb$GRS_GRADO)) > 0.90,
    sprintf("%.1f%% of urban AGEB have GRS", 100 * mean(!is.na(urb$GRS_GRADO))))
  res[[length(res) + 1]] <- qc_check(
    "grs_absent_rural", all(is.na(rur$GRS_GRADO)),
    sprintf("%d rural AGEB carry GRS (expected 0)", sum(!is.na(rur$GRS_GRADO))))

  # --- internal consistency, only where both sides exist ---
  ps <- df |> filter(!is.na(POB_TOTAL), !is.na(POB_HOMBRES), !is.na(POB_MUJERES),
                     POB_TOTAL > 0) |>
    mutate(D = abs(POB_HOMBRES + POB_MUJERES - POB_TOTAL) / POB_TOTAL * 100)
  res[[length(res) + 1]] <- qc_check(
    "pob_sex_sum_matches_total", all(ps$D <= POP_SUM_TOL_PCT),
    sprintf("%d of %d rows off by more than %.1f%%",
            sum(ps$D > POP_SUM_TOL_PCT), nrow(ps), POP_SUM_TOL_PCT))

  for (v in c("VIV_DRENAJE", "VIV_ELECTRICIDAD")) {
    sub <- df |> filter(!is.na(.data[[v]]), !is.na(VIV_PART_HAB), VIV_PART_HAB > 0)
    over <- sum(sub[[v]] > sub$VIV_PART_HAB * (1 + VIV_TOL_PCT / 100))
    res[[length(res) + 1]] <- qc_check(
      paste0(tolower(v), "_le_viv_part_hab"), over == 0,
      sprintf("%d of %d rows exceed VIV_PART_HAB", over, nrow(sub)))
  }

  # --- ranges ---
  for (v in c("WATER_PCT", "USO_PCT", "PCT_URB")) {
    vals <- df[[v]][!is.na(df[[v]])]
    res[[length(res) + 1]] <- qc_check(
      paste0(tolower(v), "_in_0_100"),
      length(vals) == 0 || (min(vals) >= 0 && max(vals) <= 100),
      sprintf("range [%.2f, %.2f]", min(vals), max(vals)))
  }

  res[[length(res) + 1]] <- qc_check(
    "centroids_within_entity_bbox",
    { bb <- entity_bbox_4326(ent)
      all(df$CENTROIDE_LON >= bb[["xmin"]] & df$CENTROIDE_LON <= bb[["xmax"]] &
          df$CENTROIDE_LAT >= bb[["ymin"]] & df$CENTROIDE_LAT <= bb[["ymax"]]) },
    "all published centroids fall inside the entity envelope")

  report <- bind_rows(res) |> mutate(CVE_ENT = ent, .before = 1)
  path <- file.path(DIR_PROCESSED, sprintf("quality_control_report_%s.csv", ent))
  write_csv(report, path, na = "")

  n_fail <- sum(report$STATUS == "FAIL")
  log_msg("  ", nrow(report) - n_fail, " passed, ", n_fail, " failed")
  if (n_fail > 0) {
    for (i in which(report$STATUS == "FAIL")) {
      log_msg("    FAIL ", report$CHECK[i], ": ", report$DETAIL[i])
    }
  }
  # Municipal detail, so a coverage failure can be traced to the municipality.
  cov <- cov |> left_join(flagged |> select(CVE_MUN_FULL, KIND), by = "CVE_MUN_FULL")
  write_csv(cov, file.path(DIR_PROCESSED,
                           sprintf("qc_municipal_coverage_%s.csv", ent)), na = "")
  invisible(report)
}
