# 14_integrate.R -- one database per entity with every table of the pipeline.
#
# Up to 12_export.R the outputs of an entity are split by shape: the wide
# indicator CSV, the geometry in its own GeoPackage, and three long detail
# tables. This block puts them back together, one entity at a time, in a single
# GeoPackage -- an SQLite file that QGIS, R, Python and any SQL client open
# directly -- plus a flat CSV of its main layer for readers without GIS:
#
#   data/processed/base_ageb_{ENT}.gpkg
#     ageb_integrada          polygons, one row per AGEB: ID_AGEB plus the
#                             published indicators, including the wide DENUE
#                             and land-use blocks
#     denue_establishments    points, one row per DENUE establishment
#     denue_ageb_sector       AGEB x SCIAN sector (long)
#     ageb_landuse_detail     AGEB x land-use class (long)
#     diccionario_datos, data_dictionary   the dictionaries, so the file is
#                             self-describing
#
# ID_AGEB is the key of every table and the only identifier any of them carries.
# Which entity, municipality or locality an AGEB belongs to, and how large it
# is, is stated in exactly one place -- data/processed/ageb_ids.csv, one file
# for the whole country -- and read from there by joining on ID_AGEB. Nothing
# else repeats it, including the state databases: a copy of the ID table in
# each of the 32 would be the same 32 answers to a question with one answer,
# and the first thing to go stale after a name is corrected.
#
# So a query that needs a municipality name joins ageb_ids, and a correction to
# that name is made once. The cost is that base_ageb_{ENT}.gpkg on its own can
# map any indicator but cannot label it with a municipality; the reader is told
# where the names are by the dictionary the file carries.
#
# Quality control is deliberately absent: it is how the build is checked, not
# part of what is handed over. It keeps its own quality_control_report_{ENT}.csv
# and qc_municipal_coverage_{ENT}.csv in data/processed for that.
#   data/processed/ageb_integrada_{ENT}.csv  the ageb_integrada layer, no geometry
#   data/processed/detail/{table}_{ENT}.csv  the three detail tables, flat, for
#                             readers without GIS
#   data/processed/ageb_ids.csv  the ID table, for the whole country and written
#                             once: the single file every table keyed by
#                             ID_AGEB alone is joined against. Splitting it by
#                             entity, or copying it into each database, would
#                             put the same rows in 32 places; at twelve narrow
#                             columns the whole country is a few megabytes
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

# What ageb_integrada actually carries: the key and the measurements. The other
# eleven ID_COLUMNS live in ageb_ids, one row per AGEB, instead of being
# repeated on every table that mentions an AGEB.
INDICATOR_COLUMNS <- c("ID_AGEB", setdiff(INTEGRATED_COLUMNS, ID_COLUMNS))

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
# the English one naming its key columns TABLE / ORDER, and each of them must
# list every layer exactly: its columns in layer order, then the geometry
# column, which sf names geom on the way into the GeoPackage. A column added
# without its dictionary row, or a row left behind after a column is dropped,
# stops the build, so neither dictionary can drift from the schema.
#
# Every layer is checked as it is written rather than the wide one alone, so
# moving a column between tables cannot pass unnoticed in either direction.
read_dictionaries <- function() {
  lapply(list(c("diccionario_datos.csv", "TABLA", "ORDEN"),
              c("data_dictionary.csv", "TABLE", "ORDER")), function(d) {
    path <- file.path(PROJECT_ROOT, "docs", d[1])
    if (!file.exists(path)) stop("data dictionary not found: ", path, call. = FALSE)
    list(name = d[1], table = d[2], order = d[3],
         rows = read_csv(path, progress = FALSE,
                         col_types = cols(.default = col_character())))
  })
}

layer_columns <- function(obj) {
  if (inherits(obj, "sf")) {
    c(setdiff(names(obj), attr(obj, "sf_column")), "geom")
  } else {
    names(obj)
  }
}

check_layer_dictionary <- function(dicts, layer, cols) {
  for (d in dicts) {
    rows <- d$rows[d$rows[[d$table]] == layer, ]
    if (nrow(rows) == 0) {
      stop("docs/", d$name, " documents no table called ", layer, call. = FALSE)
    }
    undocumented <- setdiff(cols, rows$VARIABLE)
    stale <- setdiff(rows$VARIABLE, cols)
    if (length(undocumented) > 0 || length(stale) > 0) {
      stop("docs/", d$name, " is out of sync with the ", layer, " layer",
           if (length(undocumented) > 0) paste0("; undocumented: ",
             paste(undocumented, collapse = ", ")),
           if (length(stale) > 0) paste0("; no longer published: ",
             paste(stale, collapse = ", ")), call. = FALSE)
    }
    if (!identical(rows$VARIABLE, cols) ||
        !identical(as.integer(rows[[d$order]]), seq_along(cols))) {
      stop("docs/", d$name, ": table ", layer, " lists the columns in a ",
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

# What the dictionary embedded in each database describes: its own layers, plus
# ageb_ids. That table is not in the file -- it is national, written once -- but
# a reader holding only base_ageb_20.gpkg has to be able to find out that the
# municipality names exist and where, so it is documented here rather than left
# to be guessed from a column that is missing.
DOCUMENTED_LAYERS <- c("ageb_ids", INTEGRATED_LAYERS)

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
  dicts <- read_dictionaries()

  # Only what was measured: who the AGEB is went to the national ageb_ids, built
  # from this same published table by build_ids_national().
  ageb <- integrate_entity(ent) |> select(all_of(INDICATOR_COLUMNS))

  geom <- sf::st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    sf::st_transform(CRS_OUTPUT) |>
    select(ID_AGEB)
  if (nrow(geom) != nrow(ageb) || !setequal(geom$ID_AGEB, ageb$ID_AGEB)) {
    stop("integrated database ", ent, ": geometry and attributes cover ",
         "different AGEB (", nrow(geom), " polygons, ", nrow(ageb), " rows)",
         call. = FALSE)
  }
  ageb_sf <- geom |> left_join(ageb, by = "ID_AGEB") |>
    select(all_of(INDICATOR_COLUMNS), everything())

  # Written under a temporary name and moved into place at the end, so an
  # interrupted run never leaves a half-written file where readers expect the
  # whole database.
  tmp <- sub("[.]gpkg$", ".partial.gpkg", gpkg)
  unlink(tmp)
  write_layer <- function(obj, layer, check = TRUE) {
    if (check) check_layer_dictionary(dicts, layer, layer_columns(obj))
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

  # AREA_KM2 -- the area of the whole AGEB, repeated on each of its land-use
  # classes -- is dropped here: it is the AGEB's, not the class's, so it belongs
  # to ageb_ids. CLASS_PCT already carries the ratio the column was there for.
  write_detail(readRDS(interim_path("landuse_detail", ent)) |>
                 select(-any_of("AREA_KM2")), "ageb_landuse_detail")

  # Trimmed to the layers this file actually holds, so the embedded copy never
  # describes a table the reader does not have.
  for (d in c("diccionario_datos", "data_dictionary")) {
    dict <- read_csv(file.path(PROJECT_ROOT, "docs", paste0(d, ".csv")),
                     col_types = cols(.default = col_character()), progress = FALSE)
    write_layer(dict[dict[[1]] %in% DOCUMENTED_LAYERS, ], d, check = FALSE)
  }

  # On Windows the rename fails while another program (QGIS) holds the file.
  if (!file.rename(tmp, gpkg)) {
    stop("could not replace ", gpkg, "; close any program that has it open. ",
         "The new version is in ", tmp, call. = FALSE)
  }
  write_csv(ageb, csv, na = "")

  log_msg("  ", format(nrow(ageb), big.mark = ","), " AGEB x ",
          length(INDICATOR_COLUMNS), " columns -> ", basename(gpkg),
          " and ", basename(csv))
  invisible(gpkg)
}

# The ID table: national, and the only copy. Every other table is keyed by
# ID_AGEB alone, and what you join to resolve that key should be one file rather
# than something you first assemble out of 32.
#
# Built from the same published tables the databases are built from, so it says
# the same thing they do; an entity whose interim table is missing is skipped
# and the log says how many went in.
build_ids_national <- function(ents) {
  have <- ents[file.exists(interim_path("complete", ents))]
  if (length(have) == 0) {
    log_msg("national ID table skipped: no entity is built")
    return(invisible(NULL))
  }
  ids <- map_dfr(have, ids_table) |> arrange(ID_AGEB)
  if (anyDuplicated(ids$ID_AGEB) > 0) {
    stop("national ID table: ID_AGEB is not unique across entities (",
         sum(duplicated(ids$ID_AGEB)), " repeated)", call. = FALSE)
  }
  check_layer_dictionary(read_dictionaries(), "ageb_ids", names(ids))
  out <- file.path(DIR_PROCESSED, "ageb_ids.csv")
  write_csv(ids, out, na = "")
  log_step("national ID table: ", format(nrow(ids), big.mark = ","), " AGEB from ",
           length(have), " entities -> ", basename(out))
  invisible(out)
}
