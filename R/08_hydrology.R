# 08_hydrology.R -- water bodies intersected with AGEB.
#
# Areal intersection in EPSG:6372, never a spatial join: an AGEB that merely
# touches a lagoon must not inherit its whole area. Applies to urban and rural
# AGEB alike, and a genuine 0 is recorded where nothing intersects -- distinct
# from NA, which would mean "not computed" (spec section 5.6).

suppressPackageStartupMessages(library(sf))

# Reads a national CONABIO layer windowed to the entity envelope, so the 189 MB
# and 317 MB files are never loaded whole.
read_national_layer <- function(folder, pattern, ent) {
  path <- find_file(file.path(DIR_RAW, "national", folder), pattern)
  bb <- entity_bbox_4326(ent)
  win <- st_as_sfc(st_bbox(c(xmin = bb[["xmin"]], ymin = bb[["ymin"]],
                             xmax = bb[["xmax"]], ymax = bb[["ymax"]]),
                           crs = CRS_OUTPUT))
  # CONABIO ships these layers in UTF-8 with no .cpg; forcing ISO-8859-1 here
  # double-encodes the accents ("ACUICOLA" -> mojibake), so GDAL's default is
  # left alone. The MG shapefiles are the latin-1 ones.
  lyr <- tools::file_path_sans_ext(basename(path))
  src_crs <- st_crs(st_read(path, quiet = TRUE,
                            query = sprintf('SELECT * FROM "%s" LIMIT 1', lyr)))
  win <- st_transform(win, src_crs)
  x <- st_read(path, quiet = TRUE, wkt_filter = st_as_text(win))
  st_make_valid(st_transform(x, CRS_ANALYSIS))
}

build_hydrology <- function(ent) {
  log_step("hydrology ", ent)
  ageb <- st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)
  attrs <- readRDS(interim_path("ageb_attrs", ent))

  water <- read_national_layer("water", "\\.shp$", ent)
  log_msg("  water features in window: ", nrow(water))

  inter <- suppressWarnings(
    st_intersection(ageb, st_union(st_geometry(water)))
  )

  # area_km2() reads the active geometry column by name-independent means: the
  # GeoPackage names it "geom", not "geometry".
  water_by_ageb <- inter |>
    mutate(A = area_km2(inter)) |>
    st_drop_geometry() |>
    group_by(ID_AGEB) |>
    summarise(WATER_AREA = sum(A), .groups = "drop")

  out <- attrs |>
    select(ID_AGEB, AREA_KM2) |>
    left_join(water_by_ageb, by = "ID_AGEB") |>
    mutate(
      WATER_AREA = coalesce(WATER_AREA, 0),          # real zero, not missing
      WATER_PCT  = pmin(100, safe_pct(WATER_AREA, AREA_KM2)),
      HAS_WATER  = as.integer(WATER_AREA > 0)
    ) |>
    select(ID_AGEB, WATER_AREA, WATER_PCT, HAS_WATER)

  log_msg("  AGEB with water: ", sum(out$HAS_WATER), " | total water km2: ",
          round(sum(out$WATER_AREA), 1))
  saveRDS(out, interim_path("hydrology", ent))
  invisible(out)
}
