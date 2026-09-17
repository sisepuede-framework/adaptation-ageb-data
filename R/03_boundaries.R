# 03_boundaries.R -- base geometry: urban + rural AGEB from the Marco
# Geoestadistico, plus the municipal and rural-locality layers the later
# blocks depend on.
#
# Verified layer inventory (entity 20, MG 2020), in conjunto_de_datos/:
#   {ENT}a.shp    urban AGEB polygons   CVEGEO 13 = ENT+MUN+LOC+AGEB
#   {ENT}ar.shp   rural AGEB polygons   CVEGEO  9 = ENT+MUN+AGEB  (no CVE_LOC)
#   {ENT}mun.shp  municipal polygons
#   {ENT}lpr.shp  rural locality points, carries CVE_AGEB
#   {ENT}l.shp    locality polygons (urban + the larger rural ones)
#
# Two facts drive the code below:
#  * The MG ships in EPSG:6372 already, so areas need no reprojection; only the
#    published centroids are converted to EPSG:4326.
#  * Rural AGEB have no CVE_LOC. To keep ID_AGEB a single 13-character key
#    across both ambits, rural rows get CVE_LOC = "0000", which is also the
#    census convention for "no specific locality".

suppressPackageStartupMessages(library(sf))

# Areas are always taken from the active geometry column rather than a literal
# `geometry` name: layers read back from GeoPackage call it "geom".
area_km2 <- function(x) as.numeric(st_area(st_geometry(x))) / 1e6

MG_ENCODING <- "ENCODING=ISO-8859-1"  # .cpg says "ISO 88591", which GDAL cannot parse

mg_dir <- function(ent) file.path(DIR_RAW, ent, "marcogeo", "conjunto_de_datos")

read_mg_layer <- function(ent, suffix) {
  path <- file.path(mg_dir(ent), sprintf("%s%s.shp", ent, suffix))
  if (!file.exists(path)) {
    stop("missing Marco Geoestadistico layer: ", basename(path), call. = FALSE)
  }
  x <- st_read(path, quiet = TRUE, options = MG_ENCODING)
  st_transform(x, CRS_ANALYSIS)
}

build_boundaries <- function(ent) {
  log_step("boundaries ", ent)

  urban <- read_mg_layer(ent, "a") |>
    transmute(
      CVE_ENT, CVE_MUN, CVE_LOC, CVE_AGEB,
      AMBITO = "Urbana",
      ID_AGEB = build_ageb_id(CVE_ENT, CVE_MUN, CVE_LOC, CVE_AGEB)
    )

  rural <- read_mg_layer(ent, "ar") |>
    transmute(
      CVE_ENT, CVE_MUN,
      CVE_LOC = "0000",
      CVE_AGEB,
      AMBITO = "Rural",
      ID_AGEB = build_ageb_id(CVE_ENT, CVE_MUN, CVE_LOC, CVE_AGEB)
    )

  ageb <- bind_rows(urban, rural) |> st_make_valid()
  ageb$CVE_MUN_FULL <- build_mun_id(ageb$CVE_ENT, ageb$CVE_MUN)
  ageb$AREA_KM2 <- area_km2(ageb)

  if (anyDuplicated(ageb$ID_AGEB)) {
    stop("duplicated ID_AGEB in entity ", ent, call. = FALSE)
  }

  # point_on_surface, not centroid: guarantees the published coordinate falls
  # inside its own AGEB even for concave or multipart rural polygons.
  # Warning suppressed knowingly: sf notes that attributes are assumed constant
  # over geometries, which is exactly the intent -- only the point is wanted.
  pts <- suppressWarnings(st_point_on_surface(ageb)) |>
    st_transform(CRS_OUTPUT) |>
    st_coordinates()

  ageb$CENTROIDE_LON <- pts[, "X"]
  ageb$CENTROIDE_LAT <- pts[, "Y"]

  log_msg("  AGEB: ", sum(ageb$AMBITO == "Urbana"), " urban + ",
          sum(ageb$AMBITO == "Rural"), " rural = ", nrow(ageb))

  saveRDS(st_drop_geometry(ageb), interim_path("ageb_attrs", ent))
  st_write(ageb["ID_AGEB"], interim_path("ageb_geom", ent, "gpkg"),
           layer = "ageb", delete_dsn = TRUE, quiet = TRUE)
  invisible(ageb)
}

# Municipal polygons from the same marco -- a like-for-like area reference for
# the coverage QC, avoiding the year mismatch of CONABIO's mun22gw (2022).
build_municipios <- function(ent) {
  mun <- read_mg_layer(ent, "mun") |> st_make_valid()
  mun <- tibble(
    CVE_MUN_FULL = build_mun_id(mun$CVE_ENT, mun$CVE_MUN),
    NOM_MUN      = mun$NOMGEO,
    MUN_AREA_KM2 = area_km2(mun)
  )
  saveRDS(mun, interim_path("municipios", ent))
  invisible(mun)
}

# Rural locality points carry CVE_AGEB and cover every rural locality (verified:
# all rural localities present in {ENT}l.shp also appear here), so this single
# layer is the locality -> rural AGEB bridge used by 05_census_rural.R.
build_locality_bridge <- function(ent) {
  lpr <- read_mg_layer(ent, "lpr") |>
    st_drop_geometry() |>
    transmute(
      ID_LOC = build_loc_id(CVE_ENT, CVE_MUN, CVE_LOC),
      ID_AGEB = build_ageb_id(CVE_ENT, CVE_MUN, "0000", CVE_AGEB),
      NOM_LOC = NOMGEO
    ) |>
    distinct(ID_LOC, .keep_all = TRUE)

  urban_loc <- read_mg_layer(ent, "l") |>
    st_drop_geometry() |>
    filter(AMBITO == "Urbana") |>
    transmute(ID_LOC = build_loc_id(CVE_ENT, CVE_MUN, CVE_LOC), NOM_LOC = NOMGEO)

  saveRDS(list(rural = lpr, urban = urban_loc), interim_path("locality_bridge", ent))
  log_msg("  localities: ", nrow(lpr), " rural, ", nrow(urban_loc), " urban")
  invisible(lpr)
}

# Where the people of each rural AGEB live: its inhabited ITER localities as
# MG {ENT}lpr.shp points, in EPSG:6372, with the headcount as weight W. POBTOT
# is never suppressed in the ITER (05_census_rural.R enforces it). Rural AGEB
# absent from the result are uninhabited. Shared by 09b_health.R and
# 09c_terrain.R so both measure from the same places.
inhabited_locality_points <- function(ent, rural_ids) {
  iter_pop <- read_utf8_csv(
    find_file(file.path(DIR_RAW, ent, "iter"), "conjunto_de_datos_iter_.*\\.csv$")) |>
    rename_with(~ sub("^\ufeff", "", .x)) |>
    filter(LOC != "0000", as.integer(LOC) < 9998) |>
    transmute(ID_LOC = build_loc_id(ENTIDAD, MUN, LOC),
              W = to_num_suppressed(POBTOT))

  pts <- read_mg_layer(ent, "lpr") |>
    transmute(ID_LOC = build_loc_id(CVE_ENT, CVE_MUN, CVE_LOC),
              ID_AGEB = build_ageb_id(CVE_ENT, CVE_MUN, "0000", CVE_AGEB)) |>
    distinct(ID_LOC, .keep_all = TRUE) |>
    inner_join(iter_pop, by = "ID_LOC") |>
    filter(ID_AGEB %in% rural_ids, W > 0) |>
    select(ID_AGEB, W)
  st_geometry(pts) <- "geometry"
  pts
}

run_boundaries <- function(ent) {
  build_boundaries(ent)
  build_municipios(ent)
  build_locality_bridge(ent)
}

# Entity envelope in EPSG:4326, used to sanity-check DENUE coordinates and to
# window the large national CONABIO layers. Padded slightly so that features
# legitimately touching the border are not clipped away.
entity_bbox_4326 <- function(ent, pad_deg = 0.05) {
  cache <- interim_path("entity_bbox", ent)
  if (file.exists(cache)) return(readRDS(cache))
  bb <- read_mg_layer(ent, "ent") |> st_transform(CRS_OUTPUT) |> st_bbox()
  bb <- c(xmin = bb[["xmin"]] - pad_deg, ymin = bb[["ymin"]] - pad_deg,
          xmax = bb[["xmax"]] + pad_deg, ymax = bb[["ymax"]] + pad_deg)
  saveRDS(bb, cache)
  bb
}
