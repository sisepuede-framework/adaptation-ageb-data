# 09_landuse.R -- land use and vegetation (USYV Serie VII) per AGEB.
#
# Areal intersection in EPSG:6372 (spec section 5.7). The dominant class is the
# one covering the largest share of the AGEB, and USO_PCT is that share. The
# full AGEB x class breakdown is kept and exported separately, since it is the
# most informative block for rural AGEB.

suppressPackageStartupMessages(library(sf))

# Candidate attributes for the Serie VII class label, in order of preference.
USV_CLASS_FIELDS <- c("DESCRIPCIO", "TIPO", "CLAVE", "DESCRIPCION", "FORMACION")

# Serie VII marks human settlements with the ZU (zona urbana) class.
URBAN_CLASS_PATTERN <- "ASENTAMIENTO|ZONA URBANA|URBANO"

build_landuse <- function(ent) {
  log_step("land use ", ent)
  ageb <- st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)
  attrs <- readRDS(interim_path("ageb_attrs", ent))

  usv <- read_national_layer("landuse", "\\.shp$", ent)
  field <- intersect(USV_CLASS_FIELDS, names(usv))[1]
  if (is.na(field)) {
    stop("no recognisable class field in the USYV layer; saw: ",
         paste(names(usv), collapse = ", "), call. = FALSE)
  }
  log_msg("  USYV features in window: ", nrow(usv), " | class field: ", field)

  usv <- usv |> transmute(USO_CLASE = as.character(.data[[field]]))

  inter <- suppressWarnings(st_intersection(ageb, usv))

  detail <- inter |>
    mutate(A = area_km2(inter)) |>
    st_drop_geometry() |>
    group_by(ID_AGEB, USO_CLASE) |>
    summarise(CLASS_AREA_KM2 = sum(A), .groups = "drop") |>
    left_join(attrs |> select(ID_AGEB, AREA_KM2), by = "ID_AGEB") |>
    mutate(CLASS_PCT = pmin(100, safe_pct(CLASS_AREA_KM2, AREA_KM2)))

  dominant <- detail |>
    group_by(ID_AGEB) |>
    slice_max(CLASS_AREA_KM2, n = 1, with_ties = FALSE) |>
    ungroup() |>
    transmute(ID_AGEB, USO_DOM = USO_CLASE, USO_PCT = CLASS_PCT)

  urban_share <- detail |>
    filter(grepl(URBAN_CLASS_PATTERN, toupper(USO_CLASE))) |>
    group_by(ID_AGEB) |>
    summarise(PCT_URB = pmin(100, sum(CLASS_PCT)), .groups = "drop")

  out <- attrs |>
    select(ID_AGEB) |>
    left_join(dominant, by = "ID_AGEB") |>
    left_join(urban_share, by = "ID_AGEB") |>
    mutate(PCT_URB = coalesce(PCT_URB, 0))

  log_msg("  AGEB with a dominant class: ", sum(!is.na(out$USO_DOM)),
          " of ", nrow(out))
  saveRDS(out, interim_path("landuse", ent))
  saveRDS(detail, interim_path("landuse_detail", ent))
  invisible(out)
}
