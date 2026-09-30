# 12_export.R -- the published schema: the column list, its rounding and the
# split between what identifies an AGEB and what is measured about it.
#
# Nothing is written from here any more. This block used to publish one CSV of
# these columns per entity, plus the geometry and three detail tables; all of
# them are now layers of base_ageb_{ENT}.gpkg (14_integrate.R), which calls
# published_table() for the values below so the database carries exactly them.
# The dictionary contract that used to live here moved there too, because these
# columns are no longer one table: ID_COLUMNS becomes ageb_ids and the rest,
# keyed by ID_AGEB alone, becomes ageb_integrada.

# Census counts published after the headline indicators, for re-aggregation to
# other geographies. The six excluded here already appear earlier in the schema.
CENSUS_COUNT_COLS <- setdiff(
  names(CENSUS_VARS),
  c("POB_TOTAL", "POB_HOMBRES", "POB_MUJERES", "VIV_PART_HAB", "VIV_DRENAJE",
    "VIV_ELECTRICIDAD"))

# Declared in order rather than derived from the data, so the published schema
# is stable and a missing upstream column fails loudly instead of vanishing.
# The census catalogs it draws on live in 04_census_urban.R and 10_build.R.
# Who the AGEB is and where it sits: the keys, the names they stand for, and
# the two descriptors read straight off the polygon. Published once, as the
# ageb_ids table, so every other table carries only ID_AGEB and joins back to
# this one (14_integrate.R). ID_AGEB leads the list because it is the key.
ID_COLUMNS <- c(
  "ID_AGEB", "AMBITO", "CVE_ENT", "NOM_ENT", "CVE_MUN", "NOM_MUN",
  "CVE_LOC", "NOM_LOC", "CVE_AGEB", "AREA_KM2", "CENTROIDE_LON", "CENTROIDE_LAT"
)

CSV_COLUMNS <- c(
  ID_COLUMNS,
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
  names(HEALTH_DIST_COLS), "DIST_ORIGEN",
  TERRAIN_COLS,
  HAZARD_COLS,
  INCOME_COLS,
  CENSUS_COUNT_COLS,
  "YEAR_GEOMETRY", "YEAR_CENSUS", "YEAR_CONEVAL", "YEAR_DENUE", "YEAR_HIDRO", "YEAR_USV",
  "YEAR_CLUES", "YEAR_CEM", "YEAR_RED_HIDRO", "YEAR_COSTA", "YEAR_CENAPRED",
  "YEAR_ICMM"
)

# Rounded on export only; the interim tables keep full precision.
ROUND_DIGITS <- c(
  AREA_KM2 = 6, CENTROIDE_LON = 6, CENTROIDE_LAT = 6,
  PCT_POB_REPORTADA = 2, PCT_HOMBRES = 2, PCT_MUJERES = 2,
  DENS_POB_KM2 = 2, POB_POR_VIV = 2,
  PCT_DRENAJE = 2, PCT_ELECTRIC = 2,
  WATER_AREA = 6, WATER_PCT = 2, USO_PCT = 2, PCT_URB = 2,
  setNames(rep(3, length(HEALTH_DIST_COLS)), names(HEALTH_DIST_COLS)),
  ELEV_M = 1, PEND_MEDIA_GRAD = 2, PCT_PEND_15 = 2, PCT_PEND_30 = 2,
  DIST_CAUCE_KM = 3, DESNIVEL_CAUCE_M = 1, DIST_COSTA_KM = 3,
  ING_MUN_HOG_TRIM = 0, ING_MUN_LIM_INF = 0, ING_MUN_LIM_SUP = 0, ING_MUN_CV = 2,
  setNames(rep(2, length(CENSUS_SHARE_COLS) + length(CENSUS_AVG_COLS)),
           c(CENSUS_SHARE_COLS, CENSUS_AVG_COLS))
)

# Who the AGEB is, for one entity: the slice of the published table that becomes
# the national ageb_ids. Taken from the same rounded values as everything else,
# so the ID table cannot describe an AGEB differently than the data tables do.
ids_table <- function(ent) {
  published_table(ent) |> select(all_of(ID_COLUMNS))
}

# The published indicator columns of one entity: schema order, rounded.
# 14_integrate.R builds the ageb_integrada table on top of this, so the
# database carries these values and not a second rounding of the interim table.
published_table <- function(ent) {
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
  out
}
