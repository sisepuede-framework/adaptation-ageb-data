# 00_config.R -- paths, entity catalog, CRS, source URLs and tolerances.
# All configuration lives here; no other script should hardcode a URL or a path.

PROJECT_ROOT <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."),
                              mustWork = FALSE)

# Resolve project root robustly whether sourced or run via Rscript.
if (!dir.exists(file.path(PROJECT_ROOT, "R"))) PROJECT_ROOT <- normalizePath(getwd())

DIR_RAW       <- file.path(PROJECT_ROOT, "data", "raw")
DIR_INTERIM   <- file.path(PROJECT_ROOT, "data", "interim")
DIR_PROCESSED <- file.path(PROJECT_ROOT, "data", "processed")
DIR_LOGS      <- file.path(PROJECT_ROOT, "logs")

for (d in c(DIR_RAW, DIR_INTERIM, DIR_PROCESSED, DIR_LOGS)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# --- Coordinate reference systems (spec section 4) -------------------------
CRS_SOURCE   <- 4326L  # as distributed
CRS_ANALYSIS <- 6372L  # Mexico ITRF2008 LCC -- areas and distances
CRS_OUTPUT   <- 4326L  # as published

# --- Reference year per source (spec section 7) ---------------------------
YEARS <- list(
  geometry = 2020L,
  census   = 2020L,
  coneval  = 2020L,
  denue    = "2026-05",
  hidro    = 2018L,
  usv      = 2021L,
  clues    = "2026-07"
)

# --- Entity catalog -------------------------------------------------------
# Slugs match the file names published under the INEGI Marco Geoestadistico
# product folder; they are NOT derivable from the entity name.
ENTITY_SLUGS <- c(
  "01" = "01_aguascalientes",
  "02" = "02_bajacalifornia",
  "03" = "03_bajacaliforniasur",
  "04" = "04_campeche",
  "05" = "05_coahuiladezaragoza",
  "06" = "06_colima",
  "07" = "07_chiapas",
  "08" = "08_chihuahua",
  "09" = "09_ciudaddemexico",
  "10" = "10_durango",
  "11" = "11_guanajuato",
  "12" = "12_guerrero",
  "13" = "13_hidalgo",
  "14" = "14_jalisco",
  "15" = "15_mexico",
  "16" = "16_michoacandeocampo",
  "17" = "17_morelos",
  "18" = "18_nayarit",
  "19" = "19_nuevoleon",
  "20" = "20_oaxaca",
  "21" = "21_puebla",
  "22" = "22_queretaro",
  "23" = "23_quintanaroo",
  "24" = "24_sanluispotosi",
  "25" = "25_sinaloa",
  "26" = "26_sonora",
  "27" = "27_tabasco",
  "28" = "28_tamaulipas",
  "29" = "29_tlaxcala",
  "30" = "30_veracruzignaciodelallave",
  "31" = "31_yucatan",
  "32" = "32_zacatecas"
)

ENTITY_NAMES <- c(
  "01" = "Aguascalientes", "02" = "Baja California",
  "03" = "Baja California Sur", "04" = "Campeche",
  "05" = "Coahuila de Zaragoza", "06" = "Colima",
  "07" = "Chiapas", "08" = "Chihuahua",
  "09" = "Ciudad de Mexico", "10" = "Durango",
  "11" = "Guanajuato", "12" = "Guerrero",
  "13" = "Hidalgo", "14" = "Jalisco",
  "15" = "Mexico", "16" = "Michoacan de Ocampo",
  "17" = "Morelos", "18" = "Nayarit",
  "19" = "Nuevo Leon", "20" = "Oaxaca",
  "21" = "Puebla", "22" = "Queretaro",
  "23" = "Quintana Roo", "24" = "San Luis Potosi",
  "25" = "Sinaloa", "26" = "Sonora",
  "27" = "Tabasco", "28" = "Tamaulipas",
  "29" = "Tlaxcala", "30" = "Veracruz de Ignacio de la Llave",
  "31" = "Yucatan", "32" = "Zacatecas"
)

ENTITIES <- names(ENTITY_SLUGS)

# --- Source URLs ----------------------------------------------------------
# NOTE: the national Marco Geoestadistico URL quoted in the project spec
# (.../marcogeo/889463807469_s.zip) is a dead link. INEGI answers it with an
# HTTP 200 "Esta liga ya no existe" HTML page, which is what earlier attempts
# mistook for a 503. The live downloads are per-entity, inside a folder named
# after the product id. Verified 2026-09-15.
MG_BASE <- paste0(
  "https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/",
  "bvinegi/productos/geografia/marcogeo/889463807469"
)

url_marco_geo <- function(ent) sprintf("%s/%s.zip", MG_BASE, ENTITY_SLUGS[[ent]])

url_census_urban <- function(ent) sprintf(
  paste0("https://www.inegi.org.mx/contenidos/programas/ccpv/2020/datosabiertos/",
         "ageb_manzana/ageb_mza_urbana_%s_cpv2020_csv.zip"), ent)

url_iter <- function(ent) sprintf(
  paste0("https://www.inegi.org.mx/contenidos/programas/ccpv/2020/datosabiertos/",
         "iter/iter_%s_cpv2020_csv.zip"), ent)

DENUE_BASE <- "https://www.inegi.org.mx/contenidos/masiva/denue"

url_denue <- function(ent) sprintf("%s/denue_%s_csv.zip", DENUE_BASE, ent)

# INEGI splits the largest entities across numbered files: entity 15 ships as
# denue_15_1_csv.zip + denue_15_2_csv.zip and the unsuffixed name 404s. Probing
# is cheap and keeps the split states from being special-cased downstream.
url_denue_part <- function(ent, part) {
  sprintf("%s/denue_%s_%d_csv.zip", DENUE_BASE, ent, part)
}

DENUE_MAX_PARTS <- 6L

# National, downloaded once and read per-entity with a bbox filter.
URL_CONEVAL_GRS <- paste0("https://www.coneval.org.mx/Medicion/Documents/",
                          "GRS_AGEB_2020/GRS_AGEB_urbana_2020.zip")
URL_MUNICIPIOS  <- "http://www.conabio.gob.mx/informacion/gis/maps/geo/mun22gw.zip"
URL_LANDUSE     <- "http://www.conabio.gob.mx/informacion/gis/maps/geo/usv250s7gw.zip"
URL_WATER       <- "http://www.conabio.gob.mx/informacion/gis/maps/geo/catp50s3gw.zip"

# CLUES, the Secretaria de Salud master catalog of health facilities. DGIS
# republishes it monthly under a dated name and links only the latest from
# http://www.dgis.salud.gob.mx/contenidos/intercambio/clues_gobmx.html, so the
# snapshot is pinned here (and in YEARS$clues). When it 404s, take the current
# link from that page and update both. Verified 2026-09-16.
URL_CLUES  <- paste0("http://gobi.salud.gob.mx/gobi/catalogos/catalogosmaestros/",
                     "ESTABLECIMIENTO_SALUD_202607.xlsx")
CLUES_FILE <- "ESTABLECIMIENTO_SALUD_202607.xlsx"

# --- Quality control tolerances (spec section 8) --------------------------
COVERAGE_TOL_PCT <- 1.0   # municipal area vs. summed AGEB area
# A purely relative tolerance is unusable for the smallest municipalities: a
# ~0.05 km2 edge-digitisation difference between the AGEB and municipal layers
# is >1% of a 3 km2 municipality but is not a coverage gap. A municipality
# fails only when it breaches BOTH the relative and the absolute tolerance.
COVERAGE_TOL_KM2 <- 0.5
POP_SUM_TOL_PCT  <- 1.0   # POB_HOMBRES + POB_MUJERES vs. POB_TOTAL
VIV_TOL_PCT      <- 1.0   # VPH_* vs. TVIVPARHAB rounding slack

# A CLUES facility whose coordinates fall farther than this outside its own
# declared entity is a geocoding error (swapped signs, another state's
# coordinates) and is discarded; within it, a border town is given the benefit
# of the doubt. 97.4% of operating facilities fall inside their entity and 2.4%
# lie more than 5 km out, most of those hundreds of km away.
CLUES_ENTITY_TOL_KM <- 5

# Any download smaller than this is assumed to be an error page, not data.
MIN_DOWNLOAD_BYTES <- 10000L
