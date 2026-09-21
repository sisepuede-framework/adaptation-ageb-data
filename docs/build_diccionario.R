#!/usr/bin/env Rscript
# build_diccionario.R -- renders the data dictionary in Spanish and English:
#
#   docs/diccionario_datos.csv -> docs/DICCIONARIO_DATOS.md
#   docs/data_dictionary.csv   -> docs/DATA_DICTIONARY.md
#
#   Rscript docs/build_diccionario.R
#
# The two CSVs are the sources of truth: same rows, same order, text in each
# language (12_export.R refuses to export if their column lists drift apart).
# When the national CSV exists, coverage and medians are measured from it and
# printed next to each column; otherwise those cells are left out. Edit the
# CSVs, never the Markdown: the Markdown is overwritten on every run.

suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr) })

data_path <- "data/processed/ageb_indicadores_MX.csv"

# English CSV headers -> the internal (Spanish) field names used below.
EN_FIELDS <- c(
  TABLE = "TABLA", ORDER = "ORDEN", VARIABLE = "VARIABLE", BLOCK = "BLOQUE",
  DESCRIPTION = "DESCRIPCION", TYPE = "TIPO", UNIT = "UNIDAD",
  DECIMALS = "DECIMALES", SCOPE = "AMBITO", SOURCE = "FUENTE",
  SOURCE_VARIABLE = "VARIABLE_FUENTE", DERIVATION = "DERIVACION",
  UNIVERSE = "UNIVERSO", NA_MEANING = "NA_SIGNIFICA",
  CVI_DIMENSION = "DIMENSION_IVC", SUGGESTED_DIRECTION = "SENTIDO_SUGERIDO",
  SCRIPT = "SCRIPT", NOTES = "NOTAS")

# --- Coverage measured on the national table (shared by both languages) ----
stats <- NULL
if (file.exists(data_path)) {
  df <- read_csv(data_path, progress = FALSE, col_types = cols(
    .default = col_guess(), ID_AGEB = "c", CVE_ENT = "c", CVE_MUN = "c",
    CVE_LOC = "c", CVE_AGEB = "c", YEAR_DENUE = "c", YEAR_CLUES = "c"))
  urb <- df$AMBITO == "Urbana"
  rur_hab <- df$AMBITO == "Rural" & df$POB_TOTAL > 0
  # Coverage is measured on inhabited AGEB: uninhabited ones cannot carry a
  # share, and counting them would read as missing data.
  urb_hab <- urb & df$POB_TOTAL > 0
  fmt_num <- function(x) {
    if (is.na(x)) return("")
    if (abs(x) >= 1000) format(round(x), big.mark = ",") else format(signif(x, 4))
  }
  stats <- map_dfr(names(df), function(v) {
    x <- df[[v]]
    tibble(
      VARIABLE = v,
      COB_URB = sprintf("%.1f", 100 * mean(!is.na(x[urb_hab]))),
      COB_RUR = sprintf("%.1f", 100 * mean(!is.na(x[rur_hab]))),
      # Population-weighted: many rural AGEB lacking a share are hamlets of a
      # handful of people, so AGEB counts alone overstate the gap.
      POB_URB = sprintf("%.1f", 100 * sum(df$POB_TOTAL[urb_hab & !is.na(x)]) / sum(df$POB_TOTAL[urb_hab])),
      POB_RUR = sprintf("%.1f", 100 * sum(df$POB_TOTAL[rur_hab & !is.na(x)]) / sum(df$POB_TOTAL[rur_hab])),
      MEDIANA = if (is.numeric(x)) fmt_num(median(x[df$POB_TOTAL > 0], na.rm = TRUE)) else "",
      RANGO = if (is.numeric(x) && any(!is.na(x)))
        paste0(fmt_num(min(x, na.rm = TRUE)), " – ", fmt_num(max(x, na.rm = TRUE))) else ""
    )
  })
  stats_n <- format(nrow(df), big.mark = ",")
  stats_date <- format(file.mtime(data_path), "%Y-%m-%d")
}

esc <- function(x) gsub("|", "\\|", x, fixed = TRUE)
code <- function(x) ifelse(x == "", "", paste0("`", x, "`"))

# --- Language-specific text ---------------------------------------------------
TEXT <- list(
  es = list(
    dict_path = "docs/diccionario_datos.csv",
    out_path  = "docs/DICCIONARIO_DATOS.md",
    intro = c(
      "# Diccionario de datos",
      "",
      "<!-- Generado por docs/build_diccionario.R a partir de docs/diccionario_datos.csv. No editar a mano. -->",
      "",
      "*English version: [DATA_DICTIONARY.md](DATA_DICTIONARY.md).*",
      "",
      "Describe cada columna de las tablas que produce el pipeline. La fuente única es",
      "[`diccionario_datos.csv`](diccionario_datos.csv), que se puede leer desde R o Python;",
      "este documento se regenera con `Rscript docs/build_diccionario.R`. El *porqué* de",
      "cada regla está en [DECISIONES.md](DECISIONES.md) (identificadores `D-nn`) y las",
      "fuentes en [FUENTES.md](FUENTES.md).",
      "",
      "## Cómo leer este diccionario",
      "",
      "| Campo | Significado |",
      "|---|---|",
      "| `TIPO` | `texto`, `entero`, `decimal`, `decimal (conteo)`: conteo que puede traer .5 por la imputación urbana (D-15), `categórica`, `binaria`, `geometría` |",
      "| `UNIDAD` | Unidad física. Los porcentajes van de 0 a 100, no de 0 a 1 |",
      "| `DECIMALES` | Redondeo aplicado al exportar; vacío = sin redondeo |",
      "| `AMBITO` | `Ambos` o `Solo urbana` |",
      "| `FUENTE` | Identificador de [FUENTES.md](FUENTES.md); `PIPELINE` = calculada aquí |",
      "| `VARIABLE_FUENTE` | Nombre de la variable en la fuente original (mnemónico del INEGI, columna de CONEVAL, etc.) |",
      "| `DERIVACION` | Fórmula o regla de construcción |",
      "| `UNIVERSO` | Denominador de un porcentaje o promedio |",
      "| `NA_SIGNIFICA` | Por qué puede venir vacía (códigos abajo) |",
      "| `DIMENSION_IVC` | Papel **sugerido** en un índice de vulnerabilidad climática; no es una decisión tomada (D-30) |",
      "| `SENTIDO_SUGERIDO` | `+`: un valor mayor indica más vulnerabilidad; `−`: menos; `±`: ambiguo o depende de la amenaza; `n/a`: no aplica |",
      "",
      "**Códigos de `NA_SIGNIFICA`**",
      "",
      "| Código | Significado |",
      "|---|---|",
      "| `S` | **Supresión** del INEGI o CONEVAL: AGEB urbana suprimida entera (1–2 viviendas), o AGEB rural cuyas localidades suprimen todas ese grupo de variables (D-13, D-16) |",
      "| `E` | **Estructural**: el dato no existe para ese ámbito (p. ej. CONEVAL en AGEB rurales) |",
      "| `D0` | **Denominador cero**: el universo del porcentaje es 0 (p. ej. AGEB deshabitada, o sin población de 6–14 años) |",
      "| `C` | **No calculable** por geometría o coordenadas (se explica en la columna) |",
      "| `Nunca` | La columna siempre trae valor; un 0 es un cero real |",
      "",
      "**Advertencias generales**",
      "",
      "- Lee `ID_AGEB`, `CVE_ENT`, `CVE_MUN`, `CVE_LOC` y `CVE_AGEB` **como texto**.",
      "- Una AGEB rural deshabitada tiene `POB_TOTAL = 0` y sus conteos en 0; sus porcentajes quedan vacíos (`D0`).",
      "- En AGEB con universos minúsculos los porcentajes son ruido (K-01 en DECISIONES.md). Filtra o pondera por `POB_TOTAL`, `VIV_CARACT` o `PCT_POB_REPORTADA`.",
      "- Para reagregar a otra geografía suma **conteos**, nunca promedies porcentajes (D-25).",
      "- `PCT_VIV_SIN_DRENAJE` no es `100 − PCT_DRENAJE`, y está bien que no sumen 100 (D-19)."
    ),
    table_word = "Tabla", tables_title = "Tablas", file_word = "Archivo",
    cols_word = "Columnas",
    table_desc = c(
      ageb_indicadores       = "`data/processed/ageb_indicadores_{ENT}.csv` y `ageb_indicadores_MX.csv`. Una fila por AGEB urbana o rural.",
      ageb_integrada         = "`data/processed/base_ageb_MX.gpkg`, capa `ageb_integrada` (EPSG:4326), y `ageb_integrada_MX.csv`. Una fila por AGEB con todas las columnas de ageb_indicadores más las que se listan aquí; `ORDEN` es su posición en esa tabla. El GeoPackage también trae, como capas, las demás tablas de este diccionario en versión nacional.",
      ageb_geom              = "`data/processed/ageb_geom_{ENT}.gpkg`, capa `ageb`, EPSG:4326. Una fila por AGEB.",
      denue_establishments   = "`data/processed/denue_establishments_{ENT}.csv`. Una fila por establecimiento del DENUE.",
      denue_ageb_sector      = "`data/processed/denue_ageb_sector_{ENT}.csv`. Una fila por AGEB × sector SCIAN.",
      ageb_landuse_detail    = "`data/processed/ageb_landuse_detail_{ENT}.csv`. Una fila por AGEB × clase de uso de suelo.",
      quality_control_report = "`data/processed/quality_control_report_{ENT}.csv` y `_MX.csv`. Una fila por control.",
      qc_municipal_coverage  = "`data/processed/qc_municipal_coverage_{ENT}.csv`. Una fila por municipio."),
    stats_note = paste0(
      "Cobertura y mediana medidas sobre `%s` (%s AGEB, generado el %s). ",
      "La cobertura se mide sobre AGEB **habitadas**, como %% de AGEB con valor y como %% ",
      "de su población; la mediana y el rango también se miden sobre AGEB habitadas."),
    head_stats = "| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |",
    head_plain = "| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | Sentido |",
    cards_title = "## Fichas de ageb_indicadores",
    cards_intro = "Una ficha por columna, en el orden del CSV.",
    card = c(field = "Campo", value = "Valor", BLOQUE = "Bloque", TIPO = "Tipo",
             UNIDAD = "Unidad", DECIMALES = "Decimales", AMBITO = "Ámbito",
             FUENTE = "Fuente", VARIABLE_FUENTE = "Variable en la fuente",
             DERIVACION = "Derivación", UNIVERSO = "Universo",
             NA_SIGNIFICA = "Valores vacíos", DIMENSION_IVC = "Dimensión sugerida",
             SENTIDO_SUGERIDO = "Sentido sugerido", SCRIPT = "Script",
             cob = "AGEB habitadas con dato (urbana / rural)",
             pob = "Población con dato (urbana / rural)",
             med = "Mediana (AGEB habitadas)", rango = "Rango", NOTAS = "Notas"),
    head_secondary = "| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |",
    message_nostats = ", no coverage stats: national CSV not found"
  ),
  en = list(
    dict_path = "docs/data_dictionary.csv",
    out_path  = "docs/DATA_DICTIONARY.md",
    intro = c(
      "# Data dictionary",
      "",
      "<!-- Generated by docs/build_diccionario.R from docs/data_dictionary.csv. Do not edit by hand. -->",
      "",
      "*Versión en español: [DICCIONARIO_DATOS.md](DICCIONARIO_DATOS.md).*",
      "",
      "Describes every column of the tables the pipeline produces. The source of truth is",
      "[`data_dictionary.csv`](data_dictionary.csv), readable from R or Python, kept row for",
      "row in step with the Spanish [`diccionario_datos.csv`](diccionario_datos.csv); this",
      "document is regenerated with `Rscript docs/build_diccionario.R`. The *why* behind each",
      "rule is in [DECISIONES.md](DECISIONES.md) (identifiers `D-nn`) and the sources in",
      "[FUENTES.md](FUENTES.md), both in Spanish.",
      "",
      "Column **names** and **data values** are in Spanish, exactly as they appear in the",
      "CSV: `AMBITO` holds `Urbana` or `Rural`, `GRS_GRADO` holds `Muy bajo` to `Muy alto`,",
      "`DIST_ORIGEN` holds `Localidades` or `Punto interior`. AGEB (*Área Geoestadística",
      "Básica*) is INEGI's census tract.",
      "",
      "## How to read this dictionary",
      "",
      "| Field | Meaning |",
      "|---|---|",
      "| `TYPE` | `text`, `integer`, `decimal`, `decimal (count)`: a count that may carry .5 from urban imputation (D-15), `categorical`, `binary`, `geometry` |",
      "| `UNIT` | Physical unit. Shares run from 0 to 100, not 0 to 1 |",
      "| `DECIMALS` | Rounding applied on export; empty = unrounded |",
      "| `SCOPE` | `Both` (urban and rural AGEB) or `Urban only` |",
      "| `SOURCE` | Identifier from [FUENTES.md](FUENTES.md); `PIPELINE` = computed here |",
      "| `SOURCE_VARIABLE` | Variable name in the original source (INEGI mnemonic, CONEVAL column, etc.) |",
      "| `DERIVATION` | Formula or construction rule |",
      "| `UNIVERSE` | Denominator of a share or average |",
      "| `NA_MEANING` | Why it may be empty (codes below) |",
      "| `CVI_DIMENSION` | **Suggested** role in a climate vulnerability index; not a decision taken (D-30) |",
      "| `SUGGESTED_DIRECTION` | `+`: a higher value means more vulnerability; `−`: less; `±`: ambiguous or hazard-dependent; `n/a`: not applicable |",
      "",
      "**`NA_MEANING` codes**",
      "",
      "| Code | Meaning |",
      "|---|---|",
      "| `S` | **Suppression** by INEGI or CONEVAL: urban AGEB suppressed as a whole (1–2 dwellings), or rural AGEB whose localities all suppress that group of variables (D-13, D-16) |",
      "| `E` | **Structural**: the data does not exist for that setting (e.g. CONEVAL in rural AGEB) |",
      "| `D0` | **Zero denominator**: the universe of the share is 0 (e.g. an uninhabited AGEB, or one with no population aged 6–14) |",
      "| `C` | **Not computable** from geometry or coordinates (explained in the column) |",
      "| `Never` | The column always has a value; a 0 is a true zero |",
      "",
      "**General warnings**",
      "",
      "- Read `ID_AGEB`, `CVE_ENT`, `CVE_MUN`, `CVE_LOC` and `CVE_AGEB` **as text**.",
      "- An uninhabited rural AGEB has `POB_TOTAL = 0` and its counts at 0; its shares are empty (`D0`).",
      "- In AGEB with tiny universes the shares are noise (K-01 in DECISIONES.md). Filter or weight by `POB_TOTAL`, `VIV_CARACT` or `PCT_POB_REPORTADA`.",
      "- To re-aggregate to another geography, sum **counts**; never average shares (D-25).",
      "- `PCT_VIV_SIN_DRENAJE` is not `100 − PCT_DRENAJE`, and it is expected that they do not add up to 100 (D-19)."
    ),
    table_word = "Table", tables_title = "Tables", file_word = "File",
    cols_word = "Columns",
    table_desc = c(
      ageb_indicadores       = "`data/processed/ageb_indicadores_{ENT}.csv` and `ageb_indicadores_MX.csv`. One row per urban or rural AGEB.",
      ageb_integrada         = "`data/processed/base_ageb_MX.gpkg`, layer `ageb_integrada` (EPSG:4326), and `ageb_integrada_MX.csv`. One row per AGEB with every ageb_indicadores column plus the ones listed here; `ORDER` is their position in that table. The GeoPackage also carries, as layers, the national version of the other tables in this dictionary.",
      ageb_geom              = "`data/processed/ageb_geom_{ENT}.gpkg`, layer `ageb`, EPSG:4326. One row per AGEB.",
      denue_establishments   = "`data/processed/denue_establishments_{ENT}.csv`. One row per DENUE establishment.",
      denue_ageb_sector      = "`data/processed/denue_ageb_sector_{ENT}.csv`. One row per AGEB × SCIAN sector.",
      ageb_landuse_detail    = "`data/processed/ageb_landuse_detail_{ENT}.csv`. One row per AGEB × land use class.",
      quality_control_report = "`data/processed/quality_control_report_{ENT}.csv` and `_MX.csv`. One row per check.",
      qc_municipal_coverage  = "`data/processed/qc_municipal_coverage_{ENT}.csv`. One row per municipality."),
    stats_note = paste0(
      "Coverage and median measured on `%s` (%s AGEB, generated on %s). ",
      "Coverage is measured on **inhabited** AGEB, as the %% of AGEB with a value and as the %% ",
      "of their population; the median and range are also measured on inhabited AGEB."),
    head_stats = "| # | Variable | Description | Unit | Scope | Source variable | % AGEB with value (urb / rur) | % population with value (urb / rur) | Median | Direction |",
    head_plain = "| # | Variable | Description | Unit | Scope | Source variable | Direction |",
    cards_title = "## ageb_indicadores column cards",
    cards_intro = "One card per column, in CSV order.",
    card = c(field = "Field", value = "Value", BLOQUE = "Block", TIPO = "Type",
             UNIDAD = "Unit", DECIMALES = "Decimals", AMBITO = "Scope",
             FUENTE = "Source", VARIABLE_FUENTE = "Source variable",
             DERIVACION = "Derivation", UNIVERSO = "Universe",
             NA_SIGNIFICA = "Empty values", DIMENSION_IVC = "Suggested dimension",
             SENTIDO_SUGERIDO = "Suggested direction", SCRIPT = "Script",
             cob = "Inhabited AGEB with value (urban / rural)",
             pob = "Population with value (urban / rural)",
             med = "Median (inhabited AGEB)", rango = "Range", NOTAS = "Notes"),
    head_secondary = "| # | Variable | Description | Type | Unit | Source | Derivation | Notes |",
    message_nostats = ", no coverage stats: national CSV not found"
  )
)

render <- function(lang) {
  T <- TEXT[[lang]]
  dict <- read_csv(T$dict_path, col_types = cols(.default = col_character()),
                   locale = locale(encoding = "UTF-8"), progress = FALSE) |>
    mutate(across(everything(), ~ coalesce(.x, "")))
  if (lang == "en") dict <- dict |> rename(!!!setNames(names(EN_FIELDS), EN_FIELDS))

  lines <- c(T$intro, "",
             "```r",
             "readr::read_csv(\"data/processed/ageb_indicadores_MX.csv\",",
             "                col_types = readr::cols(ID_AGEB = \"c\", CVE_ENT = \"c\", CVE_MUN = \"c\",",
             "                                        CVE_LOC = \"c\", CVE_AGEB = \"c\"))",
             "```",
             "")

  tables <- unique(dict$TABLA)
  lines <- c(lines, paste0("## ", T$tables_title), "",
             sprintf("| %s | %s | %s |", T$table_word, T$file_word, T$cols_word), "|---|---|---|",
             map_chr(tables, \(t) sprintf("| [%s](#tabla-%s) | %s | %d |", t,
                                          gsub("_", "-", t), T$table_desc[[t]],
                                          sum(dict$TABLA == t))), "")

  main <- dict |> filter(TABLA == "ageb_indicadores")
  # A column documented here but not yet present in the national CSV -- one
  # added after the last national run -- gets empty cells instead of failing.
  if (!is.null(stats)) main <- main |> left_join(stats, by = "VARIABLE") |>
    mutate(across(c(COB_URB, COB_RUR, POB_URB, POB_RUR, MEDIANA, RANGO),
                  ~ coalesce(.x, "")))

  lines <- c(lines, "<a id=\"tabla-ageb-indicadores\"></a>",
             paste0("## ", T$table_word, " ageb_indicadores"), "",
             T$table_desc[["ageb_indicadores"]], "")
  if (!is.null(stats)) lines <- c(lines, sprintf(T$stats_note, data_path, stats_n, stats_date), "")

  for (blk in unique(main$BLOQUE)) {
    sub <- main |> filter(BLOQUE == blk)
    lines <- c(lines, paste0("### ", blk), "")
    if (!is.null(stats)) {
      lines <- c(lines, T$head_stats,
        "|---|---|---|---|---|---|---|---|---|---|",
        sprintf("| %s | [`%s`](#%s) | %s | %s | %s | %s | %s / %s | %s / %s | %s | %s |",
                sub$ORDEN, sub$VARIABLE, tolower(sub$VARIABLE), esc(sub$DESCRIPCION),
                sub$UNIDAD, sub$AMBITO, code(sub$VARIABLE_FUENTE) |> esc(),
                sub$COB_URB, sub$COB_RUR, sub$POB_URB, sub$POB_RUR, sub$MEDIANA,
                sub$SENTIDO_SUGERIDO))
    } else {
      lines <- c(lines, T$head_plain,
        "|---|---|---|---|---|---|---|",
        sprintf("| %s | [`%s`](#%s) | %s | %s | %s | %s | %s |",
                sub$ORDEN, sub$VARIABLE, tolower(sub$VARIABLE), esc(sub$DESCRIPCION),
                sub$UNIDAD, sub$AMBITO, code(sub$VARIABLE_FUENTE) |> esc(),
                sub$SENTIDO_SUGERIDO))
    }
    lines <- c(lines, "")
  }

  lines <- c(lines, T$cards_title, "", T$cards_intro, "")

  C <- T$card
  field <- function(label, value) if (value == "") character(0) else
    sprintf("| %s | %s |", label, esc(value))

  pair_pct <- function(a, b) if (a == "" || b == "") "" else
    sprintf("%s %% / %s %%", a, b)

  for (i in seq_len(nrow(main))) {
    r <- main[i, ]
    lines <- c(lines,
      sprintf("<a id=\"%s\"></a>", tolower(r$VARIABLE)),
      sprintf("#### %s. `%s`", r$ORDEN, r$VARIABLE), "",
      r$DESCRIPCION, "",
      sprintf("| %s | %s |", C[["field"]], C[["value"]]), "|---|---|",
      field(C[["BLOQUE"]], r$BLOQUE),
      field(C[["TIPO"]], r$TIPO),
      field(C[["UNIDAD"]], r$UNIDAD),
      field(C[["DECIMALES"]], r$DECIMALES),
      field(C[["AMBITO"]], r$AMBITO),
      field(C[["FUENTE"]], r$FUENTE),
      field(C[["VARIABLE_FUENTE"]], code(r$VARIABLE_FUENTE)),
      field(C[["DERIVACION"]], r$DERIVACION),
      field(C[["UNIVERSO"]], r$UNIVERSO),
      field(C[["NA_SIGNIFICA"]], r$NA_SIGNIFICA),
      field(C[["DIMENSION_IVC"]], r$DIMENSION_IVC),
      field(C[["SENTIDO_SUGERIDO"]], r$SENTIDO_SUGERIDO),
      field(C[["SCRIPT"]], r$SCRIPT),
      if (!is.null(stats)) field(C[["cob"]], pair_pct(r$COB_URB, r$COB_RUR)),
      if (!is.null(stats)) field(C[["pob"]], pair_pct(r$POB_URB, r$POB_RUR)),
      if (!is.null(stats)) field(C[["med"]], r$MEDIANA),
      if (!is.null(stats)) field(C[["rango"]], r$RANGO),
      field(C[["NOTAS"]], r$NOTAS),
      "")
  }

  for (t in setdiff(tables, "ageb_indicadores")) {
    sub <- dict |> filter(TABLA == t)
    lines <- c(lines,
      sprintf("<a id=\"tabla-%s\"></a>", gsub("_", "-", t)),
      paste0("## ", T$table_word, " ", t), "", T$table_desc[[t]], "",
      T$head_secondary,
      "|---|---|---|---|---|---|---|---|",
      sprintf("| %s | `%s` | %s | %s | %s | %s | %s | %s |",
              sub$ORDEN, sub$VARIABLE, esc(sub$DESCRIPCION), sub$TIPO, sub$UNIDAD,
              sub$FUENTE, esc(sub$DERIVACION), esc(sub$NOTAS)),
      "")
  }

  # Binary mode keeps LF line endings on Windows too, so the Markdown does not
  # show up as changed in git after a regeneration there.
  con <- file(T$out_path, "wb")
  writeLines(lines, con, useBytes = TRUE)
  close(con)
  message("wrote ", T$out_path, " (", nrow(dict), " columns documented",
          if (is.null(stats)) T$message_nostats else "", ")")
  dict
}

es <- render("es")
en <- render("en")
if (!identical(es[c("TABLA", "ORDEN", "VARIABLE")], en[c("TABLA", "ORDEN", "VARIABLE")])) {
  stop("docs/data_dictionary.csv is out of step with docs/diccionario_datos.csv: ",
       "both must list the same tables and variables in the same order", call. = FALSE)
}
