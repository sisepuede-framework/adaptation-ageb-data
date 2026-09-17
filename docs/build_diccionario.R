#!/usr/bin/env Rscript
# build_diccionario.R -- renders docs/DICCIONARIO_DATOS.md from
# docs/diccionario_datos.csv, the single source of truth for column metadata.
#
#   Rscript docs/build_diccionario.R
#
# When the national CSV exists, coverage and medians are measured from it and
# printed next to each column; otherwise those cells are left out. Edit the CSV,
# never the Markdown: the Markdown is overwritten on every run.

suppressPackageStartupMessages({ library(dplyr); library(readr); library(purrr) })

dict_path <- "docs/diccionario_datos.csv"
out_path  <- "docs/DICCIONARIO_DATOS.md"
data_path <- "data/processed/ageb_indicadores_MX.csv"

dict <- read_csv(dict_path, col_types = cols(.default = col_character()),
                 locale = locale(encoding = "UTF-8"), progress = FALSE) |>
  mutate(across(everything(), ~ coalesce(.x, "")))

# --- Coverage measured on the national table --------------------------------
stats <- NULL
if (file.exists(data_path)) {
  df <- read_csv(data_path, progress = FALSE, col_types = cols(
    .default = col_guess(), ID_AGEB = "c", CVE_ENT = "c", CVE_MUN = "c",
    CVE_LOC = "c", CVE_AGEB = "c", YEAR_DENUE = "c"))
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
  stats_note <- sprintf(paste0(
    "Cobertura y mediana medidas sobre `%s` (%s AGEB, generado el %s). ",
    "La cobertura se mide sobre AGEB **habitadas**, como %% de AGEB con valor y como %% ",
    "de su población; la mediana y el rango también se miden sobre AGEB habitadas."),
    data_path, format(nrow(df), big.mark = ","),
    format(file.mtime(data_path), "%Y-%m-%d"))
}

esc <- function(x) gsub("|", "\\|", x, fixed = TRUE)
code <- function(x) ifelse(x == "", "", paste0("`", x, "`"))

lines <- c(
  "# Diccionario de datos",
  "",
  "<!-- Generado por docs/build_diccionario.R a partir de docs/diccionario_datos.csv. No editar a mano. -->",
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
  "- `PCT_VIV_SIN_DRENAJE` no es `100 − PCT_DRENAJE`, y está bien que no sumen 100 (D-19).",
  "",
  "```r",
  "readr::read_csv(\"data/processed/ageb_indicadores_MX.csv\",",
  "                col_types = readr::cols(ID_AGEB = \"c\", CVE_ENT = \"c\", CVE_MUN = \"c\",",
  "                                        CVE_LOC = \"c\", CVE_AGEB = \"c\"))",
  "```",
  ""
)

tables <- unique(dict$TABLA)
table_desc <- c(
  ageb_indicadores       = "`data/processed/ageb_indicadores_{ENT}.csv` y `ageb_indicadores_MX.csv`. Una fila por AGEB urbana o rural.",
  ageb_geom              = "`data/processed/ageb_geom_{ENT}.gpkg`, capa `ageb`, EPSG:4326. Una fila por AGEB.",
  denue_establishments   = "`data/processed/denue_establishments_{ENT}.csv`. Una fila por establecimiento del DENUE.",
  denue_ageb_sector      = "`data/processed/denue_ageb_sector_{ENT}.csv`. Una fila por AGEB × sector SCIAN.",
  ageb_landuse_detail    = "`data/processed/ageb_landuse_detail_{ENT}.csv`. Una fila por AGEB × clase de uso de suelo.",
  quality_control_report = "`data/processed/quality_control_report_{ENT}.csv` y `_MX.csv`. Una fila por control.",
  qc_municipal_coverage  = "`data/processed/qc_municipal_coverage_{ENT}.csv`. Una fila por municipio."
)

lines <- c(lines, "## Tablas", "", "| Tabla | Archivo | Columnas |", "|---|---|---|",
           map_chr(tables, \(t) sprintf("| [%s](#tabla-%s) | %s | %d |", t,
                                        gsub("_", "-", t), table_desc[[t]],
                                        sum(dict$TABLA == t))), "")

# --- Main table: summary per block, then one card per column ---------------
main <- dict |> filter(TABLA == "ageb_indicadores")
if (!is.null(stats)) main <- main |> left_join(stats, by = "VARIABLE")

lines <- c(lines, "<a id=\"tabla-ageb-indicadores\"></a>",
           "## Tabla ageb_indicadores", "", table_desc[["ageb_indicadores"]], "")
if (!is.null(stats)) lines <- c(lines, stats_note, "")

for (blk in unique(main$BLOQUE)) {
  sub <- main |> filter(BLOQUE == blk)
  lines <- c(lines, paste0("### ", blk), "")
  if (!is.null(stats)) {
    lines <- c(lines,
      "| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | % AGEB con dato (urb / rur) | % población con dato (urb / rur) | Mediana | Sentido |",
      "|---|---|---|---|---|---|---|---|---|---|",
      sprintf("| %s | [`%s`](#%s) | %s | %s | %s | %s | %s / %s | %s / %s | %s | %s |",
              sub$ORDEN, sub$VARIABLE, tolower(sub$VARIABLE), esc(sub$DESCRIPCION),
              sub$UNIDAD, sub$AMBITO, code(sub$VARIABLE_FUENTE) |> esc(),
              sub$COB_URB, sub$COB_RUR, sub$POB_URB, sub$POB_RUR, sub$MEDIANA,
              sub$SENTIDO_SUGERIDO))
  } else {
    lines <- c(lines,
      "| # | Variable | Descripción | Unidad | Ámbito | Variable fuente | Sentido |",
      "|---|---|---|---|---|---|---|",
      sprintf("| %s | [`%s`](#%s) | %s | %s | %s | %s | %s |",
              sub$ORDEN, sub$VARIABLE, tolower(sub$VARIABLE), esc(sub$DESCRIPCION),
              sub$UNIDAD, sub$AMBITO, code(sub$VARIABLE_FUENTE) |> esc(),
              sub$SENTIDO_SUGERIDO))
  }
  lines <- c(lines, "")
}

lines <- c(lines, "## Fichas de ageb_indicadores", "",
           "Una ficha por columna, en el orden del CSV.", "")

field <- function(label, value) if (value == "") character(0) else
  sprintf("| %s | %s |", label, esc(value))

for (i in seq_len(nrow(main))) {
  r <- main[i, ]
  lines <- c(lines,
    sprintf("<a id=\"%s\"></a>", tolower(r$VARIABLE)),
    sprintf("#### %s. `%s`", r$ORDEN, r$VARIABLE), "",
    r$DESCRIPCION, "",
    "| Campo | Valor |", "|---|---|",
    field("Bloque", r$BLOQUE),
    field("Tipo", r$TIPO),
    field("Unidad", r$UNIDAD),
    field("Decimales", r$DECIMALES),
    field("Ámbito", r$AMBITO),
    field("Fuente", r$FUENTE),
    field("Variable en la fuente", code(r$VARIABLE_FUENTE)),
    field("Derivación", r$DERIVACION),
    field("Universo", r$UNIVERSO),
    field("Valores vacíos", r$NA_SIGNIFICA),
    field("Dimensión sugerida", r$DIMENSION_IVC),
    field("Sentido sugerido", r$SENTIDO_SUGERIDO),
    field("Script", r$SCRIPT),
    if (!is.null(stats)) field("AGEB habitadas con dato (urbana / rural)",
                               sprintf("%s %% / %s %%", r$COB_URB, r$COB_RUR)),
    if (!is.null(stats)) field("Población con dato (urbana / rural)",
                               sprintf("%s %% / %s %%", r$POB_URB, r$POB_RUR)),
    if (!is.null(stats)) field("Mediana (AGEB habitadas)", r$MEDIANA),
    if (!is.null(stats)) field("Rango", r$RANGO),
    field("Notas", r$NOTAS),
    "")
}

# --- Secondary tables: one compact table each --------------------------------
for (t in setdiff(tables, "ageb_indicadores")) {
  sub <- dict |> filter(TABLA == t)
  lines <- c(lines,
    sprintf("<a id=\"tabla-%s\"></a>", gsub("_", "-", t)),
    paste0("## Tabla ", t), "", table_desc[[t]], "",
    "| # | Variable | Descripción | Tipo | Unidad | Fuente | Derivación | Notas |",
    "|---|---|---|---|---|---|---|---|",
    sprintf("| %s | `%s` | %s | %s | %s | %s | %s | %s |",
            sub$ORDEN, sub$VARIABLE, esc(sub$DESCRIPCION), sub$TIPO, sub$UNIDAD,
            sub$FUENTE, esc(sub$DERIVACION), esc(sub$NOTAS)),
    "")
}

writeLines(lines, out_path, useBytes = TRUE)
message("wrote ", out_path, " (", nrow(dict), " columns documented",
        if (is.null(stats)) ", no coverage stats: national CSV not found" else "", ")")
