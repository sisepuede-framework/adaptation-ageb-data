# 07_denue.R -- economic units from DENUE, per AGEB, plus the school proxy.
#
# DENUE carries its own cve_ent/cve_mun/cve_loc/ageb fields, so establishments
# are assigned by key rather than by spatial join, and the product covers urban
# and rural AGEB alike (spec section 5.4).
#
# Two details that bite:
#  * the file is latin-1, and the archive also contains a data dictionary CSV
#    that must not be read as data;
#  * per_ocu is a size stratum ("0 a 5 personas"), not a headcount, so it is
#    never summed.
#
# DEN_EDU (61) is a subset of DEN_SERV (48-81) and SCHOOL_TOT (611) a subset of
# DEN_EDU; the spec defines them as overlapping views, so they are not additive.

SCIAN_SECTORS <- list(
  DEN_MANUF = as.character(31:33),
  DEN_COM   = c("43", "46"),
  DEN_SERV  = as.character(48:81),
  DEN_EDU   = "61",
  DEN_GOB   = "93"
)

build_denue <- function(ent) {
  log_step("DENUE ", ent)
  # Explicitly the conjunto_de_datos files: the dictionary CSV sits in a sibling
  # folder and matches a looser pattern. Large entities ship in several parts
  # (entity 15), each extracted under denue/partN/, so every match is read and
  # stacked.
  root <- file.path(DIR_RAW, ent, "denue")
  rel <- list.files(root, recursive = TRUE)
  rel <- rel[grepl("conjunto_de_datos/denue_.*\\.csv$", rel, ignore.case = TRUE)]
  if (length(rel) == 0) stop("no DENUE data file under ", root, call. = FALSE)
  if (length(rel) > 1) log_msg("  reading ", length(rel), " DENUE parts")

  raw <- map_dfr(file.path(root, rel), read_latin1_csv)

  spine_all <- readRDS(interim_path("ageb_attrs", ent))
  urban_spine <- spine_all$ID_AGEB[spine_all$AMBITO == "Urbana"]
  rural_spine <- spine_all$ID_AGEB[spine_all$AMBITO == "Rural"]

  # DENUE always reports the real locality, but rural AGEB have no CVE_LOC and
  # this database stores them with CVE_LOC = "0000". So the key is resolved in
  # two passes: try the urban form first, then fall back to the rural form.
  # Without this, every rural establishment misses the spine (~4% of records).
  id_urban <- build_ageb_id(raw$cve_ent, raw$cve_mun, raw$cve_loc, raw$ageb)
  id_rural <- build_ageb_id(raw$cve_ent, raw$cve_mun, "0000", raw$ageb)
  resolved <- ifelse(id_urban %in% urban_spine, id_urban,
                     ifelse(id_rural %in% rural_spine, id_rural, id_urban))

  est <- raw |>
    transmute(
      ID_AGEB = resolved,
      NOM_ESTAB = nom_estab,
      SCIAN = codigo_act,
      SECTOR = substr(codigo_act, 1, 2),
      PER_OCU_STRATUM = per_ocu,
      LON = suppressWarnings(as.numeric(longitud)),
      LAT = suppressWarnings(as.numeric(latitud))
    )

  # Drop coordinates outside the entity envelope. Only the coordinate is
  # cleared; the establishment still counts, because its AGEB key is what the
  # aggregation uses.
  bb <- entity_bbox_4326(ent)
  bad <- !is.na(est$LON) &
    (est$LON < bb["xmin"] | est$LON > bb["xmax"] |
     est$LAT < bb["ymin"] | est$LAT > bb["ymax"])
  if (any(bad)) {
    log_msg("  coordinates outside the entity envelope: ", sum(bad), " (cleared)")
    est$LON[bad] <- NA_real_
    est$LAT[bad] <- NA_real_
  }

  off_spine <- sum(!est$ID_AGEB %in% spine_all$ID_AGEB)
  if (off_spine > 0) {
    log_msg("  establishments whose AGEB key is absent from the MG: ", off_spine)
  }

  summary_tbl <- est |>
    group_by(ID_AGEB) |>
    summarise(
      DENUE_TOT = n(),
      !!!lapply(SCIAN_SECTORS, function(codes) {
        rlang::expr(sum(SECTOR %in% !!codes))
      }),
      SCHOOL_TOT = sum(substr(SCIAN, 1, 3) == "611"),
      .groups = "drop"
    )

  # Long AGEB x sector detail, exported separately by 12_export.R.
  sector_tbl <- est |> count(ID_AGEB, SECTOR, name = "N_UNITS")

  log_msg("  establishments: ", format(nrow(est), big.mark = ","),
          " in ", nrow(summary_tbl), " AGEB | schools: ",
          format(sum(summary_tbl$SCHOOL_TOT), big.mark = ","))

  saveRDS(summary_tbl, interim_path("denue", ent))
  saveRDS(sector_tbl, interim_path("denue_sector", ent))
  saveRDS(est, interim_path("denue_establishments", ent))
  invisible(summary_tbl)
}
