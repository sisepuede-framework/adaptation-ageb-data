# 06_coneval.R -- CONEVAL 2020 social lag degree and its 17 indicators.
#
# The workbook is national, one sheet, with a three-level header. Data starts
# on row 6, so skip = 5 and columns are addressed positionally (the header
# cells are merged and unusable as names):
#   col  8  "Clave de la AGEB"  -- already ENT+MUN+LOC+AGEB, 13 characters
#   cols 11-27  the 17 rezago indicators, in the order listed below
#   col  28 "Grado de Rezago Social"
#
# This product exists for URBAN AGEB only. Rural AGEB keep NA in every column
# here, which is expected, not missing data (spec section 5.3). The continuous
# IRS index does not exist at AGEB level at all -- only the grade.

CONEVAL_COL_KEY    <- 8L
CONEVAL_COL_IND    <- 11:27
CONEVAL_COL_GRADE  <- 28L

# Names follow the spec's CSV schema; order matches columns 11..27 exactly.
RZ_NAMES <- c(
  "RZ_ANALF",   # 15+ illiterate
  "RZ_INA614",  # 6-14 not attending school
  "RZ_INA1524", # 15-24 not attending school
  "RZ_EBINC",   # 15+ incomplete basic education
  "RZ_SSALUD",  # without health service affiliation
  "RZ_HACIN",   # overcrowded dwellings
  "RZ_SAGUA",   # no piped water
  "RZ_SEXCUS",  # no toilet
  "RZ_SDREN",   # no drainage
  "RZ_SELEC",   # no electricity
  "RZ_PISOT",   # dirt floor
  "RZ_SLAVAD",  # no washing machine
  "RZ_SREFRI",  # no refrigerator
  "RZ_STELF",   # no landline
  "RZ_SCEL",    # no mobile phone
  "RZ_SCOMPU",  # no computer
  "RZ_SINTER"   # no internet
)

GRS_LEVELS <- c("Muy bajo", "Bajo", "Medio", "Alto", "Muy alto")

# Read once, cache nationally, then slice per entity.
load_coneval_national <- function() {
  cache <- file.path(DIR_INTERIM, "coneval_national.rds")
  if (file.exists(cache)) return(readRDS(cache))

  log_step("CONEVAL GRS (national workbook)")
  path <- find_file(file.path(DIR_RAW, "national", "coneval_grs"), "\\.xlsx$")

  # Everything as text: the AGEB key is alphanumeric and would lose its
  # leading zeros if readxl guessed numeric.
  raw <- readxl::read_excel(path, sheet = 1, skip = 5, col_names = FALSE,
                            col_types = "text", .name_repair = "minimal")

  out <- tibble(ID_AGEB = as.character(raw[[CONEVAL_COL_KEY]]))
  for (i in seq_along(CONEVAL_COL_IND)) {
    out[[RZ_NAMES[i]]] <- to_num_suppressed(raw[[CONEVAL_COL_IND[i]]])
  }
  out$GRS_GRADO <- str_trim(as.character(raw[[CONEVAL_COL_GRADE]]))
  out$GRS_NUM   <- match(out$GRS_GRADO, GRS_LEVELS)

  out <- out |>
    filter(!is.na(ID_AGEB), nchar(ID_AGEB) == 13) |>
    distinct(ID_AGEB, .keep_all = TRUE)

  log_msg("  national urban AGEB with GRS: ", nrow(out))
  saveRDS(out, cache)
  out
}

build_coneval <- function(ent) {
  log_step("CONEVAL ", ent)
  out <- load_coneval_national() |> filter(substr(ID_AGEB, 1, 2) == ent)
  log_msg("  rows: ", nrow(out))
  saveRDS(out, interim_path("coneval", ent))
  invisible(out)
}
