# 02_download.R -- fetch every source into data/raw/ and extract it.
# Idempotent: an already-cached, non-empty, non-HTML file is left alone.

# Large national layers, fetched once and later read per-entity with a bbox.
download_national <- function() {
  log_step("national sources")
  nat <- list(
    coneval_grs = list(url = URL_CONEVAL_GRS, zip = "GRS_AGEB_urbana_2020.zip"),
    municipios  = list(url = URL_MUNICIPIOS,  zip = "mun22gw.zip"),
    water       = list(url = URL_WATER,       zip = "catp50s3gw.zip"),
    landuse     = list(url = URL_LANDUSE,     zip = "usv250s7gw.zip")
  )
  for (nm in names(nat)) {
    zip_path <- file.path(DIR_RAW, "national", nat[[nm]]$zip)
    download_cached(nat[[nm]]$url, zip_path)
    unzip_cached(zip_path, file.path(DIR_RAW, "national", nm))
  }
  # A bare workbook, not an archive.
  download_cached(URL_CLUES, file.path(DIR_RAW, "national", "clues", CLUES_FILE))

  coast_zip <- file.path(DIR_RAW, "national", "lc2018gw.zip")
  download_cached(URL_COAST, coast_zip)
  unzip_cached(coast_zip, file.path(DIR_RAW, "national", "coast"))

  for (upc in RED_HIDRO_UPCS) {
    zip_path <- file.path(DIR_RAW, "national", "red_hidro", sprintf("%s_s.zip", upc))
    download_cached(url_red_hidro(upc), zip_path)
    unzip_cached(zip_path, file.path(DIR_RAW, "national", "red_hidro", upc))
  }

  # Every entity's elevation model, not just the one being processed: slope
  # and stream-bed elevations near a state line read the neighbour's cells.
  for (ent in ENTITIES) {
    zip_path <- file.path(DIR_RAW, ent, sprintf("cem_%s.zip", ent))
    download_cached(url_cem(ent), zip_path)
    unzip_cached(zip_path, file.path(DIR_RAW, ent, "cem"))
  }

  # One small WFS query per CENAPRED hazard layer instead of 15 GeoPackages
  # that would differ in a single column; 13_hazard.R explains why.
  download_hazard()
  invisible(TRUE)
}

# Per-entity sources: geometry, urban census, ITER and DENUE.
download_entity <- function(ent) {
  log_step("entity ", ent, " (", ENTITY_NAMES[[ent]], ") sources")
  ent_dir <- file.path(DIR_RAW, ent)
  srcs <- list(
    marcogeo     = list(url = url_marco_geo(ent),    zip = sprintf("marcogeo_%s.zip", ent)),
    census_urban = list(url = url_census_urban(ent), zip = sprintf("census_urban_%s.zip", ent)),
    iter         = list(url = url_iter(ent),         zip = sprintf("iter_%s.zip", ent))
  )
  for (nm in names(srcs)) {
    zip_path <- file.path(ent_dir, srcs[[nm]]$zip)
    download_cached(srcs[[nm]]$url, zip_path)
    unzip_cached(zip_path, file.path(ent_dir, nm))
  }
  download_denue(ent, ent_dir)
  invisible(ent_dir)
}

# DENUE arrives either as one file or, for the largest entities, as numbered
# parts. Each part is extracted into its own folder under denue/, and
# 07_denue.R reads every conjunto_de_datos CSV it finds there.
download_denue <- function(ent, ent_dir) {
  single <- file.path(ent_dir, sprintf("denue_%s.zip", ent))
  if (file.exists(single) || url_is_data(url_denue(ent))) {
    download_cached(url_denue(ent), single)
    unzip_cached(single, file.path(ent_dir, "denue", "part1"))
    return(invisible(TRUE))
  }

  found <- 0L
  for (part in seq_len(DENUE_MAX_PARTS)) {
    zip_path <- file.path(ent_dir, sprintf("denue_%s_%d.zip", ent, part))
    if (!file.exists(zip_path) && !url_is_data(url_denue_part(ent, part))) break
    download_cached(url_denue_part(ent, part), zip_path)
    unzip_cached(zip_path, file.path(ent_dir, "denue", sprintf("part%d", part)))
    found <- found + 1L
  }
  if (found == 0L) {
    stop("no DENUE file found for entity ", ent, call. = FALSE)
  }
  log_msg("  DENUE delivered in ", found, " part(s)")
  invisible(TRUE)
}
