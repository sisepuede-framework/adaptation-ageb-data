# 12_export.R -- final CSV (spec section 7 column order) and GeoPackage.

# Census counts published after the headline indicators, for re-aggregation to
# other geographies. The six excluded here already appear earlier in the schema.
CENSUS_COUNT_COLS <- setdiff(
  names(CENSUS_VARS),
  c("POB_TOTAL", "POB_HOMBRES", "POB_MUJERES", "VIV_PART_HAB", "VIV_DRENAJE",
    "VIV_ELECTRICIDAD"))

# Declared in order rather than derived from the data, so the published schema
# is stable and a missing upstream column fails loudly instead of vanishing.
# The census catalogs it draws on live in 04_census_urban.R and 10_build.R.
CSV_COLUMNS <- c(
  "ID_AGEB", "AMBITO", "CVE_ENT", "NOM_ENT", "CVE_MUN", "NOM_MUN",
  "CVE_LOC", "NOM_LOC", "CVE_AGEB", "AREA_KM2", "CENTROIDE_LON", "CENTROIDE_LAT",
  "POB_TOTAL", "POB_REPORTADA", "PCT_POB_REPORTADA", "N_CELDAS_IMPUTADAS",
  "POB_HOMBRES", "POB_MUJERES", "PCT_HOMBRES", "PCT_MUJERES",
  "DENS_POB_KM2", "POB_POR_VIV",
  "VIV_PART_HAB", "VIV_CARACT", "VIV_DRENAJE", "VIV_ELECTRICIDAD",
  "PCT_DRENAJE", "PCT_ELECTRIC",
  CENSUS_SHARE_COLS, CENSUS_AVG_COLS,
  "GRS_GRADO", "GRS_NUM", RZ_NAMES,
  "DENUE_TOT", "DEN_MANUF", "DEN_COM", "DEN_SERV", "DEN_EDU", "DEN_GOB", "SCHOOL_TOT",
  "WATER_AREA", "WATER_PCT", "HAS_WATER",
  "USO_DOM", "USO_PCT", "PCT_URB",
  CENSUS_COUNT_COLS,
  "YEAR_GEOMETRY", "YEAR_CENSUS", "YEAR_CONEVAL", "YEAR_DENUE", "YEAR_HIDRO", "YEAR_USV"
)

# Rounded on export only; the interim tables keep full precision.
ROUND_DIGITS <- c(
  AREA_KM2 = 6, CENTROIDE_LON = 6, CENTROIDE_LAT = 6,
  PCT_POB_REPORTADA = 2, PCT_HOMBRES = 2, PCT_MUJERES = 2,
  DENS_POB_KM2 = 2, POB_POR_VIV = 2,
  PCT_DRENAJE = 2, PCT_ELECTRIC = 2,
  WATER_AREA = 6, WATER_PCT = 2, USO_PCT = 2, PCT_URB = 2,
  setNames(rep(2, length(CENSUS_SHARE_COLS) + length(CENSUS_AVG_COLS)),
           c(CENSUS_SHARE_COLS, CENSUS_AVG_COLS))
)

export_entity <- function(ent) {
  log_step("exporting ", ent)
  df <- readRDS(interim_path("complete", ent))

  missing <- setdiff(CSV_COLUMNS, names(df))
  if (length(missing) > 0) {
    stop("columns missing before export: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  out <- df |> select(all_of(CSV_COLUMNS))
  for (nm in intersect(names(ROUND_DIGITS), names(out))) {
    out[[nm]] <- round(out[[nm]], ROUND_DIGITS[[nm]])
  }

  csv_path <- file.path(DIR_PROCESSED, sprintf("ageb_indicadores_%s.csv", ent))
  write_csv(out, csv_path, na = "")

  # Detail tables (spec section 7).
  write_csv(readRDS(interim_path("denue_establishments", ent)),
            file.path(DIR_PROCESSED, sprintf("denue_establishments_%s.csv", ent)), na = "")
  write_csv(readRDS(interim_path("denue_sector", ent)),
            file.path(DIR_PROCESSED, sprintf("denue_ageb_sector_%s.csv", ent)), na = "")
  write_csv(readRDS(interim_path("landuse_detail", ent)),
            file.path(DIR_PROCESSED, sprintf("ageb_landuse_detail_%s.csv", ent)), na = "")

  # Geometry, published in EPSG:4326 and carrying the identification block so
  # it is usable without joining back to the CSV.
  geom <- sf::st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    sf::st_transform(CRS_OUTPUT) |>
    left_join(out |> select(ID_AGEB, AMBITO, CVE_ENT, CVE_MUN, NOM_MUN,
                            NOM_LOC, AREA_KM2, POB_TOTAL, GRS_GRADO),
              by = "ID_AGEB")
  sf::st_write(geom, file.path(DIR_PROCESSED, sprintf("ageb_geom_%s.gpkg", ent)),
               layer = "ageb", delete_dsn = TRUE, quiet = TRUE)

  log_msg("  wrote ", nrow(out), " rows -> ", basename(csv_path))
  invisible(csv_path)
}

# Concatenates the per-entity CSVs into the national file.
export_national <- function(ents) {
  log_step("national consolidation")
  paths <- file.path(DIR_PROCESSED, sprintf("ageb_indicadores_%s.csv", ents))
  paths <- paths[file.exists(paths)]
  if (length(paths) == 0) return(invisible(NULL))

  all <- map_dfr(paths, ~ read_csv(.x, col_types = cols(
    .default = col_guess(),
    ID_AGEB = col_character(), CVE_ENT = col_character(),
    CVE_MUN = col_character(), CVE_LOC = col_character(),
    CVE_AGEB = col_character()), progress = FALSE))

  out_path <- file.path(DIR_PROCESSED, "ageb_indicadores_MX.csv")
  write_csv(all, out_path, na = "")
  log_msg("  ", nrow(all), " AGEB from ", length(paths), " entities -> ",
          basename(out_path))
  invisible(out_path)
}
