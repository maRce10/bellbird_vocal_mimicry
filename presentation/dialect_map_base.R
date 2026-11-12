# Base map for the bellbird dialect map (slide with the phylogeny close-up): Costa Rica with
# shaded relief and its neighbours, saved as images/mapa_dialectos_base.png. The deck draws the
# dialect points and the spectrograms on top of it (in the same coordinates, map_ext below).
# Downloads GADM outlines and SRTM-based elevation (geodata package) to maps/geodata/ the
# first time (that folder is not in git).
# Run from presentation/ or from the project root:  Rscript presentation/dialect_map_base.R

if (!file.exists("dialect_map_base.R") && file.exists("presentation/dialect_map_base.R"))
  setwd("presentation")

suppressMessages({library(geodata); library(terra); library(sf); library(ggplot2)})

# map extent (degrees); must be the same as in the deck's dialect map chunk
map_ext <- c(xmin = -86.25, xmax = -82.45, ymin = 7.95, ymax = 11.75)

dir.create("maps/geodata", recursive = TRUE, showWarnings = FALSE)
countries <- do.call(rbind, lapply(c("CRI", "NIC", "PAN", "COL"), function(cc)
  st_as_sf(gadm(cc, level = 0, path = "maps/geodata", resolution = 1))))
countries <- st_crop(st_make_valid(countries), st_bbox(map_ext + c(-1, 1, -1, 1), crs = st_crs(4326)))
cr <- countries[countries$GID_0 == "CRI", ]
provinces <- st_as_sf(gadm("CRI", level = 1, path = "maps/geodata", resolution = 1))

# elevation and hillshade of Costa Rica
elev <- elevation_30s("CRI", path = "maps/geodata")
elev <- mask(elev, vect(cr))
slope <- terrain(elev, "slope", unit = "radians")
aspect <- terrain(elev, "aspect", unit = "radians")
hill <- shade(slope, aspect, angle = 40, direction = 315)
d_hill <- as.data.frame(hill, xy = TRUE, na.rm = TRUE); names(d_hill)[3] <- "hill"
d_elev <- as.data.frame(elev, xy = TRUE, na.rm = TRUE); names(d_elev)[3] <- "elev"

# colours
sea <- "#dfeaf1"
land_other <- "#efede6"
border <- "#9a9a9a"
elev_cols <- c("#e6eed9", "#cfe0b8", "#b9cf9b", "#d8c99a", "#c4a982", "#a88f74", "#f3f0ea")

base <- ggplot() +
  geom_sf(data = countries[countries$GID_0 != "CRI", ], fill = land_other, colour = border,
          linewidth = 0.35) +
  geom_raster(data = d_elev, aes(x, y, fill = elev)) +
  scale_fill_gradientn(colours = elev_cols, values = scales::rescale(c(0, 300, 800, 1500, 2200, 3000, 3800)),
                       limits = c(0, 3800), guide = "none") +
  # relief: hillshade as a semi-transparent grey layer
  geom_raster(data = d_hill, aes(x, y, alpha = 1 - hill), fill = "grey15") +
  scale_alpha_continuous(range = c(0, 0.45), guide = "none") +
  geom_sf(data = provinces, fill = NA, colour = "white", linewidth = 0.25, alpha = 0.7) +
  geom_sf(data = cr, fill = NA, colour = "grey35", linewidth = 0.5) +
  coord_sf(xlim = map_ext[c("xmin", "xmax")], ylim = map_ext[c("ymin", "ymax")], expand = FALSE) +
  theme_void() +
  theme(panel.background = element_rect(fill = sea, colour = NA),
        plot.margin = margin(0, 0, 0, 0))

# square-ish image with the panel filling it exactly
asp <- diff(map_ext[c("ymin", "ymax")]) / (diff(map_ext[c("xmin", "xmax")]) * cos(mean(map_ext[c("ymin", "ymax")]) * pi / 180))
ggsave("images/mapa_dialectos_base.png", base, width = 6, height = 6 * asp, dpi = 300)
