# 14_integrate.R -- one database per entity with every table of the pipeline.
#
# Up to 12_export.R the outputs of an entity are split by shape: the wide
# indicator CSV, the geometry in its own GeoPackage, and three long detail
# tables. This block puts them back together, one entity at a time, in a single
# GeoPackage -- an SQLite file that QGIS, R, Python and any SQL client open
# directly -- plus a flat CSV of its main layer for readers without GIS:
#
#   data/processed/base_ageb_{ENT}.gpkg
#     ageb_integrada          polygons, one row per AGEB: the 189 published
#                             indicator columns plus the wide DENUE and
#                             land-use blocks
#     denue_establishments    points, one row per DENUE establishment
#     denue_ageb_sector       AGEB x SCIAN sector (long)
#     ageb_landuse_detail     AGEB x land-use class (long)
#     diccionario_datos, data_dictionary   the dictionaries, so the file is
#                             self-describing
#
# Quality control is deliberately absent: it is how the build is checked, not
# part of what is handed over. It keeps its own quality_control_report_{ENT}.csv
# and qc_municipal_coverage_{ENT}.csv in data/processed for that.
#   data/processed/ageb_integrada_{ENT}.csv  the ageb_integrada layer, no geometry
#   data/processed/detail/{table}_{ENT}.csv  the three detail tables, flat, for
#                             readers without GIS
#
# There is no national version on purpose. The 32 entities in one GeoPackage
# come to ~1.4 GB, slow to open and awkward to move around, and the work that
# reads this database is done entity by entity. A national analysis reads the
# 32 ageb_integrada_{ENT}.csv and binds them.
#
# The wide blocks are the only new variables, and both are reshapes of detail
# the pipeline already computes, so no source is read here:
#
#  * DEN_SCIAN_*: establishments per SCIAN sector. DEN_MANUF, DEN_COM, ... are
#    overlapping views chosen for the index (DEN_EDU sits
#    inside DEN_SERV); these are the 20 official sectors, which partition
#    DENUE_TOT exactly and let the analyst build any other grouping.
#  * USV_PCT_*: the 183 USYV classes collapsed into 12 formations. The class
#    list is far too long to pivot, and a single USO_DOM hides that a rural
#    AGEB can be 45% agriculture and 40% secondary forest. Secondary
#    vegetation is kept apart from the formation it degrades, because
#    degradation is what the index cares about.
#
# An entity is rebuilt only when one of its own inputs is newer than its
# database, so `Rscript run_all.R 20` touches Oaxaca and leaves the other 31
# files alone.

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

integrated_gpkg <- function(ent) {
  file.path(DIR_PROCESSED, sprintf("base_ageb_%s.gpkg", ent))
}
integrated_csv <- function(ent) {
  file.path(DIR_PROCESSED, sprintf("ageb_integrada_%s.csv", ent))
}

# docs/diccionario_datos.csv (Spanish) and docs/data_dictionary.csv (English)
# document every published column. They are the same rows in the same order,
# the English one naming its key columns TABLE / ORDER, and table
# ageb_integrada must list this layer exactly: the 221 columns in layer order,
# then the geometry column that sf writes last. A column added without its
# dictionary row, or a row left behind after a column is dropped, stops the
# build, so neither dictionary can drift from the schema.
INTEGRATED_DOC_COLS <- c(INTEGRATED_COLUMNS, "geom")

check_integrated_dictionary <- function() {
  for (d in list(c("diccionario_datos.csv", "TABLA", "ORDEN"),
                 c("data_dictionary.csv", "TABLE", "ORDER"))) {
    path <- file.path(PROJECT_ROOT, "docs", d[1])
    if (!file.exists(path)) stop("data dictionary not found: ", path, call. = FALSE)
    dict <- read_csv(path, progress = FALSE,
                     col_types = cols(.default = col_character()))
    rows <- dict[dict[[d[2]]] == "ageb_integrada", ]

    undocumented <- setdiff(INTEGRATED_DOC_COLS, rows$VARIABLE)
    stale <- setdiff(rows$VARIABLE, INTEGRATED_DOC_COLS)
    if (length(undocumented) > 0 || length(stale) > 0) {
      stop("docs/", d[1], " is out of sync with the ageb_integrada layer",
           if (length(undocumented) > 0) paste0("; undocumented: ",
             paste(undocumented, collapse = ", ")),
           if (length(stale) > 0) paste0("; no longer published: ",
             paste(stale, collapse = ", ")), call. = FALSE)
    }
    if (!identical(rows$VARIABLE, INTEGRATED_DOC_COLS) ||
        !identical(as.integer(rows[[d[3]]]), seq_along(INTEGRATED_DOC_COLS))) {
      stop("docs/", d[1], ": table ageb_integrada lists the columns in a ",
           "different order than the layer", call. = FALSE)
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

# The tables the published database carries, in the order they are written.
INTEGRATED_LAYERS <- c("ageb_integrada", "denue_establishments",
                       "denue_ageb_sector", "ageb_landuse_detail")

# Everything the integrated database of one entity reads; if any of these is
# newer than the database, it is stale.
integrated_inputs <- function(ent) {
  c(interim_path("complete", ent),
    interim_path("denue_sector", ent),
    interim_path("denue_establishments", ent),
    interim_path("landuse_detail", ent),
    interim_path("ageb_geom", ent, "gpkg"),
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

build_integrated <- function(ent) {
  gpkg <- integrated_gpkg(ent)
  csv  <- integrated_csv(ent)

  inputs <- integrated_inputs(ent)
  if (file.exists(gpkg) && file.exists(csv) && all(file.exists(inputs)) &&
      all(file.mtime(inputs) < file.mtime(gpkg))) {
    log_msg("skip integrated database ", ent, " (already up to date)")
    return(invisible(gpkg))
  }
  log_step("integrated database ", ent)
  check_integrated_dictionary()

  ageb <- integrate_entity(ent)

  geom <- sf::st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    sf::st_transform(CRS_OUTPUT) |>
    select(ID_AGEB)
  if (nrow(geom) != nrow(ageb) || !setequal(geom$ID_AGEB, ageb$ID_AGEB)) {
    stop("integrated database ", ent, ": geometry and attributes cover ",
         "different AGEB (", nrow(geom), " polygons, ", nrow(ageb), " rows)",
         call. = FALSE)
  }
  ageb_sf <- geom |> left_join(ageb, by = "ID_AGEB") |>
    select(all_of(INTEGRATED_COLUMNS), everything())

  # Written under a temporary name and moved into place at the end, so an
  # interrupted run never leaves a half-written file where readers expect the
  # whole database.
  tmp <- sub("[.]gpkg$", ".partial.gpkg", gpkg)
  unlink(tmp)
  write_layer <- function(obj, layer) {
    sf::st_write(obj, tmp, layer = layer, driver = "GPKG", quiet = TRUE,
                 append = FALSE)
    log_msg("  ", layer, ": ", format(nrow(obj), big.mark = ","), " rows")
  }

  write_layer(ageb_sf, "ageb_integrada")

  # The detail tables go out twice: as a layer of the database, and as a flat
  # CSV in DIR_DETAIL so they can be read without GIS. Same rows either way --
  # dropping the geometry of the DENUE points leaves the LON/LAT columns they
  # were built from.
  write_detail <- function(obj, layer) {
    write_layer(obj, layer)
    write_csv(sf::st_drop_geometry(obj),
              file.path(DIR_DETAIL, sprintf("%s_%s.csv", layer, ent)), na = "")
  }

  # Establishments without a usable coordinate (07_denue.R clears those outside
  # the entity) are kept, as empty points: they still count toward their AGEB.
  est <- readRDS(interim_path("denue_establishments", ent))
  est_sf <- sf::st_as_sf(est |> mutate(X = coalesce(LON, 0), Y = coalesce(LAT, 0)),
                         coords = c("X", "Y"), crs = CRS_OUTPUT, remove = TRUE)
  no_xy <- is.na(est$LON) | is.na(est$LAT)
  sf::st_geometry(est_sf)[no_xy] <- sf::st_point()
  write_detail(est_sf, "denue_establishments")

  write_detail(readRDS(interim_path("denue_sector", ent)), "denue_ageb_sector")
  write_detail(readRDS(interim_path("landuse_detail", ent)), "ageb_landuse_detail")

  # Trimmed to the layers this file actually holds, so the embedded copy never
  # describes a table the reader does not have; docs/ keeps the full version,
  # which also covers the quality-control tables.
  for (d in c("diccionario_datos", "data_dictionary")) {
    dict <- read_csv(file.path(PROJECT_ROOT, "docs", paste0(d, ".csv")),
                     col_types = cols(.default = col_character()), progress = FALSE)
    write_layer(dict[dict[[1]] %in% INTEGRATED_LAYERS, ], d)
  }

  # On Windows the rename fails while another program (QGIS) holds the file.
  if (!file.rename(tmp, gpkg)) {
    stop("could not replace ", gpkg, "; close any program that has it open. ",
         "The new version is in ", tmp, call. = FALSE)
  }
  write_csv(ageb, csv, na = "")

  log_msg("  ", format(nrow(ageb), big.mark = ","), " AGEB x ",
          length(INTEGRATED_COLUMNS), " columns -> ", basename(gpkg),
          " and ", basename(csv))
  invisible(gpkg)
}
