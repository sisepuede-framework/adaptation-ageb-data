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
  clues    = "2026-07",
  cem      = 2024L,  # CEM 4.0 publication; ALOS PALSAR radar of 2006-2011
  red_hidro = 2010L,
  costa    = 2018L,  # CONABIO coastline, RapidEye imagery of 2011-2014
  cenapred = 2023L
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

# CEM 4.0, INEGI's 15 m elevation model, one GeoTIFF per entity. The download
# endpoint is what the viewer at https://www.inegi.org.mx/app/geo2/elevacionesmex/
# calls (its api/archivo?version=2&opcion=15&clave=NN lists the file); the
# entidad parameter is ignored by the server. ~7.5 GB for the 32 entities.
# Verified 2026-09-16.
url_cem <- function(ent) sprintf(paste0(
  "https://www.inegi.org.mx/app/geo2/elevacionesmex/DownloadFile.do?",
  "file=e%s_cem_r15_v4_tif.zip&res=15&entidad=%s"), ent, ent)

# Red Hidrografica 1:50 000 edicion 2.0, one archive per hydrological region.
# The 37 regional products carry consecutive UPCs in the INEGI library
# (702825006976 Baja California Noroeste ... 702825007012 El Salado); each
# unpacks into subcuenca folders with {SUBC}_hl.shp flow lines. ~3.5 GB.
# Verified 2026-09-16.
RED_HIDRO_BASE <- paste0(
  "https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/",
  "bvinegi/productos/geografia/hidrogeolo/region_hidrografica")
RED_HIDRO_UPCS <- paste0("70282500", 6976:7012)
url_red_hidro <- function(upc) sprintf("%s/%s_s.zip", RED_HIDRO_BASE, upc)

# CONABIO coastline 1:25 000 (2011-2014). Segments described as "Frontera" are
# the land borders and are dropped. Verified 2026-09-16.
URL_COAST <- "http://www.conabio.gob.mx/informacion/gis/maps/geo/lc2018gw.zip"

# SEDATU republishes CENAPRED's municipal indicator system through the GeoNode
# behind situ.sedatu.gob.mx/descargas/?tema=riesgo. Each hazard is a separate
# "layer" whose GeoPackage weighs ~38 MB, but all of them carry the same
# municipal table and differ in a single column, so 13_hazard.R asks WFS for
# just that column (~80 KB per layer) instead of downloading 17 copies of the
# same polygons. Verified 2026-09-17.
URL_SEDATU_WFS <- "https://ide.sedatu.gob.mx/geoserver/ows"

# Output column -> the SEDATU layer it comes from, kept here rather than in
# 13_hazard.R because 12_export.R needs the column list while building the
# published schema and R sources the blocks in name order. How each field is
# read and coded lives in 13_hazard.R.
#
# Layer and field names are the ones GeoServer publishes;
# they are inconsistent upstream (pelig_ciclores, def_asoc_tarnsp) and are
# copied verbatim on purpose, typos included.
#
# The 13 AMZ_* columns are hazards. The last two are CENAPRED's own municipal
# judgements about the population, kept as external validation in the same
# spirit as the CONEVAL GRS (D-23): useful to contrast against what this
# database computes, never as an input to it.
HAZARD_SOURCES <- list(
  AMZ_INUND      = c(layer = "pel_inund",             field = "gp_inundac", scale = "grado"),
  AMZ_SEQUIA     = c(layer = "pelig_seq",             field = "gp_sequia2", scale = "grado"),
  AMZ_ONDA_CAL   = c(layer = "mun_ondas_calidas",     field = "gp_ondasca", scale = "grado"),
  AMZ_CICLON     = c(layer = "pelig_ciclores",        field = "gp_ciclnes", scale = "grado"),
  AMZ_DESLIZ     = c(layer = "suscept_lad_cenapred",  field = "susceplad",  scale = "grado"),
  AMZ_TORM_ELEC  = c(layer = "mun_tormentaselec",     field = "gp_tormele", scale = "grado"),
  AMZ_GRANIZO    = c(layer = "mun_peligro_gra",       field = "gp_granizo", scale = "grado"),
  AMZ_TEMP_BAJA  = c(layer = "pelig_temp_baja",       field = "gp_bajaste", scale = "grado"),
  AMZ_NEVADA     = c(layer = "peligro_neva_cenapred", field = "gp_nevadas", scale = "grado"),
  AMZ_SISMO      = c(layer = "pel_sismico",           field = "gp_sismico", scale = "grado"),
  AMZ_VOLCAN     = c(layer = "peligro_volcanico",     field = "volcanes",   scale = "grado"),
  AMZ_SUS_TOX    = c(layer = "mun_pel_tox_cenapred",  field = "gp_sustox",  scale = "grado"),
  AMZ_SUS_INFLA  = c(layer = "pel_sus_infla",         field = "gp_susinfl", scale = "grado"),
  CEN_RESIL      = c(layer = "mun_grado_resil",       field = "g_resilien", scale = "grado"),
  CEN_VULN_CC    = c(layer = "vulne_comb_clima",      field = "v_cc",       scale = "si_no")
)

HAZARD_COLS <- names(HAZARD_SOURCES)

url_sedatu_wfs <- function(layer, field) sprintf(
  paste0("%s?service=WFS&version=2.0.0&request=GetFeature&typeNames=geonode:%s",
         "&outputFormat=csv&propertyName=cve_munc,%s"),
  URL_SEDATU_WFS, layer, field)

# Terrain and flood-exposure parameters (09c_terrain.R).
# At 1:50 000 almost any point lies a few hundred metres from some first-order
# gully, so only streams of Strahler order >= 3 count as flood sources.
STREAM_MIN_ORDER  <- 3L
# Rural localities are points; slope and elevation are read over this radius,
# roughly a village core.
TERRAIN_BUFFER_M  <- 150
SLOPE_THRESHOLDS  <- c(15, 30)  # degrees
# The 1:50 000 flow lines and the 15 m DEM are not co-registered, so the
# stream's elevation is the lowest cell within this radius of the nearest point.
STREAM_BED_RADIUS_M <- 45

# A CLUES facility whose coordinates fall farther than this outside its own
# declared entity is a geocoding error (swapped signs, another state's
# coordinates) and is discarded; within it, a border town is given the benefit
# of the doubt. 97.4% of operating facilities fall inside their entity and 2.4%
# lie more than 5 km out, most of those hundreds of km away.
CLUES_ENTITY_TOL_KM <- 5

# Any download smaller than this is assumed to be an error page, not data.
MIN_DOWNLOAD_BYTES <- 10000L
