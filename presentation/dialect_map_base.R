# Base map for the bellbird dialect map (slide with the phylogeny close-up): Costa Rica and its
# neighbours in the style of the species distribution maps (distribution_maps.R: flat land, grey
# borders, light blue sea), with a north arrow and an inset showing where it lies in the Americas.
# Saved as images/mapa_dialectos_base.png. The deck draws the dialect points and the spectrograms
# on top of it (in the same coordinates, map_ext below).
# Downloads GADM outlines (geodata package) to maps/geodata/ the first time (not in git).
# Run from presentation/ or from the project root:  Rscript presentation/dialect_map_base.R

if (!file.exists("dialect_map_base.R") && file.exists("presentation/dialect_map_base.R"))
  setwd("presentation")

suppressMessages({library(geodata); library(sf); library(ggplot2)})
sf_use_s2(FALSE)

# map extent (degrees); must be the same as in the deck's dialect map chunk
map_ext <- c(xmin = -86.25, xmax = -82.45, ymin = 7.95, ymax = 11.75)

# colours of the species distribution maps
sea <- "#dfe9ef"
land_col <- "#f2f0ea"
border <- "#b9b6ad"
frame_col <- "#d23c3c"      # box of the map area in the inset

dir.create("maps/geodata", recursive = TRUE, showWarnings = FALSE)
countries <- do.call(rbind, lapply(c("CRI", "NIC", "PAN", "COL"), function(cc)
  st_as_sf(gadm(cc, level = 0, path = "maps/geodata", resolution = 1))))
countries <- st_crop(st_make_valid(countries), st_bbox(map_ext + c(-1, 1, -1, 1), crs = st_crs(4326)))

# inset: the Americas with a box around the area of the map
americas <- rnaturalearth::ne_countries(scale = "medium", continent = c("North America", "South America"),
                                        returnclass = "sf")
inset <- ggplot() +
  geom_sf(data = americas, fill = land_col, colour = border, linewidth = 0.1) +
  annotate("rect", xmin = map_ext[["xmin"]], xmax = map_ext[["xmax"]], ymin = map_ext[["ymin"]],
           ymax = map_ext[["ymax"]], fill = NA, colour = frame_col, linewidth = 0.6) +
  coord_sf(xlim = c(-125, -30), ylim = c(-56, 50), expand = FALSE) +
  theme_void() +
  theme(panel.background = element_rect(fill = sea, colour = "#888888", linewidth = 0.8),
        plot.margin = margin(0, 0, 0, 0))
inset_file <- tempfile(fileext = ".png")
ggsave(inset_file, inset, width = 2, height = 2 * 106 / 95, dpi = 300)
inset_img <- png::readPNG(inset_file)
in_w <- 0.95; in_h <- in_w * 106 / 95           # inset size and position (degrees), bottom left
in_x <- map_ext[["xmin"]] + 0.06; in_y <- map_ext[["ymin"]] + 0.06

# north arrow, top right
na_x <- map_ext[["xmax"]] - 0.25; na_y <- map_ext[["ymax"]] - 0.62

base <- ggplot() +
  geom_sf(data = countries, fill = land_col, colour = border, linewidth = 0.4) +
  annotation_raster(inset_img, xmin = in_x, xmax = in_x + in_w, ymin = in_y, ymax = in_y + in_h,
                    interpolate = TRUE) +
  annotate("segment", x = na_x, xend = na_x, y = na_y, yend = na_y + 0.32, colour = "#333333",
           linewidth = 0.9, arrow = grid::arrow(length = grid::unit(0.18, "cm"), type = "closed")) +
  annotate("text", x = na_x, y = na_y + 0.42, label = "N", fontface = "bold", size = 5,
           colour = "#333333") +
  coord_sf(xlim = map_ext[c("xmin", "xmax")], ylim = map_ext[c("ymin", "ymax")], expand = FALSE) +
  theme_void() +
  theme(panel.background = element_rect(fill = sea, colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# square-ish image with the panel filling it exactly
asp <- diff(map_ext[c("ymin", "ymax")]) / (diff(map_ext[c("xmin", "xmax")]) * cos(mean(map_ext[c("ymin", "ymax")]) * pi / 180))
ggsave("images/mapa_dialectos_base.png", base, width = 6, height = 6 * asp, dpi = 300)
