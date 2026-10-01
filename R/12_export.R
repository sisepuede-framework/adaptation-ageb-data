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

# One block at a time, in the order the data dictionary lists them: a reader
# scrolling the table meets a whole subject before the next one starts, and the
# dictionary's BLOQUE column never alternates. The blocks named in the comments
# are exactly the values of that column.
CSV_COLUMNS <- c(
  ID_COLUMNS,
  # Poblacion base
  "POB_TOTAL", "POB_HOMBRES", "POB_MUJERES", "PCT_HOMBRES", "PCT_MUJERES",
  "DENS_POB_KM2", "POB_POR_VIV",
  # Confiabilidad: how much of the AGEB was reported rather than imputed
  "POB_REPORTADA", "PCT_POB_REPORTADA", "N_CELDAS_IMPUTADAS",
  # Vivienda: the counts and the shares derived from them, together
  "VIV_PART_HAB", "VIV_CARACT", "VIV_DRENAJE", "VIV_ELECTRICIDAD",
  "PCT_DRENAJE", "PCT_ELECTRIC", SHARE_VIVIENDA,
  # Sensibilidad
  SHARE_SENSIBILIDAD,
  # Rezago social: the CONEVAL equivalents and the two census averages
  SHARE_REZAGO, CENSUS_AVG_COLS,
  # Empleo
  SHARE_EMPLEO,
  # Agua y almacenamiento
  SHARE_AGUA,
  # Bienes y movilidad
  SHARE_BIENES,
  # Comunicacion y alertas
  SHARE_COMUNICACION,
  # Validacion CONEVAL
  "GRS_GRADO", "GRS_NUM", RZ_NAMES,
  # Actividad economica (14_integrate.R splices DEN_SCIAN_* in after SCHOOL_TOT)
  "DENUE_TOT", "DEN_MANUF", "DEN_COM", "DEN_SERV", "DEN_EDU", "DEN_GOB", "SCHOOL_TOT",
  # Hidrografia
  "WATER_AREA", "WATER_PCT", "HAS_WATER",
  # Uso de suelo (14_integrate.R splices USV_PCT_* in after PCT_URB)
  "USO_DOM", "USO_PCT", "PCT_URB",
  # Acceso a salud
  names(HEALTH_DIST_COLS), "DIST_ORIGEN",
  # Relieve y exposicion
  TERRAIN_COLS,
  # Amenaza (CENAPRED)
  HAZARD_COLS,
  # Ingreso (municipal)
  INCOME_COLS,
  # Conteos censales
  CENSUS_COUNT_COLS
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

# What each source is, in the order the pipeline reads it. The key is the name
# it has in YEARS (00_config.R), which holds the vintage; this list holds the
# sentence that says what the vintage is the vintage of.
#
# These twelve were columns of the indicator table -- YEAR_GEOMETRY, YEAR_CENSUS
# and the rest -- until they were taken out of it. A source's vintage is a
# property of the source, not of the AGEB, so writing it on all 81,451 rows said
# one fact 81,451 times. It is now said once, in the fuentes table.
SOURCE_DESC <- c(
  geometry  = "Marco Geoestadístico del INEGI: las AGEB y sus polígonos.",
  census    = "Censo de Población y Vivienda: AGEB urbana e ITER para la rural.",
  coneval   = "Grado de Rezago Social (GRS) del CONEVAL a nivel AGEB.",
  denue     = "Directorio Estadístico Nacional de Unidades Económicas (DENUE).",
  hidro     = "Cuerpos de agua del Continuo Topográfico del INEGI.",
  usv       = "Uso de suelo y vegetación del INEGI, serie VII.",
  clues     = "Catálogo CLUES de establecimientos de salud de la Secretaría de Salud.",
  cem       = "Continuo de Elevaciones Mexicano 4.0 del INEGI.",
  red_hidro = "Red Hidrográfica 1:50 000, edición 2.0, del INEGI.",
  costa     = "Línea de costa de la CONABIO.",
  cenapred  = "Sistema de Indicadores Municipales del Atlas Nacional de Riesgos (CENAPRED).",
  icmm      = "Ingreso Corriente para los Municipios de México (INEGI, a partir de la ENIGH)."
)

# The fuentes table: one row per source, the same for the whole country, so it
# is published once (14_integrate.R) rather than per entity. VERSION is text
# because DENUE and CLUES are pinned to a month rather than a year, and a column
# that is sometimes 2020 and sometimes '2026-05' cannot be an integer.
#
# YEARS and SOURCE_DESC have to name exactly the same sources: a source added to
# one and not the other would otherwise be published without a vintage, or drop
# out of the table without a word.
fuentes_table <- function() {
  only_desc <- setdiff(names(SOURCE_DESC), names(YEARS))
  only_year <- setdiff(names(YEARS), names(SOURCE_DESC))
  if (length(only_desc) > 0 || length(only_year) > 0) {
    stop("SOURCE_DESC and YEARS disagree on which sources exist",
         if (length(only_desc) > 0) paste0("; no vintage for: ",
           paste(only_desc, collapse = ", ")),
         if (length(only_year) > 0) paste0("; no description for: ",
           paste(only_year, collapse = ", ")), call. = FALSE)
  }
  data.frame(
    FUENTE      = toupper(names(SOURCE_DESC)),
    VERSION     = as.character(unlist(YEARS[names(SOURCE_DESC)], use.names = FALSE)),
    DESCRIPCION = unname(SOURCE_DESC),
    stringsAsFactors = FALSE
  )
}

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
