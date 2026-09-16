#!/usr/bin/env Rscript
# map_municipio.R -- visual check of the final AGEB mesh for one municipality.
#   Rscript maps/map_municipio.R 20 057
# Draws the AGEB tessellation over the municipal outline so gaps, if any, show
# as background bleeding through.

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(ggplot2); library(readr)
})
source("R/00_config.R"); source("R/01_utils.R"); source("R/03_boundaries.R")

args <- commandArgs(trailingOnly = TRUE)
ent <- if (length(args) >= 1) args[[1]] else "20"
mun <- if (length(args) >= 2) args[[2]] else "057"

geom <- st_read(file.path(DIR_PROCESSED, sprintf("ageb_geom_%s.gpkg", ent)), quiet = TRUE)
tab  <- read_csv(file.path(DIR_PROCESSED, sprintf("ageb_indicadores_%s.csv", ent)),
                 show_col_types = FALSE,
                 col_types = cols(ID_AGEB = "c", CVE_ENT = "c", CVE_MUN = "c",
                                  CVE_LOC = "c", CVE_AGEB = "c"))

sel <- geom |>
  select(ID_AGEB) |>
  inner_join(tab |> filter(CVE_MUN == mun), by = "ID_AGEB") |>
  st_transform(CRS_ANALYSIS)

# Municipal outline straight from the marco, i.e. the reference the coverage QC
# compares against -- not the dissolved AGEB, which would hide a gap by
# construction.
mun_poly <- read_mg_layer(ent, "mun") |>
  filter(CVE_MUN == mun) |>
  st_make_valid()

nom  <- sel$NOM_MUN[1]
pob  <- sum(sel$POB_TOTAL, na.rm = TRUE)
area <- sum(sel$AREA_KM2)
n_u  <- sum(sel$AMBITO == "Urbana"); n_r <- sum(sel$AMBITO == "Rural")

ageb_fill <- c(Urbana = "#C2410C", Rural = "#15803D")

base_theme <- theme_void(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(size = 10, colour = "grey30"),
        plot.caption = element_text(size = 8, colour = "grey45", hjust = 0),
        legend.position = "bottom",
        plot.background = element_rect(fill = "white", colour = NA),
        plot.margin = margin(12, 12, 12, 12))

# --- panel 1: the whole municipality -------------------------------------
p1 <- ggplot() +
  # Magenta underlay: any hole in the mesh shows through as a bright patch.
  geom_sf(data = mun_poly, fill = "#FF00FF", colour = NA) +
  geom_sf(data = sel, aes(fill = AMBITO), colour = "white", linewidth = 0.25) +
  geom_sf(data = mun_poly, fill = NA, colour = "black", linewidth = 0.8) +
  scale_fill_manual(values = ageb_fill, name = NULL) +
  labs(title = sprintf("%s, %s", nom, sel$NOM_ENT[1]),
       subtitle = sprintf("%d AGEB (%d urbanas, %d rurales) · %s km² · %s habitantes",
                          nrow(sel), n_u, n_r,
                          format(round(area, 1), big.mark = ","),
                          format(pob, big.mark = ",")),
       caption = paste("Marco Geoestadístico 2020 y Censo 2020 (INEGI).",
                       "El relleno magenta quedaría visible si la malla dejara",
                       "algún hueco dentro del municipio.")) +
  base_theme

ggsave(sprintf("maps/ageb_%s%s_ambito.png", ent, mun), p1,
       width = 8, height = 8.6, dpi = 200, bg = "white")

# --- panel 2: population density, main urban locality ---------------------
# Zooming to the bbox of ALL urban AGEB is wrong when a municipality has more
# than one town: the window then spans the whole territory and the map is
# mostly empty. The frame is set from the most populated urban LOCALITY.
main_loc <- sel |>
  st_drop_geometry() |>
  filter(AMBITO == "Urbana") |>
  group_by(CVE_LOC, NOM_LOC) |>
  summarise(POB = sum(POB_TOTAL, na.rm = TRUE), .groups = "drop") |>
  slice_max(POB, n = 1)

core <- sel |> filter(AMBITO == "Urbana", CVE_LOC == main_loc$CVE_LOC[1])
win  <- st_bbox(st_buffer(core, 900))

p2 <- ggplot() +
  geom_sf(data = sel, fill = "grey93", colour = "white", linewidth = 0.2) +
  geom_sf(data = mun_poly, fill = NA, colour = "black", linewidth = 0.7) +
  geom_sf(data = core, aes(fill = DENS_POB_KM2), colour = "white", linewidth = 0.3) +
  scale_fill_viridis_c(option = "magma", direction = -1,
                       name = "hab/km²", labels = scales::comma,
                       n.breaks = 4, na.value = "grey85") +
  coord_sf(xlim = win[c("xmin", "xmax")], ylim = win[c("ymin", "ymax")],
           expand = FALSE) +
  guides(fill = guide_colourbar(barwidth = 14, barheight = 0.6,
                                title.position = "top", title.hjust = 0.5)) +
  # Municipality and its seat usually share a name; do not print it twice.
  labs(title = if (identical(nom, main_loc$NOM_LOC[1])) nom else
                 sprintf("%s — %s", nom, main_loc$NOM_LOC[1]),
       subtitle = sprintf("Densidad en las %d AGEB urbanas de la localidad; en gris, AGEB rurales del entorno",
                          nrow(core)),
       caption = "Censo 2020 (INEGI) sobre geometría del Marco Geoestadístico 2020.") +
  base_theme +
  theme(plot.subtitle = element_text(size = 9.5))

ggsave(sprintf("maps/ageb_%s%s_densidad.png", ent, mun), p2,
       width = 8, height = 8.2, dpi = 200, bg = "white")

cat(sprintf("%s: %d AGEB (%d urb / %d rur), %.1f km2, %s hab\n",
            nom, nrow(sel), n_u, n_r, area, format(pob, big.mark = ",")))
cat(sprintf("AGEB area %.4f km2 vs municipal polygon %.4f km2 (diff %+.4f)\n",
            area, as.numeric(st_area(mun_poly)) / 1e6,
            area - as.numeric(st_area(mun_poly)) / 1e6))
