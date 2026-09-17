# 10_build.R -- assemble every block onto the AGEB spine.
#
# The Marco Geoestadistico is the spine and every other source is LEFT joined
# onto it. That ordering is deliberate: it guarantees one row per real AGEB and
# complete municipal coverage, and it silently drops source rows that describe
# AGEB the marco does not recognise (see 04_census_urban.R).
#
# Urban and rural population arrive through different products and are stacked,
# never added, so no AGEB can be counted twice.

# Census shares derived below, in publication order. 11_qc.R range-checks them
# and 12_export.R publishes them.
CENSUS_SHARE_COLS <- c(
  # Sensitivity
  "PCT_POB_0A5", "PCT_POB_65YMAS", "PCT_POB_DISC", "PCT_POB_HLI",
  "PCT_POB_HLI_NHE", "PCT_HOG_JEFA",
  # CONEVAL rezago equivalents
  "PCT_POB_SIN_SALUD", "PCT_ANALF", "PCT_EDU_BAS_INC", "PCT_NOASIS_6A14",
  "PCT_NOASIS_15A24",
  # Employment
  "PCT_PEA", "PCT_PEA_F", "PCT_DESOCUP",
  # Housing
  "PCT_VIV_SIN_DRENAJE", "PCT_VIV_SIN_ELECTRIC", "PCT_VIV_SIN_AGUA",
  "PCT_VIV_PISO_TIERRA", "PCT_VIV_1CUARTO", "PCT_VIV_SIN_SANITARIO",
  "PCT_VIV_TINACO", "PCT_VIV_CISTERNA", "PCT_VIV_REFRI", "PCT_VIV_LAVADORA",
  "PCT_VIV_AUTO", "PCT_VIV_RADIO", "PCT_VIV_TELEFONO", "PCT_VIV_CELULAR",
  "PCT_VIV_INTERNET", "PCT_VIV_COMPU", "PCT_VIV_SIN_RADIO_TV",
  "PCT_VIV_SIN_TEL_CEL", "PCT_VIV_SIN_TIC", "PCT_VIV_SIN_BIENES"
)
CENSUS_AVG_COLS <- c("GRAPROES", "PRO_OCUP_C")

# CONEVAL urban rezago indicator -> the census share that measures it here.
# CONEVAL states deprivation ("sin lavadora"); where the census only counts
# possession the share runs the other way, listed in CONEVAL_INVERTED.
CONEVAL_EQUIVALENTS <- c(
  RZ_ANALF   = "PCT_ANALF",            RZ_INA614  = "PCT_NOASIS_6A14",
  RZ_INA1524 = "PCT_NOASIS_15A24",     RZ_EBINC   = "PCT_EDU_BAS_INC",
  RZ_SSALUD  = "PCT_POB_SIN_SALUD",    RZ_HACIN   = "PRO_OCUP_C",
  RZ_SAGUA   = "PCT_VIV_SIN_AGUA",     RZ_SEXCUS  = "PCT_VIV_SIN_SANITARIO",
  RZ_SDREN   = "PCT_VIV_SIN_DRENAJE",  RZ_SELEC   = "PCT_VIV_SIN_ELECTRIC",
  RZ_PISOT   = "PCT_VIV_PISO_TIERRA",  RZ_SLAVAD  = "PCT_VIV_LAVADORA",
  RZ_SREFRI  = "PCT_VIV_REFRI",        RZ_STELF   = "PCT_VIV_TELEFONO",
  RZ_SCEL    = "PCT_VIV_CELULAR",      RZ_SCOMPU  = "PCT_VIV_COMPU",
  RZ_SINTER  = "PCT_VIV_INTERNET"
)
CONEVAL_INVERTED <- c("RZ_SLAVAD", "RZ_SREFRI", "RZ_STELF", "RZ_SCEL",
                      "RZ_SCOMPU", "RZ_SINTER")

# Largest population-weighted mean absolute gap to CONEVAL, in percentage
# points, that 11_qc.R accepts. Calibrated on four entities (Oaxaca, CDMX,
# Chiapas, Estado de Mexico) against deliberately broken formulas: correct
# single-count shares stay under 0.08 while a wrong universe or definition
# lands at 0.24-15; shares built from several counts (or from person totals
# CONEVAL may exclude unspecified answers from) run noisier when correct.
CONEVAL_MAX_WMAE <- c(
  RZ_ANALF = 0.25, RZ_SAGUA = 0.25, RZ_SEXCUS = 0.25, RZ_SDREN = 0.25,
  RZ_SELEC = 0.25, RZ_PISOT = 0.25, RZ_SLAVAD = 0.25, RZ_SREFRI = 0.25,
  RZ_STELF = 0.25, RZ_SCEL = 0.25, RZ_SCOMPU = 0.25, RZ_SINTER = 0.25,
  RZ_INA614 = 1.0, RZ_SSALUD = 1.0,
  RZ_EBINC = 1.5, RZ_INA1524 = 1.5
)
stopifnot(setequal(names(CONEVAL_MAX_WMAE), setdiff(RZ_NAMES, "RZ_HACIN")))
stopifnot(setequal(names(CONEVAL_EQUIVALENTS), RZ_NAMES),
          all(setdiff(CONEVAL_EQUIVALENTS, CENSUS_AVG_COLS) %in% CENSUS_SHARE_COLS))

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
  health   <- readRDS(interim_path("health", ent))

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
    left_join(health, by = "ID_AGEB") |>
    mutate(
      NOM_ENT = unname(ENTITY_NAMES[ent]),
      NOM_LOC = NOM_LOC_CENSUS,

      # DENUE counts are genuine zeros where the source has no establishment,
      # unlike census variables, where NA means suppressed.
      across(c(DENUE_TOT, DEN_MANUF, DEN_COM, DEN_SERV, DEN_EDU, DEN_GOB,
               SCHOOL_TOT), ~ coalesce(.x, 0L)),

      # A rural AGEB that matched no ITER locality at all is uninhabited
      # territory, not a suppressed measurement: it has no locality in the
      # marco either. Zero is the true value there.
      #
      # The flag comes from the join itself, not from is.na(POB_TOTAL): a
      # missing headcount would be read as "nobody lives here", which is only
      # safe while INEGI never suppresses POBTOT (05_census_rural.R enforces
      # that). It is applied to the whole row at once, so the zeroed counts
      # stay internally consistent. Urban AGEB are never zero-filled -- there
      # NA really does mean suppressed.
      UNINHABITED = AMBITO == "Rural" & !ID_AGEB %in% census_r$ID_AGEB,
      across(all_of(c(names(CENSUS_VARS), CENSUS_TOTAL_VARS, "POB_REPORTADA",
                      CENSUS_DEN_COLS, "N_CELDAS_IMPUTADAS")),
             ~ if_else(UNINHABITED, 0, .x)),

      # Shares divide by the population of the localities that reported the
      # numerator's group (CENSUS_GROUPS), not by POB_TOTAL: in a rural AGEB
      # the two differ by the hamlets whose characteristics INEGI suppressed.
      # For urban AGEB every POB_DEN_* equals POB_TOTAL. DENS_POB_KM2 keeps the
      # full headcount, which is never suppressed.
      PCT_POB_REPORTADA = safe_pct(POB_REPORTADA, POB_TOTAL),
      PCT_HOMBRES  = safe_pct(POB_HOMBRES, POB_DEN_SEXO),
      PCT_MUJERES  = safe_pct(POB_MUJERES, POB_DEN_SEXO),
      DENS_POB_KM2 = safe_ratio(POB_TOTAL, AREA_KM2),
      POB_POR_VIV  = safe_ratio(POB_DEN_VIV, VIV_PART_HAB),

      # Housing traits (VPH_*) describe only the dwellings whose
      # characteristics were captured. TVIVPARHAB also counts dwellings with
      # no information on their occupants, so dividing by it inflates every
      # deprivation where census non-response is high -- a CDMX AGEB with 446
      # dwellings and 187 mobile phones read 58% "sin celular" against
      # CONEVAL's 2.6%. The census publishes no count of that universe; the
      # dwellings that answered the electricity question (con + sin) are the
      # closest one. Against CONEVAL across 58,772 urban AGEB this universe
      # matches or beats TVIVPARHAB on every housing indicator (RZ_SCEL:
      # r 0.94 -> 0.99, 90th-percentile gap 0.8 -> 0.2 points).
      #
      # Each con + sin pair, and each single trait count, is a lower bound on
      # that universe (a trait left unspecified drops out of its pair), so the
      # tightest estimate is the largest of them, capped by TVIVPARHAB. Taking
      # the maximum matters in tiny urban AGEB, where an imputed 1.5 can leave
      # the electricity pair half a dwelling short of a published count.
      VIV_CARACT   = pmin(VIV_PART_HAB, pmax(
        VIV_ELECTRICIDAD + VIV_SIN_ELECTRICIDAD, VIV_DRENAJE + VIV_SIN_DRENAJE,
        VIV_EXCUSADO + VIV_LETRINA, VIV_SIN_AGUA, VIV_PISO_TIERRA, VIV_1CUARTO,
        VIV_TINACO, VIV_CISTERNA, VIV_REFRI, VIV_LAVADORA, VIV_AUTO, VIV_RADIO,
        VIV_TELEFONO, VIV_CELULAR, VIV_INTERNET, VIV_COMPU, VIV_SIN_RADIO_TV,
        VIV_SIN_TEL_CEL, VIV_SIN_TIC, VIV_SIN_BIENES)),
      PCT_DRENAJE  = safe_pct(VIV_DRENAJE, VIV_CARACT),
      PCT_ELECTRIC = safe_pct(VIV_ELECTRICIDAD, VIV_CARACT),

      # --- Sensitivity. Each numerator and its universe share a CENSUS_GROUPS
      # group, so both cover the same localities.
      PCT_POB_0A5       = safe_pct(POB_0A2 + POB_3A5, POB_DEN_PERS),
      PCT_POB_65YMAS    = safe_pct(POB_65YMAS, POB_DEN_PERS),
      PCT_POB_DISC      = safe_pct(POB_DISC, POB_DEN_PERS),
      PCT_POB_HLI       = safe_pct(POB_HLI, POB_3YMAS),
      PCT_POB_HLI_NHE   = safe_pct(POB_HLI_NHE, POB_3YMAS),
      PCT_HOG_JEFA      = safe_pct(HOGARES_JEFA, HOGARES),

      # --- Census equivalents of CONEVAL's rezago indicators, for both ambits.
      # Same definitions as RZ_* where the census allows it; RZ_HACIN
      # (share of overcrowded dwellings) has no census count, so the average
      # occupants per room stands in for it.
      PCT_POB_SIN_SALUD = safe_pct(POB_SIN_SALUD, POB_DEN_PERS),
      PCT_ANALF         = safe_pct(POB_15YMAS_ANALF, POB_15YMAS),
      # Four summed cells, each possibly imputed: in a handful of tiny urban
      # AGEB the estimate overshoots its universe, so it is bounded at 100.
      PCT_EDU_BAS_INC   = pmin(100, safe_pct(POB_15YMAS_SIN_ESC + POB_15YMAS_PRIM_INC +
                                               POB_15YMAS_PRIM_COM + POB_15YMAS_SEC_INC,
                                             POB_15YMAS)),
      PCT_NOASIS_6A14   = safe_pct(POB_6A11_NOASIS + POB_12A14_NOASIS,
                                   POB_6A11 + POB_12A14),
      # A difference of counts: with imputed cells it can dip just below 0.
      PCT_NOASIS_15A24  = pmax(0, safe_pct(POB_15A17 + POB_18A24 -
                                             POB_15A17_ASIS - POB_18A24_ASIS,
                                           POB_15A17 + POB_18A24)),
      GRAPROES          = safe_ratio(ESC_ANIOS_TOT, POB_15YMAS),
      PRO_OCUP_C       = safe_ratio(OCUP_CON_CUARTOS, CUARTOS_TOT),

      # --- Employment. The universe is the population 12+ whose activity
      # condition was captured (PEA + PE_INAC), not P_12YMAS, for the same
      # reason housing divides by VIV_CARACT: the unspecified answers are
      # small nationally (0.2-0.5% of P_12YMAS) but concentrated in a few
      # AGEB, up to 27% in Oaxaca. PDESOCUP is the unemployed over the
      # economically active (PEA = POCUPADA + PDESOCUP exactly). The census
      # rate runs low -- 2.3% in CDMX, 1.7% in Oaxaca -- because informal work
      # counts as occupied, so participation carries most of the signal.
      PCT_PEA     = safe_pct(POB_PEA, POB_PEA + POB_INAC),
      PCT_PEA_F   = safe_pct(POB_PEA_F, POB_PEA_F + POB_INAC_F),
      PCT_DESOCUP = safe_pct(POB_DESOCUP, POB_PEA),

      # --- Housing, over VIV_CARACT like PCT_DRENAJE and PCT_ELECTRIC.
      #
      # Deprivation comes from the census's own "sin" counts, never from
      # 100 - "con": some dwellings leave a given trait unspecified, and for
      # rare deprivations that slack swamps the signal. Against CONEVAL's urban
      # RZ_SELEC the direct count correlates at 0.98, the complement at 0.82.
      PCT_VIV_SIN_DRENAJE  = safe_pct(VIV_SIN_DRENAJE, VIV_CARACT),
      PCT_VIV_SIN_ELECTRIC = safe_pct(VIV_SIN_ELECTRICIDAD, VIV_CARACT),
      PCT_VIV_SIN_AGUA     = safe_pct(VIV_SIN_AGUA, VIV_CARACT),
      PCT_VIV_PISO_TIERRA  = safe_pct(VIV_PISO_TIERRA, VIV_CARACT),
      PCT_VIV_1CUARTO      = safe_pct(VIV_1CUARTO, VIV_CARACT),
      # No "sin sanitario" count exists, so this one is a complement.
      # CONEVAL counts a latrine as a toilet; with that, it reproduces
      # RZ_SEXCUS at r = 0.93, against 0.41 for 100 - excusado/TVIVPARHAB.
      PCT_VIV_SIN_SANITARIO = pmax(0, 100 - safe_pct(VIV_EXCUSADO + VIV_LETRINA,
                                                     VIV_CARACT)),
      PCT_VIV_TINACO       = safe_pct(VIV_TINACO, VIV_CARACT),
      PCT_VIV_CISTERNA     = safe_pct(VIV_CISTERNA, VIV_CARACT),
      PCT_VIV_REFRI        = safe_pct(VIV_REFRI, VIV_CARACT),
      PCT_VIV_LAVADORA     = safe_pct(VIV_LAVADORA, VIV_CARACT),
      PCT_VIV_AUTO         = safe_pct(VIV_AUTO, VIV_CARACT),
      PCT_VIV_RADIO        = safe_pct(VIV_RADIO, VIV_CARACT),
      PCT_VIV_TELEFONO     = safe_pct(VIV_TELEFONO, VIV_CARACT),
      PCT_VIV_CELULAR      = safe_pct(VIV_CELULAR, VIV_CARACT),
      PCT_VIV_INTERNET     = safe_pct(VIV_INTERNET, VIV_CARACT),
      PCT_VIV_COMPU        = safe_pct(VIV_COMPU, VIV_CARACT),
      PCT_VIV_SIN_RADIO_TV = safe_pct(VIV_SIN_RADIO_TV, VIV_CARACT),
      PCT_VIV_SIN_TEL_CEL  = safe_pct(VIV_SIN_TEL_CEL, VIV_CARACT),
      PCT_VIV_SIN_TIC      = safe_pct(VIV_SIN_TIC, VIV_CARACT),
      PCT_VIV_SIN_BIENES   = safe_pct(VIV_SIN_BIENES, VIV_CARACT),

      YEAR_GEOMETRY = YEARS$geometry,
      YEAR_CENSUS   = YEARS$census,
      YEAR_CONEVAL  = YEARS$coneval,
      YEAR_DENUE    = YEARS$denue,
      YEAR_HIDRO    = YEARS$hidro,
      YEAR_USV      = YEARS$usv,
      YEAR_CLUES    = YEARS$clues
    )
  # UNINHABITED stays in the interim table for 11_qc.R; the export drops it.

  log_msg("  rows: ", nrow(df), " | with census: ", sum(!is.na(df$POB_TOTAL)),
          " | with GRS: ", sum(!is.na(df$GRS_GRADO)))
  saveRDS(df, interim_path("complete", ent))
  invisible(df)
}
