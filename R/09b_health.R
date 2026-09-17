# 09b_health.R -- straight-line distance from each AGEB's population to the
# nearest operating health facility, from the CLUES catalog.
#
# DENUE counts establishments inside the AGEB, which for a hospital is zero
# almost everywhere and says nothing about how far care is. CLUES is the
# Secretaria de Salud registry: it states whether a unit operates, its level of
# care and its institution, and is geocoded. Three distances are published:
#
#   DIST_HOSP_KM        any hospital (second or third level), private included
#   DIST_HOSP_PUB_KM    public hospital -- the one open to the uninsured
#   DIST_1NIVEL_PUB_KM  public first-level clinic (centro de salud, UMF, UMR)
#
# Distances run from where people live, not from the polygon. An urban AGEB is
# small, so its interior point stands in for it. A rural AGEB can span hundreds
# of km2 with its population in a few localities, so its distance is the mean
# over its inhabited ITER localities (MG {ENT}lpr.shp points), weighted by
# population; DIST_ORIGEN records which of the two was used. Rural AGEB with no
# inhabited locality fall back to the interior point.
#
# The facility set is national: the nearest hospital for a border municipality
# is often in the next state. Straight-line distance understates travel in the
# sierra, where roads wind; it ranks access, it does not measure travel time.

suppressPackageStartupMessages(library(sf))

# Institutions whose units are not general care open to the public: forensic
# and judicial services, addiction prevention, driver-licence exams (SCT) and
# DIF rehabilitation units.
CLUES_NON_CARE_PATTERN <- paste(
  "INTEGRACION JUVENIL", "FISCALIA", "PROCURADURIA", "PODER JUDICIAL",
  "TRIBUNAL", "FORENSES", "SEGURIDAD Y PROTECCI", "COMUNICACIONES Y TRANSPORTES",
  "DESARROLLO INTEGRAL DE LA FAMILIA", sep = "|")

# Not government-run: excluded from the public distances.
CLUES_NON_PUBLIC_PATTERN <- "SERVICIOS MEDICOS PRIVADOS|CRUZ ROJA"

# Mobile units and brigades have a registered base, not a fixed place of care.
CLUES_MOBILE_PATTERN <- "M[OÓ]VIL|BRIGADA"

# Single-purpose hospitals that do not take general admissions.
CLUES_SPECIALTY_HOSP_PATTERN <- "PSIQUI|ADICCIONES"

HEALTH_DIST_COLS <- c(DIST_HOSP_KM = "HOSP", DIST_HOSP_PUB_KM = "HOSP_PUB",
                      DIST_1NIVEL_PUB_KM = "NIVEL1_PUB")

# Operating, correctly geocoded facilities with their class flags, in
# EPSG:6372. Built once from the national workbook and cached.
load_clues_facilities <- function() {
  cache <- interim_path("clues_facilities", "MX")
  if (file.exists(cache)) return(readRDS(cache))
  log_msg("  building CLUES facility layer")

  raw <- readxl::read_excel(
    file.path(DIR_RAW, "national", "clues", CLUES_FILE),
    sheet = 1, col_types = "text")

  fac <- raw |>
    transmute(
      CLUES,
      CVE_ENT  = `CLAVE DE LA ENTIDAD`,
      STATUS   = `ESTATUS DE OPERACION`,
      TIPO     = `NOMBRE TIPO ESTABLECIMIENTO`,
      NIVEL    = `NIVEL ATENCION`,
      TIPOLOGIA = coalesce(`NOMBRE DE TIPOLOGIA`, ""),
      INSTITUCION = toupper(`NOMBRE DE LA INSTITUCION`),
      MOBILE   = !is.na(`UNIDAD MOVIL TIPO`) |
        grepl(CLUES_MOBILE_PATTERN, TIPOLOGIA),
      LAT = suppressWarnings(as.numeric(LATITUD)),
      LON = suppressWarnings(as.numeric(LONGITUD))
    ) |>
    filter(STATUS == "EN OPERACION")
  n_operating <- nrow(fac)

  fac <- fac |> filter(!is.na(LAT), !is.na(LON)) |>
    st_as_sf(coords = c("LON", "LAT"), crs = CRS_SOURCE, remove = FALSE) |>
    st_transform(CRS_ANALYSIS)
  n_coords <- nrow(fac)

  # Geocoding check against CONABIO's national municipal layer (already
  # downloaded, and unlike the MG it does not depend on which entities have
  # been fetched). Points inside their declared entity pass directly; the rest
  # are measured to that entity's municipalities.
  mun <- st_read(find_file(file.path(DIR_RAW, "national", "municipios"), "\\.shp$"),
                 quiet = TRUE) |>
    select(MUN_ENT = CVE_ENT) |>
    st_transform(CRS_ANALYSIS) |>
    st_make_valid()
  hit <- st_join(fac |> select(CLUES), mun, join = st_intersects, left = TRUE) |>
    st_drop_geometry() |>
    distinct(CLUES, .keep_all = TRUE)
  hit_ent <- hit$MUN_ENT[match(fac$CLUES, hit$CLUES)]
  keep <- !is.na(hit_ent) & hit_ent == fac$CVE_ENT

  outside <- which(!keep)
  near <- st_is_within_distance(fac[outside, ], mun,
                                dist = CLUES_ENTITY_TOL_KM * 1000)
  keep[outside] <- mapply(\(i, js) any(mun$MUN_ENT[js] == fac$CVE_ENT[i]),
                          outside, near)
  fac <- fac[keep, ]

  fac <- fac |>
    mutate(
      CARE   = !grepl(CLUES_NON_CARE_PATTERN, INSTITUCION) & !MOBILE,
      PUBLIC = !grepl(CLUES_NON_PUBLIC_PATTERN, INSTITUCION),
      HOSP   = CARE & grepl("HOSPITALIZACI", TIPO) &
        !grepl(CLUES_SPECIALTY_HOSP_PATTERN, TIPOLOGIA),
      HOSP_PUB   = HOSP & PUBLIC,
      NIVEL1_PUB = CARE & PUBLIC & grepl("CONSULTA EXTERNA", TIPO) &
        NIVEL == "PRIMER NIVEL"
    ) |>
    filter(HOSP | NIVEL1_PUB) |>
    select(CLUES, CVE_ENT, all_of(unname(HEALTH_DIST_COLS)))

  log_msg("  CLUES: ", n_operating, " operating | ", n_coords, " with coordinates | ",
          n_coords - sum(keep), " dropped as geocoded > ", CLUES_ENTITY_TOL_KM,
          " km outside their entity | hospitals ", sum(fac$HOSP), " (public ",
          sum(fac$HOSP_PUB), ") | public first-level ", sum(fac$NIVEL1_PUB))
  saveRDS(fac, cache)
  fac
}

# Distance in km from each origin point to the nearest facility of a set.
nearest_km <- function(origins, facilities) {
  idx <- st_nearest_feature(origins, facilities)
  as.numeric(st_distance(origins, facilities[idx, ], by_element = TRUE)) / 1000
}

build_health <- function(ent) {
  log_step("health access ", ent)
  fac <- load_clues_facilities()

  ageb <- st_read(interim_path("ageb_geom", ent, "gpkg"), quiet = TRUE) |>
    st_transform(CRS_ANALYSIS)
  attrs <- readRDS(interim_path("ageb_attrs", ent))
  rural_ids <- attrs$ID_AGEB[attrs$AMBITO == "Rural"]

  loc_pts <- inhabited_locality_points(ent, rural_ids) |>
    mutate(DIST_ORIGEN = "Localidades")

  # Everything else -- urban AGEB and uninhabited rural ones -- from the
  # interior point, which always falls inside its own polygon.
  interior <- suppressWarnings(st_point_on_surface(ageb)) |>
    filter(!ID_AGEB %in% loc_pts$ID_AGEB) |>
    transmute(ID_AGEB, W = 1, DIST_ORIGEN = "Punto interior")
  st_geometry(interior) <- "geometry"

  origins <- rbind(loc_pts, interior)
  for (col in names(HEALTH_DIST_COLS)) {
    origins[[col]] <- nearest_km(origins, fac[fac[[HEALTH_DIST_COLS[[col]]]], ])
  }

  out <- origins |>
    st_drop_geometry() |>
    group_by(ID_AGEB, DIST_ORIGEN) |>
    summarise(across(all_of(names(HEALTH_DIST_COLS)), ~ weighted.mean(.x, W)),
              .groups = "drop")

  if (anyDuplicated(out$ID_AGEB) || !setequal(out$ID_AGEB, attrs$ID_AGEB)) {
    stop("health distances do not map one-to-one onto the AGEB spine in entity ",
         ent, call. = FALSE)
  }

  log_msg("  origins: ", nrow(loc_pts), " rural localities + ", nrow(interior),
          " interior points | median km to hospital: urban ",
          round(median(out$DIST_HOSP_KM[!out$ID_AGEB %in% rural_ids]), 1),
          ", rural ", round(median(out$DIST_HOSP_KM[out$ID_AGEB %in% rural_ids]), 1))
  saveRDS(out, interim_path("health", ent))
  invisible(out)
}
