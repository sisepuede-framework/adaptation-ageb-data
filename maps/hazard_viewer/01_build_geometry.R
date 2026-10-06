# 01_build_geometry.R -- AGEB geometry + labels for the national hazard viewer.
#
# Writes OUT_DIR/geometry.js: window.GEO (GeoJSON, one feature per AGEB, sorted
# by CVEGEO, property i = row in every data matrix) and window.META (labels and
# per-state bounding boxes). Sorting by CVEGEO is the contract with
# 02_build_data.py: column j of every matrix is the j-th feature here.
#
# Simplification is proportional to the AGEB's size: an urban AGEB (~0.4 km2)
# keeps ~12 m of detail, a rural one (~80 km2) ~150 m. A single tolerance would
# either wreck the cities or bloat the countryside.
#
#   Rscript maps/hazard_viewer/01_build_geometry.R [out_dir]

suppressMessages({ library(sf); library(jsonlite) })
sf_use_s2(FALSE)

args    <- commandArgs(trailingOnly = TRUE)
OUT_DIR <- if (length(args) >= 1) args[1] else path.expand("~/Downloads/hazard_viewer_ageb_mexico")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

root <- if (dir.exists("data/interim")) "." else stop("run from the project root")
g <- do.call(rbind, lapply(sprintf("%s/data/interim/ageb_geom_%02d.gpkg", root, 1:32),
                           st_read, quiet = TRUE))
g <- g[order(g$CVEGEO), ]
stopifnot(!anyDuplicated(g$CVEGEO), nrow(g) == 81451L)

g6   <- st_transform(g, 6372)
area <- as.numeric(st_area(g6))
tol  <- pmin(150, pmax(10, 0.02 * sqrt(area)))
bins <- c(10, 20, 40, 80, 150)
tol  <- bins[findInterval(tol, bins, all.inside = TRUE)]
geom <- st_geometry(g6)
for (b in unique(tol)) {
  idx <- which(tol == b)
  geom[idx] <- st_simplify(geom[idx], preserveTopology = TRUE, dTolerance = b)
}
out <- st_sf(i = seq_len(nrow(g)) - 1L, geometry = st_transform(geom, 4326))
stopifnot(!any(st_is_empty(out)))

tmp <- tempfile(fileext = ".geojson")
st_write(out, tmp, driver = "GeoJSON", quiet = TRUE,
         layer_options = c("COORDINATE_PRECISION=4"))
gj <- readLines(tmp, warn = FALSE) |> paste(collapse = "")

ids <- read.csv(file.path(root, "data/processed/ageb_ids.csv"), colClasses = "character")
ids <- ids[match(g$CVEGEO, ids$CVEGEO), ]
stopifnot(!anyNA(ids$CVEGEO))
codes <- function(x) { u <- unique(x); list(dict = u, code = match(x, u) - 1L) }
ent <- codes(ids$CVE_ENT); nent <- ids$NOM_ENT[match(ent$dict, ids$CVE_ENT)]
mun <- codes(substr(ids$CVEGEO, 1, 5)); nmun <- ids$NOM_MUN[match(mun$dict, substr(ids$CVEGEO, 1, 5))]
loc <- codes(paste(substr(ids$CVEGEO, 1, 9), ids$NOM_LOC, sep = "|"))
bb <- lapply(split(seq_len(nrow(out)), ent$code), function(ix) {
  b <- st_bbox(out[ix, ]); unname(round(as.numeric(b[c("xmin", "ymin", "xmax", "ymax")]), 3))
})
mbb <- lapply(split(seq_len(nrow(out)), mun$code), function(ix) {
  b <- st_bbox(out[ix, ]); unname(round(as.numeric(b[c("xmin", "ymin", "xmax", "ymax")]), 3))
})
meta <- list(
  id = ids$CVEGEO, amb = ifelse(ids$AMBITO == "Rural", 1L, 0L),
  entCode = ent$dict, entName = nent, ent = ent$code,
  munCode = mun$dict, munName = nmun, mun = mun$code,
  locName = sub("^[^|]*[|]", "", loc$dict), loc = loc$code,
  area = round(as.numeric(ids$AREA_KM2), 3),
  entBbox = unname(bb), munBbox = unname(mbb)
)
con <- file(file.path(OUT_DIR, "geometry.js"), "w", encoding = "UTF-8")
writeLines(c(paste0("window.GEO=", gj, ";"),
             paste0("window.META=", toJSON(meta, auto_unbox = TRUE, digits = NA), ";")), con)
close(con)
cat("geometry.js:", round(file.size(file.path(OUT_DIR, "geometry.js")) / 1e6, 1), "MB,",
    nrow(out), "AGEB\n")
