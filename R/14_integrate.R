# 14_integrate.R -- one national database with every table of the pipeline.
#
# Up to 12_export.R the outputs are split two ways: by entity (32 files of
# each kind) and by shape (the wide indicator CSV, the geometry in its own
# GeoPackage, and three long detail tables). This block puts them together in
# a single GeoPackage -- an SQLite file that QGIS, R, Python and any SQL client
# open directly -- plus a flat CSV of its main layer for readers without GIS:
#
#   data/processed/base_ageb_MX.gpkg
#     ageb_integrada          polygons, one row per AGEB: every ageb_indicadores
#                             column plus the wide DENUE and land-use blocks
#     denue_establishments    points, one row per DENUE establishment
#     denue_ageb_sector       AGEB x SCIAN sector (long)
#     ageb_landuse_detail     AGEB x land-use class (long)
#     quality_control_report  every check of every entity
#     diccionario_datos, data_dictionary   the dictionaries, so the file is
#                             self-describing
#   data/processed/ageb_integrada_MX.csv   the ageb_integrada layer, no geometry
#
# The wide blocks are the only new variables, and both are reshapes of detail
# the pipeline already computes, so no source is read here:
#
#  * DEN_SCIAN_*: establishments per SCIAN sector. DEN_MANUF, DEN_COM, ... in
#    ageb_indicadores are overlapping views chosen for the index (DEN_EDU sits
#    inside DEN_SERV); these are the 20 official sectors, which partition
#    DENUE_TOT exactly and let the analyst build any other grouping.
#  * USV_PCT_*: the 183 USYV classes collapsed into 12 formations. The class
#    list is far too long to pivot, and a single USO_DOM hides that a rural
#    AGEB can be 45% agriculture and 40% secondary forest. Secondary
#    vegetation is kept apart from the formation it degrades, because
#    degradation is what the index cares about.
#
# The integrated file is rebuilt from whatever entities are on disk, never just
# the ones of the current run, so `Rscript run_all.R 20` refreshes Oaxaca inside
# the national file instead of replacing the nation by Oaxaca.

suppressPackageStartupMessages(library(sf))

# Official SCIAN 2023 sectors. Manufacturing (31-33) and transport (48-49) are
# single sectors spread over several two-digit codes.
SCIAN_SECTOR_COLS <- list(
  DEN_SCIAN_11    = "11", DEN_SCIAN_21 = "21", DEN_SCIAN_22 = "22",
  DEN_SCIAN_23    = "23", DEN_SCIAN_31_33 = c("31", "32", "33"),
  DEN_SCIAN_43    = "43", DEN_SCIAN_46 = "46", DEN_SCIAN_48_49 = c("48", "49"),
  DEN_SCIAN_51    = "51", DEN_SCIAN_52 = "52", DEN_SCIAN_53 = "53",
  DEN_SCIAN_54    = "54", DEN_SCIAN_55 = "55", DEN_SCIAN_56 = "56",
  DEN_SCIAN_61    = "61", DEN_SCIAN_62 = "62", DEN_SCIAN_71 = "71",
  DEN_SCIAN_72    = "72", DEN_SCIAN_81 = "81", DEN_SCIAN_93 = "93"
)
stopifnot(!anyDuplicated(unlist(SCIAN_SECTOR_COLS)))

# USYV class -> formation, first match wins, so the order matters: secondary
# vegetation is tested before the formation it names ("VEGETACION SECUNDARIA
# ARBUSTIVA DE BOSQUE DE PINO" must not land in USV_PCT_BOSQUE), and induced
# grassland before natural grassland. A class matching nothing stops the run:
# a new label upstream would otherwise vanish from every share without a trace.
USV_GROUPS <- c(
  USV_PCT_URBANO      = URBAN_CLASS_PATTERN,
  USV_PCT_AGUA        = "^CUERPO DE AGUA|^ACU[I\u00cd]COLA",
  USV_PCT_SECUNDARIA  = "^VEGETACI[O\u00d3]N SECUNDARIA",
  USV_PCT_AGRICOLA    = "^AGRICULTURA",
  USV_PCT_PASTIZAL_INDUCIDO = "^PASTIZAL (CULTIVADO|INDUCIDO)",
  USV_PCT_BOSQUE      = "^BOSQUE",
  USV_PCT_SELVA       = "^SELVA",
  USV_PCT_MATORRAL    = "^MATORRAL|^MEZQUITAL|^CHAPARRAL|DESIERTOS ARENOSOS|GIPS[O\u00d3]FILA|HAL[O\u00d3]FILA XER[O\u00d3]FILA",
  USV_PCT_PASTIZAL    = "^PASTIZAL|^PRADERA|^SABANA|^SABANOIDE",
  USV_PCT_HIDROFILA   = "^MANGLAR|^TULAR|^POPAL|HIDR[O\u00d3]FILA|GALER[I\u00cd]A|PET[E\u00c9]N",
  USV_PCT_SIN_VEG     = "SIN VEGETACI[O\u00d3]N|^DESPROVISTO",
  USV_PCT_OTRA        = "DUNAS COSTERAS|^PALMAR"
)

# Where the new blocks sit in the integrated table: each next to the summary
# it breaks down.
INTEGRATED_COLUMNS <- local({
  cols <- append(CSV_COLUMNS, names(SCIAN_SECTOR_COLS),
                 after = match("SCHOOL_TOT", CSV_COLUMNS))
  append(cols, names(USV_GROUPS), after = match("PCT_URB", cols))
})
INTEGRATED_EXTRA_COLS <- setdiff(INTEGRATED_COLUMNS, CSV_COLUMNS)

# Classes of one AGEB can overlap by slivers in the USYV layer, so the shares
# may sum to a hair over 100; more than this means a class was counted twice.
USV_SUM_TOL_PCT <- 1

INTEGRATED_GPKG <- file.path(DIR_PROCESSED, "base_ageb_MX.gpkg")
INTEGRATED_CSV  <- file.path(DIR_PROCESSED, "ageb_integrada_MX.csv")

# The dictionaries document the new columns as table ageb_integrada, in the
# order and position they take in the layer; the ageb_indicadores rows already
# cover the rest. Same contract as check_dictionary() in 12_export.R.
check_integrated_dictionary <- function() {
  for (d in list(c("diccionario_datos.csv", "TABLA", "ORDEN"),
                 c("data_dictionary.csv", "TABLE", "ORDER"))) {
    dict <- read_csv(file.path(PROJECT_ROOT, "docs", d[1]), progress = FALSE,
                     col_types = cols(.default = col_character()))
    rows <- dict[dict[[d[2]]] == "ageb_integrada", ]
    if (!identical(rows$VARIABLE, INTEGRATED_EXTRA_COLS) ||
        !identical(as.integer(rows[[d[3]]]),
                   match(INTEGRATED_EXTRA_COLS, INTEGRATED_COLUMNS))) {
      stop("docs/", d[1], ": table ageb_integrada must list ",
           paste(INTEGRATED_EXTRA_COLS, collapse = ", "),
           " with their positions in INTEGRATED_COLUMNS", call. = FALSE)
    }
  }
  invisible(TRUE)
}

# AGEB x sector counts, wide. AGEB with no establishment get 0 in every sector,
# as DENUE_TOT does.
integrate_denue_sectors <- function(sector_long, ids) {
  unknown <- setdiff(sector_long$SECTOR, unlist(SCIAN_SECTOR_COLS))
  if (length(unknown) > 0) {
    stop("DENUE sector code(s) outside SCIAN_SECTOR_COLS: ",
         paste(sQuote(unknown), collapse = ", "), call. = FALSE)
  }
  code_to_col <- setNames(rep(names(SCIAN_SECTOR_COLS), lengths(SCIAN_SECTOR_COLS)),
                          unlist(SCIAN_SECTOR_COLS))
  wide <- sector_long |>
    mutate(COL = factor(code_to_col[SECTOR], levels = names(SCIAN_SECTOR_COLS))) |>
    count(ID_AGEB, COL, wt = N_UNITS, name = "N", .drop = FALSE) |>
    tidyr::pivot_wider(names_from = COL, values_from = N, values_fill = 0L)
  tibble(ID_AGEB = ids) |>
    left_join(wide, by = "ID_AGEB") |>
    mutate(across(all_of(names(SCIAN_SECTOR_COLS)), ~ as.integer(coalesce(.x, 0L))))
}

usv_group_of <- function(classes) {
  folded <- toupper(classes)
  group <- rep(NA_character_, length(folded))
  for (g in names(USV_GROUPS)) {
    hit <- is.na(group) & grepl(USV_GROUPS[[g]], folded)
    group[hit] <- g
  }
  unmatched <- unique(classes[is.na(group)])
  if (length(unmatched) > 0) {
    stop("land-use class(es) with no USV_GROUPS formation: ",
         paste(sQuote(unmatched), collapse = ", "), call. = FALSE)
  }
  group
}

# Share of the AGEB in each formation. NA where the AGEB has no USYV polygon at
# all (same rule as USO_DOM); 0 where it has classes, just none of this group.
integrate_landuse_groups <- function(detail, ids) {
  wide <- detail |>
    mutate(GROUP = factor(usv_group_of(USO_CLASE), levels = names(USV_GROUPS))) |>
    group_by(ID_AGEB, GROUP, .drop = FALSE) |>
    summarise(PCT = pmin(100, sum(CLASS_PCT)), .groups = "drop") |>
    tidyr::pivot_wider(names_from = GROUP, values_from = PCT, values_fill = 0)
  tibble(ID_AGEB = ids) |>
    left_join(wide, by = "ID_AGEB") |>
    mutate(across(all_of(names(USV_GROUPS)), ~ round(.x, 2)))
}

# Every entity whose assembled table exists, whether or not it ran this time.
integrated_entities <- function() {
  ENTITIES[file.exists(vapply(ENTITIES, \(e) interim_path("complete", e), ""))]
}

# The inputs of one entity that the integrated database reads.
integrated_inputs <- function(ents) {
  c(vapply(ents, \(e) interim_path("complete", e), ""),
    vapply(ents, \(e) interim_path("denue_sector", e), ""),
    vapply(ents, \(e) interim_path("denue_establishments", e), ""),
    vapply(ents, \(e) interim_path("landuse_detail", e), ""),
    vapply(ents, \(e) interim_path("ageb_geom", e, "gpkg"), ""),
    file.path(DIR_PROCESSED, sprintf("quality_control_report_%s.csv", ents)),
    file.path(PROJECT_ROOT, "docs", c("diccionario_datos.csv", "data_dictionary.csv")))
}

integrate_entity <- function(ent) {
  tbl <- published_table(ent)
  ids <- tbl$ID_AGEB

  sectors <- integrate_denue_sectors(readRDS(interim_path("denue_sector", ent)), ids)
  landuse <- integrate_landuse_groups(readRDS(interim_path("landuse_detail", ent)), ids)

  out <- tbl |>
    left_join(sectors, by = "ID_AGEB") |>
    left_join(landuse, by = "ID_AGEB") |>
    select(all_of(INTEGRATED_COLUMNS))

  # The sectors must add back to the published total, AGEB by AGEB; a gap means
  # establishments whose sector code the partition does not know.
  sector_sum <- rowSums(as.matrix(out[names(SCIAN_SECTOR_COLS)]))
  if (any(sector_sum != out$DENUE_TOT)) {
    stop("entity ", ent, ": DEN_SCIAN_* do not add up to DENUE_TOT in ",
         sum(sector_sum != out$DENUE_TOT), " AGEB", call. = FALSE)
  }
  usv_sum <- rowSums(as.matrix(out[names(USV_GROUPS)]))
  over <- which(usv_sum > 100 + USV_SUM_TOL_PCT)
  if (length(over) > 0) {
    stop("entity ", ent, ": USV_PCT_* add up to more than 100 in ", length(over),
         " AGEB (max ", round(max(usv_sum[over]), 2), ")", call. = FALSE)
  }
  if (!identical(is.na(out$USV_PCT_URBANO), is.na(out$USO_DOM))) {
    stop("entity ", ent, ": USV_PCT_* and USO_DOM disagree on which AGEB have ",
         "land-use data", call. = FALSE)
  }
  out
}

build_integrated <- function() {
  ents <- integrated_entities()
  if (length(ents) == 0) {
    log_msg("integrated database: no assembled entity on disk, nothing to do")
    return(invisible(NULL))
  }
  inputs <- integrated_inputs(ents)
  if (file.exists(INTEGRATED_GPKG) && file.exists(INTEGRATED_CSV) &&
      all(file.exists(inputs)) &&
      all(file.mtime(inputs) < file.mtime(INTEGRATED_GPKG))) {
    log_msg("skip integrated database (up to date with ", length(ents), " entities)")
    return(invisible(INTEGRATED_GPKG))
  }

  log_step("integrated database -- ", length(ents), " entit",
           if (length(ents) == 1) "y" else "ies")
  missing_ents <- setdiff(ENTITIES, ents)
  if (length(missing_ents) > 0) {
    log_msg("  !! not yet assembled, left out: ", paste(missing_ents, collapse = ", "))
  }
  check_dictionary()
  check_integrated_dictionary()

  ageb <- map_dfr(ents, integrate_entity)
  if (anyDuplicated(ageb$ID_AGEB)) {
    stop("integrated database: repeated ID_AGEB across entities", call. = FALSE)
  }

  geom <- map_dfr(ents, \(e) {
    sf::st_read(interim_path("ageb_geom", e, "gpkg"), quiet = TRUE) |>
      sf::st_transform(CRS_OUTPUT) |>
      select(ID_AGEB)
  })
  if (nrow(geom) != nrow(ageb) || !setequal(geom$ID_AGEB, ageb$ID_AGEB)) {
    stop("integrated database: geometry and attributes cover different AGEB ",
         "(", nrow(geom), " polygons, ", nrow(ageb), " rows)", call. = FALSE)
  }
  ageb_sf <- geom |> left_join(ageb, by = "ID_AGEB") |>
    select(all_of(INTEGRATED_COLUMNS), everything())

  # Written under a temporary name and moved into place at the end, so an
  # interrupted run never leaves a half-written file where readers expect the
  # whole database.
  tmp <- sub("[.]gpkg$", ".partial.gpkg", INTEGRATED_GPKG)
  unlink(tmp)
  write_layer <- function(obj, layer) {
    sf::st_write(obj, tmp, layer = layer, driver = "GPKG", quiet = TRUE,
                 append = FALSE)
    log_msg("  ", layer, ": ", format(nrow(obj), big.mark = ","), " rows")
  }

  write_layer(ageb_sf, "ageb_integrada")

  # Establishments without a usable coordinate (07_denue.R clears those outside
  # the entity) are kept, as empty points: they still count toward their AGEB.
  est <- map_dfr(ents, \(e) readRDS(interim_path("denue_establishments", e)))
  est_sf <- sf::st_as_sf(est |> mutate(X = coalesce(LON, 0), Y = coalesce(LAT, 0)),
                         coords = c("X", "Y"), crs = CRS_OUTPUT, remove = TRUE)
  no_xy <- is.na(est$LON) | is.na(est$LAT)
  sf::st_geometry(est_sf)[no_xy] <- sf::st_point()
  write_layer(est_sf, "denue_establishments")

  write_layer(map_dfr(ents, \(e) readRDS(interim_path("denue_sector", e))),
              "denue_ageb_sector")
  write_layer(map_dfr(ents, \(e) readRDS(interim_path("landuse_detail", e))),
              "ageb_landuse_detail")

  qc_paths <- file.path(DIR_PROCESSED, sprintf("quality_control_report_%s.csv", ents))
  write_layer(map_dfr(qc_paths[file.exists(qc_paths)], read_csv,
                      col_types = cols(.default = col_character()), progress = FALSE),
              "quality_control_report")

  for (d in c("diccionario_datos", "data_dictionary")) {
    write_layer(read_csv(file.path(PROJECT_ROOT, "docs", paste0(d, ".csv")),
                         col_types = cols(.default = col_character()), progress = FALSE),
                d)
  }

  # On Windows the rename fails while another program (QGIS) holds the file.
  if (!file.rename(tmp, INTEGRATED_GPKG)) {
    stop("could not replace ", INTEGRATED_GPKG, "; close any program that has ",
         "it open. The new version is in ", tmp, call. = FALSE)
  }
  write_csv(ageb, INTEGRATED_CSV, na = "")

  log_msg("  ", format(nrow(ageb), big.mark = ","), " AGEB x ",
          length(INTEGRATED_COLUMNS), " columns -> ", basename(INTEGRATED_GPKG),
          " and ", basename(INTEGRATED_CSV))
  invisible(INTEGRATED_GPKG)
}
