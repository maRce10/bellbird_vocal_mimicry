# Distribution of the bellbird and of the model (sympatric) and related (allopatric) species
# used in the classifier, from the BirdLife International and Handbook of the Birds of the
# World range maps (BOTW 2025). Run from presentation/:  Rscript distribution_maps.R
#
# The BirdLife data are licensed and must not be redistributed, so they stay in maps/, which
# git ignores. maps/rangos_especies.gpkg holds the 7 species, extracted from BOTW_2025.gpkg
# (inside maps/birdlife_maps.zip) with:
#   sf::st_read("BOTW_2025.gpkg", query = "SELECT * FROM all_species WHERE sci_name IN (...)")

library(ggplot2)
library(sf)
sf_use_s2(FALSE)

ranges <- st_read("maps/rangos_especies.gpkg", quiet = TRUE)

# native ranges where the species is extant or possibly extant, all seasons merged
ranges <- ranges[ranges$presence %in% c(1, 2, 3) & ranges$origin %in% c(1, 2), ]
ranges <- aggregate(ranges["sci_name"], by = list(species = ranges$sci_name), FUN = function(x) x[1])
ranges <- st_make_valid(ranges)

groups <- data.frame(
  species = c("Ramphastos sulfuratus", "Ramphastos brevis",
              "Pteroglossus torquatus", "Pteroglossus erythropygius",
              "Psarocolius montezuma", "Psarocolius guatimozinus"),
  group = factor(rep(c("Tucanes", "Aracaris", "Oropéndolas"), each = 2),
                 levels = c("Tucanes", "Aracaris", "Oropéndolas")),
  type = rep(c("Modelo simpátrico", "Pariente alopátrico"), 3)
)
sp_ranges <- merge(ranges, groups, by = "species")

# bellbird range repeated in every panel
bell <- ranges[ranges$species == "Procnias tricarunculatus", ]
# its seasonal polygons do not share edges exactly: a small buffer merges them into one outline
st_geometry(bell) <- st_buffer(st_union(st_buffer(st_geometry(bell), 0.02)), -0.02)
bell <- do.call(rbind, lapply(levels(groups$group), function(g) {
  b <- bell
  b$group <- factor(g, levels = levels(groups$group))
  b
}))

land <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")
xlim <- c(-101, -66)
ylim <- c(-5, 24)
font <- "Source Sans Pro"
# colour key: type_cols from presentation.qmd when run from the deck, otherwise these defaults
if (!exists("type_cols")) type_cols <- c("Alopátrica" = "#3a7ca5", "Simpátrica" = "#d1603d")
cols <- c("Modelo simpátrico" = type_cols[["Simpátrica"]], "Pariente alopátrico" = type_cols[["Alopátrica"]])

g <- ggplot() +
  geom_sf(data = land, fill = "#f2f0ea", colour = "#b9b6ad", linewidth = 0.2) +
  geom_sf(data = sp_ranges, aes(fill = type), colour = NA, alpha = 0.6) +
  geom_sf(data = bell, fill = NA, colour = "#111111", linewidth = 0.7) +
  facet_wrap(~ group) +
  scale_fill_manual(values = cols, name = NULL) +
  coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
  labs(caption = "Contorno negro: pájaro campana. Mapas: BirdLife International y Handbook of the Birds of the World (2025)") +
  theme_minimal(base_size = 16, base_family = font) +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank(),
        panel.background = element_rect(fill = "#dfe9ef", colour = NA),
        strip.text = element_text(size = 18), legend.position = "top",
        legend.text = element_text(size = 15),
        plot.caption = element_text(size = 11, colour = "#555555"))

ggsave("images/mapas_distribucion.png", g, width = 12, height = 5.6, dpi = 300, bg = "white")

# one small map per species for the table on the "¿Mimetismo o azar?" slide: its range, the
# bellbird outline and its drawing over the Pacific (transparent copies of images/dibujo_*.png)
bell1 <- bell[1, ]
for (i in seq_len(nrow(groups))) {
  s <- groups$species[i]
  snake <- gsub(" ", "_", tolower(s))
  img <- png::readPNG(file.path("images", paste0("icono_", snake, ".png")))
  asp <- dim(img)[1] / dim(img)[2]
  h <- 11 * 1.3                            # drawing height, in degrees of latitude
  w <- min(h / asp, 13 * 1.3)
  h <- w * asp
  m <- ggplot() +
    geom_sf(data = land, fill = "#f2f0ea", colour = "#b9b6ad", linewidth = 0.15) +
    geom_sf(data = sp_ranges[sp_ranges$species == s, ], fill = cols[[groups$type[i]]],
            colour = NA, alpha = 0.75) +
    geom_sf(data = bell1, fill = NA, colour = "#111111", linewidth = 0.45) +
    annotation_custom(grid::rasterGrob(img, interpolate = TRUE),
                      xmin = xlim[1] + 1, xmax = xlim[1] + 1 + w,
                      ymin = ylim[1] + 1, ymax = ylim[1] + 1 + h) +
    coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
    theme_void() +
    theme(panel.background = element_rect(fill = "#dfe9ef", colour = NA),
          plot.margin = margin(0, 0, 0, 0))
  ggsave(file.path("images", paste0("mapa_", snake, ".png")), m, width = 3.6, height = 3.0,
         dpi = 200, bg = "#dfe9ef")
}
