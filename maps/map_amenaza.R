#!/usr/bin/env Rscript
# map_amenaza.R -- sample maps of the CENAPRED hazard grades (13_hazard.R).
#
#   Rscript maps/map_amenaza.R              # national + the default metro zoom
#   Rscript maps/map_amenaza.R 14 039 120   # zoom on other municipalities
#
# Two figures, because one map cannot say both things:
#
# Both land in maps/png/.
#
#   amenaza_nacional.png  where each hazard is concentrated, by municipality.
#   amenaza_zoom_*.png    what that resolution means on the ground: the AGEB
#                         mesh of a metro area under the same colours, beside
#                         its population density. The hazard changes only at
#                         municipal borders; the density does not.
#
# Colour follows the data's job. The grade is an ordered magnitude, so it takes
# ONE hue light -> dark (blue, steps 250..700), never a rainbow. Density is a
# second sequential context on the same screen, so it takes the next hue
# (orange) as its own ramp. Both ramps were checked for monotonic OKLab
# lightness and >= 2:1 contrast of their lightest step against the surface.

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(tidyr); library(ggplot2); library(readr)
})
source("R/00_config.R"); source("R/01_utils.R")

# Figures live in maps/png/; the folder may not exist in a fresh clone.
DIR_MAPS <- file.path("maps", "png")
dir.create(DIR_MAPS, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
zoom_ent <- if (length(args) >= 1) args[[1]] else "14"
zoom_mun <- if (length(args) >= 2) args[-1] else
  c("039", "120", "098", "101", "097", "070")  # Zona Metropolitana de Guadalajara

SURFACE <- "#fcfcfb"
INK     <- "#0b0b0b"
INK_2   <- "#52514e"
INK_3   <- "#898781"
NO_DATA <- "#e1e0d9"

# Sequential blue, one hue light -> dark. More is worse.
GRADE_FILL <- c("Muy bajo" = "#86b6ef", "Bajo" = "#5598e7", "Medio" = "#2a78d6",
                "Alto" = "#184f95", "Muy alto" = "#0d366b")
# Second sequential context, orange ramp.
DENS_FILL <- c("#f29b6b", "#ea7538", "#d55a15", "#a94413", "#7a300d")

map_theme <- theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 15, colour = INK),
        plot.subtitle = element_text(size = 10, colour = INK_2, lineheight = 1.2),
        plot.caption = element_text(size = 8, colour = INK_3, hjust = 0,
                                    lineheight = 1.2),
        strip.text = element_text(face = "bold", size = 11, colour = INK,
                                  margin = margin(b = 4)),
        legend.position = "bottom",
        legend.key.height = unit(9, "pt"),
        legend.key.width = unit(34, "pt"),
        legend.text = element_text(size = 9, colour = INK_2),
        plot.background = element_rect(fill = SURFACE, colour = NA),
        plot.margin = margin(14, 14, 14, 14))

grade_scale <- function(name = NULL) {
  scale_fill_manual(values = GRADE_FILL, name = name, na.value = NO_DATA,
                    breaks = names(GRADE_FILL), limits = names(GRADE_FILL),
                    drop = FALSE, na.translate = FALSE,
                    guide = guide_legend(nrow = 1, label.position = "bottom",
                                         keyheight = unit(9, "pt")))
}

as_grade <- function(x) factor(x, levels = 1:5, labels = names(GRADE_FILL))

# ggplot2 draws a key for every level of the scale but paints only the levels
# the layer actually contains: on a zoom holding three grades, the other two
# came out as empty boxes the colour of the surface, under labels that were
# still there -- a legend that silently lies about its own scale. Five empty
# polygons carrying the five grades paint every key and draw nothing on the map.
# (limits/breaks alone fix the labels, not the key glyphs; override.aes does not
# reach keys the layer never generated.)
grade_key_layer <- function() {
  ghost <- st_sf(GRADO = factor(names(GRADE_FILL), levels = names(GRADE_FILL)),
                 geometry = st_sfc(rep(list(st_polygon()), length(GRADE_FILL)),
                                   crs = CRS_ANALYSIS))
  geom_sf(data = ghost, aes(fill = GRADO), colour = NA, show.legend = TRUE)
}

# --- figure 1: national, four climate hazards -----------------------------
log_step("national hazard map")

haz <- readRDS(file.path(DIR_INTERIM, "hazard_national.rds"))

# CONABIO's municipal layer is the one already downloaded for the CLUES
# geocoding check. It is a 2022 vintage: it carries six municipalities created
# after the 2020 marco, which CENAPRED has no row for and which therefore draw
# in the no-data grey.
mun <- st_read(find_file(file.path(DIR_RAW, "national", "municipios"), "[.]shp$"),
               quiet = TRUE) |>
  transmute(CVE_ENT, CVE_MUN_FULL = build_mun_id(CVE_ENT, CVE_MUN)) |>
  st_transform(CRS_ANALYSIS) |>
  st_make_valid()
# NOTE: do not st_simplify() this layer to speed up the render. At any tolerance
# that helps, the smallest municipalities -- hundreds of them in Oaxaca and
# Puebla -- collapse or pull apart, and the surface shows through as a white
# speckle that reads exactly like missing data. The full geometry draws in ~4 s.

sin_dato <- sum(!mun$CVE_MUN_FULL %in% haz$CVE_MUN_FULL)

PANELS <- c(AMZ_INUND = "Inundación", AMZ_ONDA_CAL = "Ondas cálidas",
            AMZ_SEQUIA = "Sequía", AMZ_DESLIZ = "Deslizamientos")

nat <- mun |>
  left_join(haz |> select(CVE_MUN_FULL, all_of(names(PANELS))), by = "CVE_MUN_FULL") |>
  pivot_longer(all_of(names(PANELS)), names_to = "AMENAZA", values_to = "GRADO") |>
  mutate(AMENAZA = factor(unname(PANELS[AMENAZA]), levels = unname(PANELS)),
         GRADO = as_grade(GRADO))

estados <- mun |> group_by(CVE_ENT) |> summarise(.groups = "drop")

p_nat <- ggplot(nat) +
  geom_sf(aes(fill = GRADO), colour = NA) +
  grade_key_layer() +
  geom_sf(data = estados, fill = NA, colour = SURFACE, linewidth = 0.18) +
  facet_wrap(~ AMENAZA, ncol = 2) +
  grade_scale() +
  labs(
    title = "Grado municipal de peligro, CENAPRED 2023",
    subtitle = paste(
      "2,469 municipios. Cada panel es una clasificación relativa de su propio fenómeno:",
      "un «Muy alto» de sequía\nno equivale a un «Muy alto» de inundación, y los colores",
      "no son comparables entre paneles."),
    caption = paste0(
      "Fuente: Sistema de Indicadores Municipales del Atlas Nacional de Riesgos (CENAPRED), publicado por SEDATU. Geometría municipal: CONABIO 2022.\n",
      "Las clases son ordinales, no magnitudes físicas: no hay lámina de agua ni periodo de retorno detrás de ellas. ",
      if (sin_dato > 0) sprintf("En gris, %d municipios creados después del marco 2020, sin fila en CENAPRED.", sin_dato) else "")) +
  map_theme

out_nat <- file.path(DIR_MAPS, "amenaza_nacional.png")
ggsave(out_nat, p_nat, width = 10, height = 8.4, dpi = 200, bg = SURFACE)
log_msg("  wrote ", out_nat)

# --- figure 2: what municipal resolution looks like from the ground -------
log_step("metro zoom ", zoom_ent, " ", paste(zoom_mun, collapse = " "))

tab <- read_csv(file.path(DIR_PROCESSED, sprintf("ageb_indicadores_%s.csv", zoom_ent)),
                show_col_types = FALSE,
                col_types = cols(ID_AGEB = "c", CVE_ENT = "c", CVE_MUN = "c",
                                 CVE_LOC = "c", CVE_AGEB = "c")) |>
  filter(CVE_MUN %in% zoom_mun)

sel <- st_read(file.path(DIR_PROCESSED, sprintf("ageb_geom_%s.gpkg", zoom_ent)),
               quiet = TRUE) |>
  select(ID_AGEB) |>
  inner_join(tab, by = "ID_AGEB") |>
  st_transform(CRS_ANALYSIS)

mun_zoom <- mun |> filter(CVE_MUN_FULL %in% build_mun_id(zoom_ent, zoom_mun))
# Wrapped: the six-municipality list overflows the figure on one line.
zona <- paste(strwrap(paste(sort(unique(sel$NOM_MUN)), collapse = ", "), width = 92),
              collapse = "\n")
pob  <- sum(sel$POB_TOTAL, na.rm = TRUE)

p_zoom <- ggplot(sel) +
  geom_sf(aes(fill = as_grade(AMZ_INUND)), colour = NA) +
  grade_key_layer() +
  geom_sf(data = mun_zoom, fill = NA, colour = SURFACE, linewidth = 0.7) +
  grade_scale() +
  labs(title = "Peligro por inundación sobre la malla de AGEB",
       subtitle = sprintf("%s AGEB · %s habitantes\n%s",
                          format(nrow(sel), big.mark = ","),
                          format(pob, big.mark = ","), zona),
       caption = paste(
         "El color cambia solo en los límites municipales (líneas blancas): el dato de CENAPRED es municipal y todas las AGEB de",
         "un municipio\ncomparten valor. La malla es mucho más fina que la amenaza que se le puede asignar.")) +
  map_theme

out_zoom <- file.path(DIR_MAPS, sprintf("amenaza_zoom_%s.png", zoom_ent))
ggsave(out_zoom, p_zoom, width = 8.6, height = 8.2, dpi = 200, bg = SURFACE)
log_msg("  wrote ", out_zoom)

# Density on the same mesh: the variation the hazard layer cannot see. Quintile
# breaks, because density is heavily skewed and equal intervals would leave
# every AGEB in the first class.
brk <- quantile(sel$DENS_POB_KM2[sel$POB_TOTAL > 0], probs = seq(0, 1, 0.2),
                na.rm = TRUE)
lab <- sprintf("%s–%s", format(round(head(brk, -1)), big.mark = ",", trim = TRUE),
               format(round(brk[-1]), big.mark = ",", trim = TRUE))

# An uninhabited rural AGEB has density 0 and falls outside the quintiles of the
# inhabited ones. It is named in the legend rather than left as a bare "NA":
# nothing is missing there, nobody lives there.
DESHAB <- "Deshabitada"

p_dens <- sel |>
  mutate(Q = cut(DENS_POB_KM2, breaks = unique(brk), labels = lab,
                 include.lowest = TRUE),
         Q = factor(ifelse(POB_TOTAL > 0 & !is.na(Q), as.character(Q), DESHAB),
                    levels = c(lab, DESHAB))) |>
  ggplot() +
  geom_sf(aes(fill = Q), colour = NA) +
  geom_sf(data = mun_zoom, fill = NA, colour = SURFACE, linewidth = 0.7) +
  scale_fill_manual(values = setNames(c(DENS_FILL, NO_DATA), c(lab, DESHAB)),
                    name = NULL, na.value = NO_DATA, drop = FALSE,
                    guide = guide_legend(nrow = 1, label.position = "bottom")) +
  labs(title = "Densidad de población en la misma malla",
       subtitle = "Habitantes por km², en quintiles de las AGEB habitadas",
       caption = paste(
         "Censo 2020 (INEGI). Esta es la variación que el grado municipal de peligro no puede ver: quién está expuesto se resuelve",
         "por AGEB,\na qué está expuesto, por municipio.")) +
  map_theme

out_dens <- file.path(DIR_MAPS, sprintf("amenaza_zoom_%s_densidad.png", zoom_ent))
ggsave(out_dens, p_dens, width = 8.6, height = 8.2, dpi = 200, bg = SURFACE)
log_msg("  wrote ", out_dens)
