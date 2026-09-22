# 13b_income.R -- municipal household income from INEGI's Ingreso Corriente
# para los Municipios de Mexico (ICMM), https://www.inegi.org.mx/investigacion/icmm/.
#
# The census asks no income question, so nothing in this database measures it
# at AGEB level. The ICMM is the closest official figure: the ENIGH's mean
# quarterly current income per household (ingreso corriente promedio trimestral
# por hogar), estimated for every municipality with small-area techniques that
# borrow strength from the 2020 census and administrative records. It is INEGI
# "estadistica derivada", not a direct survey estimate.
#
# --- What the numbers are, and are not ---------------------------------------
#  * The resolution is municipal, exactly as with the CENAPRED grades in
#    13_hazard.R: every AGEB of a municipality carries the same value, so these
#    columns place the AGEB's municipality on a national income ranking and say
#    nothing about which neighbourhood is poorer. Within-municipality contrast
#    has to come from the census-derived columns (GRS, PCT_VIV_SIN_BIENES, ...).
#  * Pesos of 2022 (current prices of the ENIGH 2022 fieldwork, Aug-Nov 2022),
#    per household and per quarter; divide by 3 for a monthly figure. It is a
#    mean, so a few rich households pull it up; the ICMM publishes no median.
#  * Each value carries its 90% confidence interval and coefficient of
#    variation. INEGI rates CV < 15 as high precision; the 2022 edition stays
#    under 12.4 in every municipality, highest in small Oaxaca municipalities.
#
# The archive also carries national (mun = 0, ent = 0) and state (mun = 0)
# rows; only the municipal rows are kept. The ENIGH's own national figure for
# 2022 (63,695 pesos) is the ent = 0 row, which is a handy sanity check.

# Every municipality of the 2020 marco; the same spine CENAPRED covers.
INCOME_MUNICIPALITIES <- 2469L

income_raw_dir <- function() file.path(DIR_RAW, "national", "icmm")

# Called from download_national() in 02_download.R, like every other source.
download_income <- function() {
  zip_path <- file.path(DIR_RAW, "national", sprintf("icmm_%d.zip", YEARS$icmm))
  download_cached(url_icmm(YEARS$icmm), zip_path)
  unzip_cached(zip_path, income_raw_dir())
  invisible(TRUE)
}

# One row per municipality, one column per estimator. Built once, cached,
# sliced per entity afterwards -- the same pattern as hazard_national.
load_income_national <- function() {
  cache <- file.path(DIR_INTERIM, "income_national.rds")
  if (file.exists(cache)) return(readRDS(cache))

  log_step("ICMM municipal income ", YEARS$icmm, " (national)")
  if (!file.exists(file.path(income_raw_dir(), ".unzipped"))) download_income()
  path <- find_file(income_raw_dir(), "conjunto_de_datos/conjunto_de_datos_icmm_.*[.]csv$")
  raw <- read_utf8_csv(path)

  # "icpth" holds every estimator, told apart by "est"; a renamed field would
  # otherwise surface much later as an all-NA income block.
  missing_field <- setdiff(c("ent", "mun", "est", "icpth"), names(raw))
  if (length(missing_field) > 0) {
    stop("ICMM ", YEARS$icmm, " no longer publishes ",
         paste(missing_field, collapse = ", "), call. = FALSE)
  }
  absent_est <- setdiff(INCOME_SOURCES, raw$est)
  if (length(absent_est) > 0) {
    stop("ICMM ", YEARS$icmm, " has no estimator code(s) ",
         paste(absent_est, collapse = ", "), call. = FALSE)
  }

  mun <- raw |>
    filter(as.integer(mun) > 0, est %in% INCOME_SOURCES) |>
    transmute(CVE_MUN_FULL = build_mun_id(ent, mun),
              COL = names(INCOME_SOURCES)[match(est, INCOME_SOURCES)],
              VALUE = as.numeric(icpth))
  if (anyDuplicated(mun[c("CVE_MUN_FULL", "COL")])) {
    stop("ICMM ", YEARS$icmm, " repeats a municipality x estimator row", call. = FALSE)
  }
  out <- mun |>
    tidyr::pivot_wider(names_from = COL, values_from = VALUE) |>
    select(CVE_MUN_FULL, all_of(INCOME_COLS))

  # The interval must bracket the estimate; if not, the estimator codes were
  # reshuffled upstream and the columns would be mislabelled.
  bad <- with(out, sum(!(ING_MUN_LIM_INF <= ING_MUN_HOG_TRIM &
                           ING_MUN_HOG_TRIM <= ING_MUN_LIM_SUP), na.rm = TRUE))
  if (bad > 0) {
    stop("ICMM ", YEARS$icmm, ": ", bad, " municipalities whose confidence ",
         "interval does not contain the estimate; check the est catalog", call. = FALSE)
  }

  if (nrow(out) != INCOME_MUNICIPALITIES) {
    log_msg("  !! ", nrow(out), " municipalities in the ICMM, expected ",
            INCOME_MUNICIPALITIES)
  }
  log_msg("  ", nrow(out), " municipalities | median ",
          format(round(median(out$ING_MUN_HOG_TRIM)), big.mark = ","),
          " pesos per household per quarter | max CV ",
          round(max(out$ING_MUN_CV), 2), "%")
  saveRDS(out, cache)
  out
}

build_income <- function(ent) {
  log_step("income ", ent)
  inc   <- load_income_national()
  attrs <- readRDS(interim_path("ageb_attrs", ent))

  out <- attrs |>
    select(ID_AGEB, CVE_MUN_FULL) |>
    left_join(inc, by = "CVE_MUN_FULL")

  # Reported here and failed in 11_qc.R rather than stopped, as in 13_hazard.R.
  unmatched <- unique(out$CVE_MUN_FULL[is.na(out$ING_MUN_HOG_TRIM)])
  if (length(unmatched) > 0) {
    log_msg("  !! ", length(unmatched), " municipalit",
            if (length(unmatched) == 1) "y" else "ies",
            " absent from the ICMM: ", paste(head(unmatched, 5), collapse = ", "))
  }

  out <- out |> select(-CVE_MUN_FULL)
  if (anyDuplicated(out$ID_AGEB) || !setequal(out$ID_AGEB, attrs$ID_AGEB)) {
    stop("municipal income does not map one-to-one onto the AGEB spine in entity ",
         ent, call. = FALSE)
  }

  log_msg("  ", nrow(out), " AGEB | municipalities matched: ",
          length(unique(attrs$CVE_MUN_FULL)) - length(unmatched), " of ",
          length(unique(attrs$CVE_MUN_FULL)))
  saveRDS(out, interim_path("income", ent))
  invisible(out)
}
