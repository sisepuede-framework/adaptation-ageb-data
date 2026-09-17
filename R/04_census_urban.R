# 04_census_urban.R -- population and housing for URBAN AGEB, from the
# ageb_manzana census product.
#
# The file mixes granularities in one table. The AGEB total is the row with
# MZA == "000"; rows with AGEB == "0000" are locality/municipal totals and must
# be excluded or every AGEB would be double counted (spec section 5.2).
#
# NOM_LOC is NOT usable here: every AGEB-total row carries the literal string
# "Total AGEB urbana". Real locality names come from the MG locality layer.
#
# TVIVPARHAB bounds every VPH_* count, but it is not their universe: it also
# holds dwellings with no information on occupants. Housing shares divide by
# VIV_CARACT instead (see 10_build.R). VIVPAR_HAB is neither: VPH_* can exceed it.
#
# A handful of AGEB in this product have no polygon in the MG urban layer --
# borderline localities (~2,500-3,700 inhabitants) that the MG assigns to a
# RURAL AGEB instead. Their population already arrives through the ITER path,
# so counting them here too would double count. They are not filtered by a
# name marker; the MG geometry is the spine, and 10_build.R joins onto it,
# which drops them. This function only reports them.

# Census counts, output name = census column. Both census products (ageb_manzana
# and ITER) carry every one of them under the same name. Selected for a climate
# vulnerability index: demographic sensitivity (age, disability, language), the
# census equivalents of CONEVAL's rezago indicators -- which CONEVAL publishes
# for urban AGEB only -- economic activity, and housing traits tied to heat,
# flooding, water stress and the reach of early warnings. Shares are derived in 10_build.R.
CENSUS_VARS <- c(
  POB_TOTAL           = "POBTOT",
  POB_HOMBRES         = "POBMAS",
  POB_MUJERES         = "POBFEM",
  # Sensitivity
  POB_0A2             = "P_0A2",
  POB_3A5             = "P_3A5",
  POB_65YMAS          = "POB65_MAS",
  POB_DISC            = "PCON_DISC",
  POB_3YMAS           = "P_3YMAS",
  POB_HLI             = "P3YM_HLI",
  POB_HLI_NHE         = "P3HLINHE",   # indigenous language and no Spanish
  # Education and health (CONEVAL rezago equivalents)
  POB_SIN_SALUD       = "PSINDER",
  POB_15YMAS          = "P_15YMAS",
  POB_15YMAS_ANALF    = "P15YM_AN",
  POB_15YMAS_SIN_ESC  = "P15YM_SE",
  POB_15YMAS_PRIM_INC = "P15PRI_IN",
  POB_15YMAS_PRIM_COM = "P15PRI_CO",
  POB_15YMAS_SEC_INC  = "P15SEC_IN",
  POB_6A11            = "P_6A11",
  POB_12A14           = "P_12A14",
  POB_6A11_NOASIS     = "P6A11_NOA",
  POB_12A14_NOASIS    = "P12A14NOA",
  POB_15A17           = "P_15A17",
  POB_18A24           = "P_18A24",
  POB_15A17_ASIS      = "P15A17A",
  POB_18A24_ASIS      = "P18A24A",
  # Employment, population 12+. Income is not in the census, so economic
  # activity is the closest recovery-capacity signal it offers.
  POB_PEA             = "PEA",
  POB_PEA_F           = "PEA_F",
  POB_INAC            = "PE_INAC",
  POB_INAC_F          = "PE_INAC_F",
  POB_DESOCUP         = "PDESOCUP",
  # Households
  HOGARES             = "TOTHOG",
  HOGARES_JEFA        = "HOGJEF_F",
  # Housing
  VIV_PART_HAB        = "TVIVPARHAB",
  VIV_OCUPANTES       = "OCUPVIVPAR",
  VIV_DRENAJE         = "VPH_DRENAJ",
  VIV_ELECTRICIDAD    = "VPH_C_ELEC",
  VIV_SIN_DRENAJE     = "VPH_NODREN",
  VIV_SIN_ELECTRICIDAD = "VPH_S_ELEC",
  VIV_SIN_AGUA        = "VPH_AGUAFV",
  VIV_PISO_TIERRA     = "VPH_PISOTI",
  VIV_1CUARTO         = "VPH_1CUART",
  VIV_EXCUSADO        = "VPH_EXCSA",
  VIV_LETRINA         = "VPH_LETR",
  VIV_TINACO          = "VPH_TINACO",
  VIV_CISTERNA        = "VPH_CISTER",
  VIV_REFRI           = "VPH_REFRI",
  VIV_LAVADORA        = "VPH_LAVAD",
  VIV_AUTO            = "VPH_AUTOM",
  VIV_RADIO           = "VPH_RADIO",
  VIV_TELEFONO        = "VPH_TELEF",
  VIV_CELULAR         = "VPH_CEL",
  VIV_INTERNET        = "VPH_INTER",
  VIV_COMPU           = "VPH_PC",
  VIV_SIN_RADIO_TV    = "VPH_SINRTV",
  VIV_SIN_TEL_CEL     = "VPH_SINLTC",
  VIV_SIN_TIC         = "VPH_SINTIC",
  VIV_SIN_BIENES      = "VPH_SNBIEN"
)

# Census averages. They cannot be summed across localities, so both products
# turn them into additive totals right after reading (census_avg_to_totals) and
# 10_build.R divides the totals back into averages.
CENSUS_AVG_VARS <- c("GRAPROES", "PRO_OCUP_C")
CENSUS_TOTAL_VARS <- c("ESC_ANIOS_TOT", "OCUP_CON_CUARTOS", "CUARTOS_TOT")

# Everything except the headcount. POBTOT is never suppressed in either census
# product; these are the variables INEGI blanks ("*" confidentiality, "N/D").
CENSUS_CHAR_VARS <- c(setdiff(names(CENSUS_VARS), "POB_TOTAL"), CENSUS_TOTAL_VARS)

# Characteristics grouped by the population their shares divide by. Rural AGEB
# aggregate localities, and INEGI blanks a locality group by group (sex can be
# published while everything else is "N/D"), so each group gets its own
# denominator: the population of the localities that report that group
# (POB_DEN_<group>). Across all 189,432 ITER localities PERS and VIV are always
# blanked together; they stay apart because their universes differ. A share's
# numerator and universe must sit in the same group so that both are summed
# over the same localities. A new census variable must join a group here.
CENSUS_GROUPS <- list(
  SEXO = c("POB_HOMBRES", "POB_MUJERES"),
  PERS = c("POB_0A2", "POB_3A5", "POB_65YMAS", "POB_DISC", "POB_3YMAS",
           "POB_HLI", "POB_HLI_NHE", "POB_SIN_SALUD", "POB_15YMAS",
           "POB_15YMAS_ANALF", "POB_15YMAS_SIN_ESC", "POB_15YMAS_PRIM_INC",
           "POB_15YMAS_PRIM_COM", "POB_15YMAS_SEC_INC", "POB_6A11", "POB_12A14",
           "POB_6A11_NOASIS", "POB_12A14_NOASIS", "POB_15A17", "POB_18A24",
           "POB_15A17_ASIS", "POB_18A24_ASIS", "POB_PEA", "POB_PEA_F",
           "POB_INAC", "POB_INAC_F", "POB_DESOCUP", "ESC_ANIOS_TOT"),
  VIV  = c("HOGARES", "HOGARES_JEFA", "VIV_PART_HAB", "VIV_OCUPANTES",
           "VIV_DRENAJE", "VIV_ELECTRICIDAD", "VIV_SIN_DRENAJE",
           "VIV_SIN_ELECTRICIDAD", "VIV_SIN_AGUA", "VIV_PISO_TIERRA",
           "VIV_1CUARTO", "VIV_EXCUSADO", "VIV_LETRINA", "VIV_TINACO", "VIV_CISTERNA",
           "VIV_REFRI", "VIV_LAVADORA", "VIV_AUTO", "VIV_RADIO", "VIV_TELEFONO",
           "VIV_CELULAR", "VIV_INTERNET", "VIV_COMPU", "VIV_SIN_RADIO_TV",
           "VIV_SIN_TEL_CEL", "VIV_SIN_TIC", "VIV_SIN_BIENES",
           "OCUP_CON_CUARTOS", "CUARTOS_TOT")
)
stopifnot(setequal(unlist(CENSUS_GROUPS), CENSUS_CHAR_VARS),
          !anyDuplicated(unlist(CENSUS_GROUPS)))

census_den_col <- function(group) paste0("POB_DEN_", group)
CENSUS_DEN_COLS <- census_den_col(names(CENSUS_GROUPS))

# The urban product never publishes a count of 1 or 2: across all 64,313 urban
# AGEB rows not one cell holds either value, while 0 and 3 are common. Every
# "*" in a published row therefore stands for 1 or 2 and is imputed as the
# midpoint (error at most +-0.5). Left as NA, it would blank rare deprivation
# counts (no electricity, dirt floor) in 25-30% of urban AGEB -- precisely the
# least deprived ones, so the gap would bias any index built on top.
URBAN_SUPPRESSED_VALUE <- 1.5

# Averages -> additive totals. Occupants per room becomes rooms = occupants /
# average. An average of 0 contributes nothing to either total: with no
# occupants that is exact, and occupants with 0 per room is a source
# inconsistency (17 urban AGEB nationally) better dropped than divided by.
census_avg_to_totals <- function(df) {
  df |>
    mutate(
      ESC_ANIOS_TOT = GRAPROES * POB_15YMAS,
      OCUP_CON_CUARTOS = if_else(PRO_OCUP_C > 0, VIV_OCUPANTES, 0),
      CUARTOS_TOT      = if_else(PRO_OCUP_C > 0, VIV_OCUPANTES / PRO_OCUP_C, 0)
    ) |>
    select(-all_of(CENSUS_AVG_VARS))
}

build_census_urban <- function(ent) {
  log_step("urban census ", ent)
  path <- find_file(file.path(DIR_RAW, ent, "census_urban"),
                    "conjunto_de_datos_ageb_urbana_.*\\.csv$")

  raw <- read_utf8_csv(path) |> rename_with(~ sub("^﻿", "", .x))

  count_cols <- unname(CENSUS_VARS)

  out <- raw |>
    filter(MZA == "000", AGEB != "0000") |>
    transmute(
      ID_AGEB = build_ageb_id(ENTIDAD, MUN, LOC, AGEB),
      ID_LOC  = build_loc_id(ENTIDAD, MUN, LOC),
      # A wholly suppressed AGEB (1-2 dwellings) blanks every characteristic,
      # averages included; averages are never blanked otherwise, so GRAPROES
      # marks those rows exactly. Their "*" is not a small count: no imputation.
      ROW_BLANK = GRAPROES %in% "*",
      N_CELDAS_IMPUTADAS = if_else(
        ROW_BLANK, 0, rowSums(across(all_of(count_cols), ~ .x %in% "*"))),
      across(all_of(count_cols),
             ~ if_else(.x %in% "*" & !ROW_BLANK, URBAN_SUPPRESSED_VALUE,
                       to_num_suppressed(.x))),
      across(all_of(CENSUS_AVG_VARS), to_num_suppressed)
    ) |>
    rename(!!!CENSUS_VARS) |>
    distinct(ID_AGEB, .keep_all = TRUE) |>
    census_avg_to_totals() |>
    # There is nothing to aggregate in an urban AGEB, so every group divides by
    # the full population. POB_REPORTADA is zero only for a wholly suppressed
    # row, so it reads the same in both ambits: the population whose
    # characteristics were published (see 05_census_rural.R).
    mutate(POB_REPORTADA = if_else(ROW_BLANK, 0, POB_TOTAL)) |>
    select(-ROW_BLANK)
  for (den in CENSUS_DEN_COLS) out[[den]] <- out$POB_TOTAL

  # Attach real locality names from the MG urban locality layer.
  urban_loc <- readRDS(interim_path("locality_bridge", ent))$urban
  out <- out |>
    left_join(urban_loc, by = "ID_LOC") |>
    rename(NOM_LOC_CENSUS = NOM_LOC) |>
    select(-ID_LOC)

  spine <- readRDS(interim_path("ageb_attrs", ent))
  urban_spine <- spine$ID_AGEB[spine$AMBITO == "Urbana"]
  orphan <- out |> filter(!ID_AGEB %in% urban_spine)
  if (nrow(orphan) > 0) {
    log_msg("  note: ", nrow(orphan), " census AGEB have no MG urban polygon (pop ",
            format(sum(orphan$POB_TOTAL, na.rm = TRUE), big.mark = ","),
            "); counted via ITER on the rural side, dropped here")
  }

  kept <- out |> filter(ID_AGEB %in% urban_spine)
  log_msg("  urban AGEB rows: ", nrow(kept),
          " | population: ", format(sum(kept$POB_TOTAL, na.rm = TRUE), big.mark = ","),
          " | cells imputed as ", URBAN_SUPPRESSED_VALUE, ": ",
          format(sum(kept$N_CELDAS_IMPUTADAS), big.mark = ","),
          " in ", sum(kept$N_CELDAS_IMPUTADAS > 0), " AGEB")
  saveRDS(kept, interim_path("census_urban", ent))
  invisible(kept)
}
