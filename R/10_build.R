# 10_build.R -- assemble every block onto the AGEB spine.
#
# The Marco Geoestadistico is the spine and every other source is LEFT joined
# onto it. That ordering is deliberate: it guarantees one row per real AGEB and
# complete municipal coverage, and it silently drops source rows that describe
# AGEB the marco does not recognise (see 04_census_urban.R).
#
# Urban and rural population arrive through different products and are stacked,
# never added, so no AGEB can be counted twice.

build_complete <- function(ent) {
  log_step("assembling ", ent)

  attrs    <- readRDS(interim_path("ageb_attrs", ent))
  mun      <- readRDS(interim_path("municipios", ent))
  census_u <- readRDS(interim_path("census_urban", ent))
  census_r <- readRDS(interim_path("census_rural", ent))
  coneval  <- readRDS(interim_path("coneval", ent))
  denue    <- readRDS(interim_path("denue", ent))
  hydro    <- readRDS(interim_path("hydrology", ent))
  landuse  <- readRDS(interim_path("landuse", ent))

  census <- bind_rows(census_u, census_r)
  if (anyDuplicated(census$ID_AGEB)) {
    stop("an AGEB received both urban and rural census rows in entity ", ent,
         call. = FALSE)
  }

  df <- attrs |>
    left_join(mun, by = "CVE_MUN_FULL") |>
    left_join(census, by = "ID_AGEB") |>
    left_join(coneval, by = "ID_AGEB") |>
    left_join(denue, by = "ID_AGEB") |>
    left_join(hydro, by = "ID_AGEB") |>
    left_join(landuse, by = "ID_AGEB") |>
    mutate(
      NOM_ENT = unname(ENTITY_NAMES[ent]),
      NOM_LOC = NOM_LOC_CENSUS,

      # DENUE counts are genuine zeros where the source has no establishment,
      # unlike census variables, where NA means suppressed.
      across(c(DENUE_TOT, DEN_MANUF, DEN_COM, DEN_SERV, DEN_EDU, DEN_GOB,
               SCHOOL_TOT), ~ coalesce(.x, 0L)),

      # A rural AGEB that matched no ITER locality at all is uninhabited
      # territory, not a suppressed measurement: it has no locality in the
      # marco either, and no DENUE establishment. Zero is the true value there.
      #
      # The flag is computed once from POB_TOTAL and applied to the whole row.
      # Filling column by column would be wrong: a rural AGEB can have a known
      # total while its sex split was suppressed, and zeroing only that split
      # would manufacture POB_HOMBRES + POB_MUJERES != POB_TOTAL. Urban AGEB
      # are never zero-filled -- there NA really does mean suppressed.
      UNINHABITED = AMBITO == "Rural" & is.na(POB_TOTAL),
      across(all_of(names(CENSUS_VARS)), ~ if_else(UNINHABITED, 0, .x)),

      PCT_HOMBRES  = safe_pct(POB_HOMBRES, POB_TOTAL),
      PCT_MUJERES  = safe_pct(POB_MUJERES, POB_TOTAL),
      DENS_POB_KM2 = safe_ratio(POB_TOTAL, AREA_KM2),
      POB_POR_VIV  = safe_ratio(POB_TOTAL, VIV_PART_HAB),
      PCT_DRENAJE  = safe_pct(VIV_DRENAJE, VIV_PART_HAB),
      PCT_ELECTRIC = safe_pct(VIV_ELECTRICIDAD, VIV_PART_HAB),

      YEAR_GEOMETRY = YEARS$geometry,
      YEAR_CENSUS   = YEARS$census,
      YEAR_CONEVAL  = YEARS$coneval,
      YEAR_DENUE    = YEARS$denue,
      YEAR_HIDRO    = YEARS$hidro,
      YEAR_USV      = YEARS$usv
    ) |>
    select(-UNINHABITED)

  log_msg("  rows: ", nrow(df), " | with census: ", sum(!is.na(df$POB_TOTAL)),
          " | with GRS: ", sum(!is.na(df$GRS_GRADO)))
  saveRDS(df, interim_path("complete", ent))
  invisible(df)
}
