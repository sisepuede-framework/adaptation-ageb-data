# 05_census_rural.R -- population and housing for RURAL AGEB.
#
# The rural equivalent of the ageb_manzana product does not exist: the census
# publishes rural detail per LOCALITY (ITER), which carries no AGEB key. The
# Marco Geoestadistico supplies the missing link -- {ENT}lpr.shp lists every
# rural locality together with its CVE_AGEB (verified: it is a superset of the
# rural localities in {ENT}l.shp). So the path is
#   ITER locality -> MG bridge -> rural AGEB -> sum.

build_census_rural <- function(ent) {
  log_step("rural census ", ent)
  path <- find_file(file.path(DIR_RAW, ent, "iter"),
                    "conjunto_de_datos_iter_.*\\.csv$")

  bridge <- readRDS(interim_path("locality_bridge", ent))$rural

  iter <- read_utf8_csv(path) |>
    rename_with(~ sub("^﻿", "", .x)) |>
    # LOC 0000 is the municipal total; 9998/9999 are the "localidades de una
    # vivienda" and "no especificado" aggregates. All three would double count.
    filter(LOC != "0000", as.integer(LOC) < 9998) |>
    transmute(
      ID_LOC = build_loc_id(ENTIDAD, MUN, LOC),
      NOM_LOC_ITER = NOM_LOC,
      across(all_of(unname(CENSUS_VARS)), to_num_suppressed)
    ) |>
    rename(!!!CENSUS_VARS)

  joined <- iter |> inner_join(bridge, by = "ID_LOC")

  unmatched <- nrow(iter) - nrow(joined)
  log_msg("  ITER localities: ", nrow(iter), " | matched to rural AGEB: ",
          nrow(joined), " | unmatched (urban or absent): ", unmatched)

  out <- joined |>
    group_by(ID_AGEB) |>
    summarise(
      # Suppressed values are NA, so na.rm would silently read as zero. An AGEB
      # is only summed when every contributing locality reported the variable.
      across(all_of(names(CENSUS_VARS)), ~ if (all(is.na(.x))) NA_real_ else sum(.x)),
      N_LOC = n(),
      NOM_LOC_CENSUS = if (n() == 1) first(NOM_LOC_ITER) else "(varias localidades)",
      .groups = "drop"
    ) |>
    select(-N_LOC)

  log_msg("  rural AGEB rows: ", nrow(out),
          " | population: ", format(sum(out$POB_TOTAL, na.rm = TRUE), big.mark = ","))
  saveRDS(out, interim_path("census_rural", ent))
  invisible(out)
}
