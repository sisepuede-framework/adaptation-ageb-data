# 09c_terrain.R -- physical exposure: relief, streams and coast, per AGEB.
#
# These are hazard-side columns, kept outside any vulnerability index (D-30):
#
#   ELEV_M            mean elevation, m above the Mexican geoid
#   PEND_MEDIA_GRAD   mean slope, degrees                          -> landslide
#   PCT_PEND_15/30    share of inhabited ground steeper than 15/30 -> landslide
#   DIST_CAUCE_KM     distance to the nearest stream of Strahler order >= 3
#   DIST_COSTA_KM     distance to the coastline                    -> storm surge
#   DESNIVEL_CAUCE_M  height above the nearest water: that stream's bed or the
#                     sea, whichever is closer                     -> flood
#
# Everything is read where people live, the same origins as 09b_health.R
# (DIST_ORIGEN). Relief is an area statistic: over the whole polygon for urban
# and uninhabited rural AGEB, and over a TERRAIN_BUFFER_M disc around each
# inhabited locality for the rest, weighted by population. Averaging the slope
# of a rural AGEB that spans a whole sierra would say nothing about the village
# in its valley. Distances and the height above the stream run from points: the
# interior point, or each inhabited locality.
#
# DESNIVEL_CAUCE_M is a plan-nearest approximation of HAND (height above
# nearest drainage): the water closest in plan, not the channel water would
# actually flow to. The sea counts as drainage at elevation 0: coastal plains
# have few order-3 streams, and measured against the nearest one -- in Oaxaca's
# lagoon coast, a sierra creek 13-24 km inland -- lowland villages came out
# 700 m *below* their "stream". It can still be negative where the nearest
# stream runs in the next valley over, and it is an elevation difference only:
# it knows nothing of levees, channel capacity or rainfall. Small and near
# means flood-prone.
#
# CEM 4.0 is radar-derived (ALOS PALSAR); in dense cities it partly follows
# rooftops, so urban slope reads a little rough.

suppressPackageStartupMessages({ library(sf); library(terra) })

TERRAIN_COLS <- c("ELEV_M", "PEND_MEDIA_GRAD", "PCT_PEND_15", "PCT_PEND_30",
                  "DIST_CAUCE_KM", "DESNIVEL_CAUCE_M", "DIST_COSTA_KM")

# One virtual mosaic over every entity's GeoTIFF, so windows near a state line
# read the neighbour's cells instead of NA.
cem_mosaic <- function() {
  tifs <- unlist(lapply(ENTITIES, function(e) {
    d <- file.path(DIR_RAW, e, "cem")
    if (dir.exists(d)) list.files(d, "\\.tif$", recursive = TRUE, full.names = TRUE)
  }))
  if (length(tifs) == 0) stop("no CEM GeoTIFF under data/raw/*/cem", call. = FALSE)
  vrt(tifs)
}

# Strahler order >= STREAM_MIN_ORDER flow lines from the 37 regional archives,
# built once and cached as a GeoPackage (~1 GB, 1.6 million segments), from
# which each entity reads only its window through the spatial index. LINEA
# CENTRAL segments (TIPO 103) are kept: they carry the network through lakes
# and wide rivers drawn as polygons.
load_streams <- function(window) {
  cache <- interim_path("streams", "MX", "gpkg")
  if (file.exists(cache)) {
    return(st_read(cache, wkt_filter = st_as_text(window), quiet = TRUE))
  }
  log_msg("  building national stream layer (Strahler >= ", STREAM_MIN_ORDER, ")")
  files <- list.files(file.path(DIR_RAW, "national", "red_hidro"), "_hl\\.shp$",
                      recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(files) == 0) stop("no Red Hidrografica flow lines found", call. = FALSE)
  # bind_rows, not do.call(rbind): over ~1,000 layers rbind took an hour.
  streams <- bind_rows(lapply(files, function(f) {
    x <- st_read(f, quiet = TRUE)
    x <- x[x$ORDER_1 >= STREAM_MIN_ORDER, c("ORDER_1", "CONDICION")]
    st_transform(st_zm(x), CRS_ANALYSIS)
  }))
  st_geometry(streams) <- "geom"
  log_msg("  streams: ", nrow(streams), " segments from ", length(files), " subcuencas")
  st_write(streams, cache, quiet = TRUE, delete_dsn = TRUE)
  streams[st_intersects(streams, window, sparse = FALSE)[, 1], ]
}

load_coast <- function() {
  cache <- interim_path("coast", "MX")
  if (file.exists(cache)) return(readRDS(cache))
  coast <- st_read(find_file(file.path(DIR_RAW, "national", "coast"), "\\.shp$"),
                   quiet = TRUE) |>
    filter(DESCRIP != "Frontera") |>
    st_transform(CRS_ANALYSIS) |>
    st_geometry() |>
    st_cast("LINESTRING")
  saveRDS(coast, cache)
  coast
}

# Weighted mean over the origins of each AGEB, NA-aware: an origin with no DEM
# cells (a speck of island the CEM leaves out) drops from the mean instead of
# blanking the AGEB.
weighted_by_ageb <- function(df, cols) {
  df |>
    group_by(ID_AGEB) |>
    summarise(across(all_of(cols), ~ {
      ok <- !is.na(.x)
      if (any(ok)) sum(.x[ok] * W[ok]) / sum(W[ok]) else NA_real_
    }), .groups = "drop")
}

build_terrain <- function(ent) {
  log_step("terrain and flood exposure ", ent)
  # terra draws progress bars for long operations; they flood the run log.
  terraOptions(progress = 0)
  ageb <- st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)
  st_geometry(ageb) <- "geometry"
  attrs <- readRDS(interim_path("ageb_attrs", ent))
  rural_ids <- attrs$ID_AGEB[attrs$AMBITO == "Rural"]

  loc_pts <- inhabited_locality_points(ent, rural_ids)
  polys <- ageb |> filter(!ID_AGEB %in% loc_pts$ID_AGEB) |> mutate(W = 1)

  # --- Relief. The DEM window is the entity plus a margin, so border slopes
  # are computed with real neighbours rather than an edge.
  dem_all <- cem_mosaic()
  win <- st_bbox(st_transform(st_buffer(st_as_sfc(st_bbox(ageb)), 2000), crs(dem_all)))
  dem <- crop(dem_all, ext(win[["xmin"]], win[["xmax"]], win[["ymin"]], win[["ymax"]]))
  slope <- terrain(dem, "slope", unit = "degrees")
  relief <- c(dem, slope, slope > SLOPE_THRESHOLDS[1], slope > SLOPE_THRESHOLDS[2])
  names(relief) <- c("ELEV_M", "PEND_MEDIA_GRAD", "PCT_PEND_15", "PCT_PEND_30")
  relief_cols <- names(relief)

  zonal <- function(zones) {
    v <- vect(st_transform(zones, crs(relief)))
    vals <- terra::extract(relief, v, fun = mean, na.rm = TRUE, ID = FALSE)
    bind_cols(st_drop_geometry(zones)[c("ID_AGEB", "W")], as_tibble(vals))
  }
  discs <- st_buffer(loc_pts, TERRAIN_BUFFER_M)
  relief_raw <- bind_rows(zonal(discs), zonal(polys))
  relief_tbl <- relief_raw |>
    mutate(PCT_PEND_15 = 100 * PCT_PEND_15, PCT_PEND_30 = 100 * PCT_PEND_30) |>
    weighted_by_ageb(relief_cols)

  # --- Streams and coast, from points.
  interior <- suppressWarnings(st_point_on_surface(polys)) |> select(ID_AGEB, W)
  origins <- rbind(loc_pts, interior)

  # A window padded by 100 km keeps the national layer out of the search; that
  # is far beyond any real nearest order-3 stream.
  pad <- st_as_sfc(st_bbox(st_buffer(st_as_sfc(st_bbox(ageb)), 100000)))
  streams <- load_streams(pad)
  coast <- load_coast()

  link_to <- function(target) {
    st_nearest_points(origins, target[st_nearest_feature(origins, target)],
                      pairwise = TRUE)
  }
  stream_link <- link_to(st_geometry(streams))
  coast_link  <- link_to(coast)
  origins$DIST_CAUCE_KM <- as.numeric(st_length(stream_link)) / 1000
  origins$DIST_COSTA_KM <- as.numeric(st_length(coast_link)) / 1000

  # Height above the nearest water. The ground is the origin's own relief
  # reading (disc or polygon mean, the same cells as ELEV_M), not a single
  # pixel, which can fall on a lagoon cell with no value. relief_raw is in
  # discs-then-polygons order, the same as origins. A stream's bed is the
  # lowest cell near the closest point on it; the sea is 0.
  ground <- relief_raw$ELEV_M
  to_coast <- origins$DIST_COSTA_KM < origins$DIST_CAUCE_KM
  bed_pts <- st_cast(stream_link, "POINT")[c(FALSE, TRUE)]
  bed <- st_buffer(st_sf(geometry = bed_pts[!to_coast]), STREAM_BED_RADIUS_M)
  bed_elev <- rep(0, nrow(origins))
  if (any(!to_coast)) {
    b <- terra::extract(dem, vect(st_transform(bed, crs(dem))),
                        fun = min, na.rm = TRUE, ID = FALSE)[[1]]
    b[is.infinite(b)] <- NA
    bed_elev[!to_coast] <- b
  }
  origins$DESNIVEL_CAUCE_M <- ground - bed_elev

  point_cols <- c("DIST_CAUCE_KM", "DESNIVEL_CAUCE_M", "DIST_COSTA_KM")
  point_tbl <- origins |> st_drop_geometry() |> weighted_by_ageb(point_cols)

  out <- attrs |>
    select(ID_AGEB) |>
    left_join(relief_tbl, by = "ID_AGEB") |>
    left_join(point_tbl, by = "ID_AGEB") |>
    select(ID_AGEB, all_of(TERRAIN_COLS))

  if (nrow(out) != nrow(attrs) || anyDuplicated(out$ID_AGEB)) {
    stop("terrain table does not map one-to-one onto the AGEB spine in entity ",
         ent, call. = FALSE)
  }

  inh <- out$ID_AGEB %in% c(loc_pts$ID_AGEB, attrs$ID_AGEB[attrs$AMBITO == "Urbana"])
  log_msg("  origins: ", nrow(discs), " locality discs + ", nrow(polys),
          " polygons | AGEB without elevation: ", sum(is.na(out$ELEV_M)),
          " | median slope (inhabited) ",
          round(median(out$PEND_MEDIA_GRAD[inh], na.rm = TRUE), 1),
          " deg | median km to stream ",
          round(median(out$DIST_CAUCE_KM[inh], na.rm = TRUE), 2))
  saveRDS(out, interim_path("terrain", ent))
  invisible(out)
}
