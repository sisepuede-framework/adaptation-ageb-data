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
# TVIVPARHAB is the denominator for the VPH_* counts, not VIVPAR_HAB: only the
# former satisfies VPH_* <= denominator across essentially all AGEB.
#
# A handful of AGEB in this product have no polygon in the MG urban layer --
# borderline localities (~2,500-3,700 inhabitants) that the MG assigns to a
# RURAL AGEB instead. Their population already arrives through the ITER path,
# so counting them here too would double count. They are not filtered by a
# name marker; the MG geometry is the spine, and 10_build.R joins onto it,
# which drops them. This function only reports them.

CENSUS_VARS <- c(
  POB_TOTAL        = "POBTOT",
  POB_HOMBRES      = "POBMAS",
  POB_MUJERES      = "POBFEM",
  VIV_PART_HAB     = "TVIVPARHAB",
  VIV_DRENAJE      = "VPH_DRENAJ",
  VIV_ELECTRICIDAD = "VPH_C_ELEC"
)

build_census_urban <- function(ent) {
  log_step("urban census ", ent)
  path <- find_file(file.path(DIR_RAW, ent, "census_urban"),
                    "conjunto_de_datos_ageb_urbana_.*\\.csv$")

  raw <- read_utf8_csv(path) |> rename_with(~ sub("^﻿", "", .x))

  out <- raw |>
    filter(MZA == "000", AGEB != "0000") |>
    transmute(
      ID_AGEB = build_ageb_id(ENTIDAD, MUN, LOC, AGEB),
      ID_LOC  = build_loc_id(ENTIDAD, MUN, LOC),
      across(all_of(unname(CENSUS_VARS)), to_num_suppressed)
    ) |>
    rename(!!!CENSUS_VARS) |>
    distinct(ID_AGEB, .keep_all = TRUE)

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
          " | population: ", format(sum(kept$POB_TOTAL, na.rm = TRUE), big.mark = ","))
  saveRDS(kept, interim_path("census_urban", ent))
  invisible(kept)
}
