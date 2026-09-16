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

  # Rural AGEB with no ITER locality are real uninhabited territory, not
  # missing data; 10_build.R sets them to zero from the join, not from an NA.
  # Every other rural AGEB must therefore carry a headcount.
  rur_all <- df |> filter(AMBITO == "Rural")
  res[[length(res) + 1]] <- qc_check(
    "uninhabited_rural_ageb_zeroed",
    all(rur_all$POB_TOTAL[rur_all$UNINHABITED] == 0) && !anyNA(rur_all$POB_TOTAL),
    sprintf("%d rural AGEB have no ITER locality and are recorded as population 0; %d rural AGEB with NA population",
            sum(rur_all$UNINHABITED), sum(is.na(rur_all$POB_TOTAL))))

  # Suppression only hides hamlets of 1-2 dwellings, so most rural people live
  # in localities that publish their characteristics: 88.7% (Baja California
  # Sur, dispersed ranches) to 99.8% (Tabasco), each verified against a direct
  # ITER count. When 05_census_rural.R summed without regard to suppression,
  # this share fell to about 5%, so an 80% floor catches that regression
  # without flagging the sparsely settled north.
  rur_pop <- sum(rur_all$POB_TOTAL, na.rm = TRUE)
  rur_rep <- sum(rur_all$POB_REPORTADA, na.rm = TRUE)
  inhabited <- rur_all |> filter(POB_TOTAL > 0)
  res[[length(res) + 1]] <- qc_check(
    "rural_population_with_characteristics",
    rur_pop == 0 || rur_rep / rur_pop >= 0.80,
    sprintf("%.2f%% of rural population in reporting localities; %d of %d inhabited rural AGEB have no reporting locality",
            if (rur_pop == 0) 100 else 100 * rur_rep / rur_pop,
            sum(inhabited$POB_REPORTADA == 0), nrow(inhabited)))

  pr <- df |> filter(!is.na(POB_REPORTADA), !is.na(POB_TOTAL))
  res[[length(res) + 1]] <- qc_check(
    "pob_reportada_le_total", all(pr$POB_REPORTADA <= pr$POB_TOTAL),
    sprintf("%d of %d rows exceed POB_TOTAL",
            sum(pr$POB_REPORTADA > pr$POB_TOTAL), nrow(pr)))

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
  # The sex split covers the localities that report it, so it must add up to
  # their population, not to POB_TOTAL (identical for urban AGEB). An urban
  # sex count of 1-2 is imputed as 1.5 (04_census_urban.R), so a tiny AGEB may
  # be off by up to one person without being wrong.
  ps <- df |> filter(!is.na(POB_DEN_SEXO), !is.na(POB_HOMBRES),
                     !is.na(POB_MUJERES), POB_DEN_SEXO > 0) |>
    mutate(ABS = abs(POB_HOMBRES + POB_MUJERES - POB_DEN_SEXO),
           OFF = ABS > 1 & ABS / POB_DEN_SEXO * 100 > POP_SUM_TOL_PCT)
  res[[length(res) + 1]] <- qc_check(
    "pob_sex_sum_matches_total", !any(ps$OFF),
    sprintf("%d of %d rows off POB_DEN_SEXO by more than %.1f%% and 1 person",
            sum(ps$OFF), nrow(ps), POP_SUM_TOL_PCT))

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

  # Every census share. Composite and differenced shares are bounded in
  # 10_build.R; anything else above 100 means a numerator and universe drifted
  # into different sets of localities or dwellings.
  share_cols <- CENSUS_SHARE_COLS[CENSUS_SHARE_COLS %in% names(df)]
  over <- vapply(share_cols, \(v) sum(df[[v]] < 0 | df[[v]] > 100 + VIV_TOL_PCT,
                                      na.rm = TRUE), numeric(1))
  res[[length(res) + 1]] <- qc_check(
    "census_shares_in_0_100", all(over == 0),
    if (all(over == 0)) sprintf("%d census shares within [0, 100]", length(share_cols))
    else paste("out of range:", paste(sprintf("%s (%d)", names(over)[over > 0],
                                              over[over > 0]), collapse = ", ")))

  res[[length(res) + 1]] <- qc_check(
    "imputed_cells_urban_only",
    all(df$N_CELDAS_IMPUTADAS[df$AMBITO == "Rural"] == 0, na.rm = TRUE),
    sprintf("%s urban cells imputed as %s in %d of %d urban AGEB",
            format(sum(urb$N_CELDAS_IMPUTADAS, na.rm = TRUE), big.mark = ","),
            URBAN_SUPPRESSED_VALUE, sum(urb$N_CELDAS_IMPUTADAS > 0, na.rm = TRUE),
            nrow(urb)))

  # External validation: CONEVAL computed its urban rezago indicators from the
  # same census, so each census-derived share must land close to its RZ_*
  # counterpart. Measured as the population-weighted mean absolute gap, against
  # a per-indicator ceiling (CONEVAL_MAX_WMAE, 10_build.R). Not correlation:
  # where an indicator barely varies (mobile phones in CDMX) a few noisy tiny
  # AGEB swing r without anything being wrong. Not a share of AGEB within a
  # fixed band either: at 5 points it missed a wrong universe and a wrong
  # literacy denominator, since most urban deprivation rates sit near 1-2%.
  # Weighted by population because shares in AGEB with a handful of people
  # are noise on both sides. Overcrowding is left out: RZ_HACIN is a share of
  # dwellings, PRO_OCUP_C an average.
  wmae <- vapply(names(CONEVAL_MAX_WMAE), \(k) {
    ours <- urb[[CONEVAL_EQUIVALENTS[[k]]]]
    if (k %in% CONEVAL_INVERTED) ours <- 100 - ours
    ok <- !is.na(urb[[k]]) & !is.na(ours)
    if (sum(ok) < 30) NA_real_
    else weighted.mean(abs(ours[ok] - urb[[k]][ok]), urb$POB_TOTAL[ok])
  }, numeric(1))
  ratio <- wmae / CONEVAL_MAX_WMAE
  over <- which(!is.na(ratio) & ratio > 1)
  res[[length(res) + 1]] <- qc_check(
    "census_shares_agree_with_coneval_rz", length(over) == 0,
    if (all(is.na(ratio))) "too few urban AGEB with GRS to compare"
    else paste0(
      sprintf("closest to its ceiling: %s, weighted gap %.3f of %.2f pts (%d indicators)",
              names(ratio)[which.max(ratio)], wmae[which.max(ratio)],
              CONEVAL_MAX_WMAE[which.max(ratio)], sum(!is.na(ratio))),
      if (length(over) > 0) paste0("; over ceiling: ", paste(sprintf("%s %.3f",
        names(wmae)[over], wmae[over]), collapse = ", ")) else ""))

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
