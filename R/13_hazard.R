# 13_hazard.R -- municipal hazard grades from CENAPRED's Sistema de Indicadores
# Municipales del Atlas Nacional de Riesgos, as republished by SEDATU on its
# spatial data infrastructure (situ.sedatu.gob.mx/descargas/?tema=riesgo).
#
# This is the "amenaza" module the README lists as pending. It does NOT feed the
# vulnerability index: following the IPCC AR6 framing (D-30), hazard is kept in
# its own AMZ_* columns so that vulnerability stays a property of the people and
# hazard a property of the place. Multiplying them is the analyst's decision,
# made downstream and explicitly.
#
# --- Why one WFS query per layer instead of the published downloads ---------
# SEDATU publishes each hazard as its own "dataset": 17 layers, each a ~38 MB
# GeoPackage. They are all the same table -- the 2,469 municipalities of the
# Marco Geoestadistico 2020 plus 30 sociodemographic fields from the 2020
# census -- and differ in exactly one column, the grade of that hazard. So the
# block asks GeoServer for the municipal key and that one column (~80 KB per
# layer, 15 layers) and leaves the geometry and the redundant census fields
# alone. The census fields are deliberately not imported: this database already
# computes the same variables at AGEB level, with suppression handled (D-13,
# D-15), and taking the municipal versions would mean publishing a coarser
# duplicate of its own indicators.
#
# --- What the grades are, and are not --------------------------------------
# They are ordinal labels (Muy bajo .. Muy alto) built by CENAPRED from its own
# hazard analyses, published per municipality. Three consequences:
#
#  * They are classes, not magnitudes. AMZ_INUND = 4 does not mean a flood
#    depth, a return period or twice the hazard of 2. Treat them as ordered
#    categories: rank, tabulate, cross with population; do not average across
#    different hazards as if the scales were commensurable.
#  * Each hazard has its own distribution, and they are not comparable between
#    columns. Measured on the 2,469 municipalities: flooding is spread almost
#    evenly across the five classes (492-496 each), landslide susceptibility
#    piles 1,692 municipalities into "Alto", snowfall leaves 2,318 in "Muy
#    bajo", and seismic hazard never uses "Muy bajo" at all. A "Muy alto" is
#    rare for drought (9 municipalities) and common for volcanic hazard (293).
#  * The resolution is municipal. Every AGEB in a municipality gets the same
#    value, so these columns carry no intra-municipal variation -- which is the
#    scale at which the rest of this database works. They place an AGEB's
#    municipality on a national hazard ranking; they do not say which block of
#    it floods.
#
# Volcanic hazard and the two hazardous-substance layers add a sixth label,
# "Sin Peligro", coded 0: a real absence of hazard (no volcano, no registered
# facility within reach), not a missing measurement. The labels are matched case-insensitively
# because the service spells it both "Sin Peligro" and "Sin peligro".

# Same five labels CONEVAL uses for the GRS, coded the same way (1..5, more is
# worse), so a reader who knows GRS_NUM already knows how to read AMZ_*.
# GRS_LEVELS lives in 06_coneval.R.
HAZARD_LEVELS <- GRS_LEVELS
HAZARD_NO_HAZARD_LABEL <- "Sin Peligro"

# CENAPRED covers every municipality of the 2020 marco, so the join must be
# complete; this is the count both layers agree on.
HAZARD_MUNICIPALITIES <- 2469L

# "Muy bajo".."Muy alto" -> 1..5, "Sin Peligro" -> 0. Blanks become NA; an
# unknown label stops the run instead of silently turning into NA, because a
# renamed class upstream would otherwise erase a whole hazard column.
hazard_grade_code <- function(x, col) {
  x <- str_trim(as.character(x))
  x[x == ""] <- NA_character_
  folded <- toupper(x)
  code <- ifelse(folded == toupper(HAZARD_NO_HAZARD_LABEL), 0L,
                 match(folded, toupper(HAZARD_LEVELS)))
  bad <- unique(x[!is.na(x) & is.na(code)])
  if (length(bad) > 0) {
    stop(col, ": unrecognised hazard grade(s) from CENAPRED: ",
         paste(sQuote(bad), collapse = ", "), call. = FALSE)
  }
  as.integer(code)
}

# CENAPRED's climate-change vulnerability flag is a yes/no, not a grade. Twelve
# municipalities carry a blank, which is left as NA rather than read as "No".
hazard_flag_code <- function(x, col) {
  x <- str_trim(as.character(x))
  x[x == ""] <- NA_character_
  # The service writes "Si" today; an accented "Si" would be the same answer.
  norm <- gsub("\u00cd", "I", toupper(x))
  code <- match(norm, c("NO", "SI"), nomatch = NA_integer_) - 1L
  bad <- unique(x[!is.na(x) & is.na(code)])
  if (length(bad) > 0) {
    stop(col, ": unrecognised flag value(s) from CENAPRED: ",
         paste(sQuote(bad), collapse = ", "), call. = FALSE)
  }
  as.integer(code)
}

hazard_raw_path <- function(col) {
  file.path(DIR_RAW, "national", "cenapred", paste0(col, ".csv"))
}

# Called from download_national() in 02_download.R, like every other source.
download_hazard <- function() {
  for (col in HAZARD_COLS) {
    src <- HAZARD_SOURCES[[col]]
    download_cached(url_sedatu_wfs(src[["layer"]], src[["field"]]),
                    hazard_raw_path(col))
  }
  invisible(TRUE)
}

# One row per municipality, one column per hazard. Built once, cached, sliced
# per entity afterwards -- the same pattern as the CONEVAL workbook.
load_hazard_national <- function() {
  cache <- file.path(DIR_INTERIM, "hazard_national.rds")
  if (file.exists(cache)) return(readRDS(cache))

  log_step("CENAPRED hazard grades (national)")
  out <- NULL
  for (col in HAZARD_COLS) {
    src <- HAZARD_SOURCES[[col]]
    path <- hazard_raw_path(col)
    if (!file.exists(path)) download_hazard()

    raw <- read_csv(path, col_types = cols(.default = col_character()),
                    locale = locale(encoding = "UTF-8"), progress = FALSE)
    missing_field <- setdiff(c("cve_munc", src[["field"]]), names(raw))
    if (length(missing_field) > 0) {
      stop("layer ", src[["layer"]], " no longer publishes ",
           paste(missing_field, collapse = ", "),
           "; check the catalog at situ.sedatu.gob.mx/descargas/?tema=riesgo",
           call. = FALSE)
    }

    values <- raw[[src[["field"]]]]
    one <- tibble(
      CVE_MUN_FULL = pad(raw$cve_munc, 5),
      VALUE = if (src[["scale"]] == "grado") hazard_grade_code(values, col)
              else hazard_flag_code(values, col)
    )
    names(one)[2] <- col

    if (anyDuplicated(one$CVE_MUN_FULL)) {
      stop("layer ", src[["layer"]], " repeats a municipal key", call. = FALSE)
    }
    out <- if (is.null(out)) one else full_join(out, one, by = "CVE_MUN_FULL")
  }

  if (nrow(out) != HAZARD_MUNICIPALITIES) {
    log_msg("  !! ", nrow(out), " municipalities across the layers, expected ",
            HAZARD_MUNICIPALITIES, ": the layers no longer share one municipal spine")
  }
  log_msg("  ", nrow(out), " municipalities x ", length(HAZARD_COLS), " columns")
  saveRDS(out, cache)
  out
}

build_hazard <- function(ent) {
  log_step("hazard ", ent)
  haz   <- load_hazard_national()
  attrs <- readRDS(interim_path("ageb_attrs", ent))

  out <- attrs |>
    select(ID_AGEB, CVE_MUN_FULL) |>
    left_join(haz, by = "CVE_MUN_FULL")

  # A municipality with no CENAPRED row leaves the whole block NA for its AGEB.
  # It is reported here and failed in 11_qc.R rather than stopped: the rest of
  # the entity is unaffected and still worth exporting.
  unmatched <- unique(out$CVE_MUN_FULL[is.na(out$AMZ_INUND)])
  if (length(unmatched) > 0) {
    log_msg("  !! ", length(unmatched), " municipalit",
            if (length(unmatched) == 1) "y" else "ies",
            " absent from the CENAPRED table: ",
            paste(head(unmatched, 5), collapse = ", "))
  }

  out <- out |> select(-CVE_MUN_FULL)
  if (anyDuplicated(out$ID_AGEB) || !setequal(out$ID_AGEB, attrs$ID_AGEB)) {
    stop("hazard grades do not map one-to-one onto the AGEB spine in entity ",
         ent, call. = FALSE)
  }

  log_msg("  ", nrow(out), " AGEB | municipalities matched: ",
          length(unique(attrs$CVE_MUN_FULL)) - length(unmatched), " of ",
          length(unique(attrs$CVE_MUN_FULL)))
  saveRDS(out, interim_path("hazard", ent))
  invisible(out)
}
