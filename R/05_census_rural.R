# 05_census_rural.R -- population and housing for RURAL AGEB.
#
# The rural equivalent of the ageb_manzana product does not exist: the census
# publishes rural detail per LOCALITY (ITER), which carries no AGEB key. The
# Marco Geoestadistico supplies the missing link -- {ENT}lpr.shp lists every
# rural locality together with its CVE_AGEB (verified: it is a superset of the
# rural localities in {ENT}l.shp). So the path is
#   ITER locality -> MG bridge -> rural AGEB -> sum.
# The variable catalog (CENSUS_VARS, CENSUS_GROUPS) lives in 04_census_urban.R.

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
      across(all_of(c(unname(CENSUS_VARS), CENSUS_AVG_VARS)), to_num_suppressed)
    ) |>
    rename(!!!CENSUS_VARS) |>
    census_avg_to_totals()

  joined <- iter |> inner_join(bridge, by = "ID_LOC")

  unmatched <- nrow(iter) - nrow(joined)
  log_msg("  ITER localities: ", nrow(iter), " | matched to rural AGEB: ",
          nrow(joined), " | unmatched (urban or absent): ", unmatched)

  # The headcount is what makes a rural AGEB inhabited or not (10_build.R), so a
  # suppressed POBTOT would be indistinguishable from empty territory. INEGI
  # does not suppress it today; fail loudly if that ever changes.
  if (anyNA(joined$POB_TOTAL)) {
    stop(sum(is.na(joined$POB_TOTAL)), " ITER localities in entity ", ent,
         " have a suppressed POBTOT", call. = FALSE)
  }

  # ITER blanks characteristics per locality: a locality with 1-2 inhabited
  # dwellings publishes its headcount and suppresses ("*") everything else, and
  # some localities publish sex but carry "N/D" for housing. Summing without
  # na.rm let one such hamlet blank its whole AGEB -- in Oaxaca that erased the
  # housing profile of 58% of the rural population to protect 0.6% of it.
  #
  # Instead each CENSUS_GROUPS group is summed over the localities that report
  # the whole group, and their population is carried as that group's
  # denominator (POB_DEN_*). Within a group every count then covers the same
  # localities, so no share mixes two different sets of hamlets.
  base <- joined |>
    mutate(REPORTS_ALL = if_all(all_of(CENSUS_CHAR_VARS), ~ !is.na(.x))) |>
    group_by(ID_AGEB) |>
    summarise(
      # Ordered so POB_TOTAL is still per locality when POB_REPORTADA reads it.
      POB_REPORTADA = sum(POB_TOTAL[REPORTS_ALL]),
      POB_TOTAL = sum(POB_TOTAL),
      NOM_LOC_CENSUS = if (n() == 1) first(NOM_LOC_ITER) else "(varias localidades)",
      .groups = "drop"
    )

  by_group <- imap(CENSUS_GROUPS, function(vars, g) {
    reports <- rowSums(is.na(joined[vars])) == 0
    partial <- sum(!reports & rowSums(!is.na(joined[vars])) > 0)
    if (partial > 0) {
      log_msg("  note: ", partial, " localities report only part of group ", g,
              "; excluded from that group")
    }
    joined |>
      mutate(REP = reports) |>
      group_by(ID_AGEB) |>
      summarise(
        !!census_den_col(g) := sum(POB_TOTAL[REP]),
        across(all_of(vars), ~ if (any(REP)) sum(.x[REP]) else NA_real_),
        .groups = "drop"
      )
  })

  # The ITER does publish counts of 1 and 2, so nothing here is imputed.
  out <- reduce(by_group, left_join, by = "ID_AGEB", .init = base) |>
    mutate(N_CELDAS_IMPUTADAS = 0)

  log_msg("  rural AGEB rows: ", nrow(out),
          " | population: ", format(sum(out$POB_TOTAL), big.mark = ","),
          " | in fully reporting localities: ",
          sprintf("%.2f%%", 100 * sum(out$POB_REPORTADA) / sum(out$POB_TOTAL)),
          " | AGEB with no reporting locality: ", sum(out$POB_REPORTADA == 0))
  saveRDS(out, interim_path("census_rural", ent))
  invisible(out)
}
