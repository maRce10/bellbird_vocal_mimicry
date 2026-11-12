# Circular cladogram of the 45 bird orders (Clements/eBird taxonomy 2025) for the slides,
# without labels, with songbirds (Passeri), parrots (Psittaciformes) and hummingbirds
# (Trochilidae) highlighted and illustrated. Passeriformes is split into its three suborders and Apodiformes into
# swifts and hummingbirds, so that only the vocal learners are highlighted (bellbirds
# are Tyranni).
#
# Topology: Open Tree of Life synthetic avian tree v1.7 (McTavish et al. 2025), via the
# clootl package; all orders and subgroups are monophyletic in it, so one tip each is kept.
# Run from presentation/:  Rscript bird_orders_phylogeny.R

# paths are relative to presentation/: move there when run from the project root (e.g. RStudio)
if (
  !file.exists("bird_orders_phylogeny.R") &&
    file.exists("presentation/bird_orders_phylogeny.R")
) {
  setwd("presentation")
}

library(ape)
library(ggplot2)

tree_file <- "data/bird_orders.tre"

# build the tree once (needs clootl, phangorn and an internet connection)
if (!file.exists(tree_file)) {
  library(clootl)
  tax <- taxonomyGet(taxonomy_year = 2025)
  tax <- tax[tax$CATEGORY == "species", ]
  full <- extractTree(
    species = "all_species",
    label_type = "scientific",
    taxonomy_year = 2025
  )
  i <- match(gsub("_", " ", full$tip.label), tax$SCI_NAME)
  ord <- tax$ORDER[i]
  fam <- sub(" \\(.*", "", tax$FAMILY[i])

  # groups: orders, except Passeriformes and Apodiformes, which are split
  first_of <- function(f) full$tip.label[which(fam == f)[1]]
  clade <- function(f1, f2) {
    n <- getMRCA(full, c(first_of(f1), first_of(f2)))
    full$tip.label[unlist(phangorn::Descendants(full, n, "tips"))]
  }
  groups <- split(full$tip.label, ord)
  pas <- groups$Passeriformes
  apo <- groups$Apodiformes
  groups$Passeriformes <- groups$Apodiformes <- NULL
  groups[["Passeri"]] <- clade("Menuridae", "Passeridae")
  groups[["Tyranni"]] <- clade("Cotingidae", "Pittidae")
  groups[["Acanthisitti"]] <- setdiff(pas, c(groups$Passeri, groups$Tyranni))
  groups[["Trochilidae"]] <- apo[
    fam[match(apo, full$tip.label)] == "Trochilidae"
  ]
  groups[["Apodi"]] <- setdiff(apo, groups$Trochilidae)
  stopifnot(
    all(sapply(groups, function(t) length(t) < 2 || is.monophyletic(full, t))),
    setequal(unlist(groups), full$tip.label)
  )

  rep_tip <- sapply(groups, `[`, 1)
  tr <- keep.tip(full, rep_tip)
  tr$tip.label <- names(groups)[match(tr$tip.label, rep_tip)]
  tr$node.label <- NULL
  write.tree(tr, tree_file)
}

tr <- read.tree(tree_file)
n_tip <- Ntip(tr)
root <- n_tip + 1
kids <- split(
  tr$edge[, 2],
  factor(tr$edge[, 1], levels = seq_len(n_tip + tr$Nnode))
)

highlight <- c("Passeri", "Psittaciformes", "Trochilidae")
highlight2 <- "Tyranni" # suboscines, where bellbirds belong: second version of the figure

# number of descendant tips and height (edges to the farthest tip) of every node
n_desc <- function(v) if (v <= n_tip) 1 else sum(sapply(kids[[v]], n_desc))
height <- function(v) if (v <= n_tip) 0 else 1 + max(sapply(kids[[v]], height))

# tip order around the circle: the larger clade first
tip_order <- c()
visit <- function(v) {
  if (v <= n_tip) {
    tip_order <<- c(tip_order, v)
    return(invisible())
  }
  ch <- kids[[v]]
  for (k in ch[order(-sapply(ch, n_desc))]) {
    visit(k)
  }
}
visit(root)

# x: radius (root at the centre, tips aligned on the outside); y: position around the circle
h_root <- height(root)
x <- y <- numeric(n_tip + tr$Nnode)
y[tip_order] <- seq_len(n_tip)
set_coords <- function(v) {
  x[v] <<- h_root - height(v)
  if (v > n_tip) {
    for (k in kids[[v]]) {
      set_coords(k)
    }
    y[v] <<- mean(range(y[kids[[v]]]))
  }
}
set_coords(root)

# style
line_col <- "gray"
hl_col <- "#40498E99"
hl2_col <- "#A0DFB999"
bg_col <- "#f7f5ee"
inner <- 2 # empty centre, so the deepest arcs are not squeezed
gap <- 2 # empty positions between the first and the last tip
mirror <- TRUE # TRUE: tree mirrored left-right (songbirds, parrots and bellbird on the right)
turn <- if (mirror) -1 else 1
# direction (degrees, 0 = right, 90 = top) where the songbird, parrot and bellbird tips are centred
learner_angle <- 0
# angle (radians) of a position around the circle, rotated so that those tips sit at learner_angle
angle0 <- function(pos) pi / 2 - turn * 2 * pi * (pos - 0.5) / (n_tip + gap)
learner_pos <- y[match(c("Passeri", "Psittaciformes", "Tyranni"), tr$tip.label)]
rot <- learner_angle *
  pi /
  180 -
  atan2(mean(sin(angle0(learner_pos))), mean(cos(angle0(learner_pos))))
angle <- function(pos) angle0(pos) + rot

# polar layout drawn in cartesian coordinates: radius from x, angle (clockwise from the top) from y
to_xy <- function(r, pos) {
  th <- angle(pos)
  data.frame(px = (r + inner) * cos(th), py = (r + inner) * sin(th))
}

# one path per branch: an arc along the circle from the parent, then a radial line to the child
branch_path <- function(p, ch, id) {
  arc <- seq(y[p], y[ch], length.out = max(2, ceiling(abs(y[ch] - y[p]) * 12)))
  pts <- rbind(to_xy(x[p], arc), to_xy(x[ch], y[ch]))
  pts$id <- id
  pts$hl <- ch <= n_tip && tr$tip.label[ch] %in% highlight
  pts$hl2 <- ch <= n_tip && tr$tip.label[ch] %in% highlight2
  pts
}
paths <- do.call(
  rbind,
  lapply(seq_len(nrow(tr$edge)), function(i) {
    branch_path(tr$edge[i, 1], tr$edge[i, 2], i)
  })
)

# illustrations of the vocal-learning groups, beyond their tips (transparent copies made from
# images/passeri.png, psitacidae.png and trochilidae.png)
icons <- c(
  Passeri = "images/icono_passeri.png",
  Psittaciformes = "images/icono_psitacidae.png",
  Trochilidae = "images/icono_trochilidae.png",
  Tyranni = "images/icono_procnias_tricarunculatus.png"
)
icon_size <- 5.5 # width or height of the largest side, in tree units
icon_gap <- 0.4 # distance between the tip and the illustration
# per-illustration shift around the circle (in tip positions) and outwards (tree units), so
# that the neighbouring songbird and bellbird illustrations do not overlap
icon_shift <- list(
  Passeri = c(-0.7, 0),
  Tyranni = c(0, 0.2),
  Psittaciformes = c(0.4, 0)
)
# size of each illustration relative to icon_size
icon_scale <- list(Trochilidae = 2 / 3, Tyranni = 5 / 4, Psittaciformes = 3 / 4)
# illustrations shown mirrored (facing the other way); with mirror = TRUE every one is flipped once more
icon_flip <- c("Passeri", "Psittaciformes", "Tyranni")
icon_boxes <- list() # extent of each illustration, for the close-up figure
# one illustration as a layer; gray = TRUE draws it in black and white, and alpha (0-1) is
# its opacity
icon_layer <- function(g, gray = FALSE, alpha = 1) {
    img <- png::readPNG(icons[[g]])
    if (dim(img)[3] == 4) img[,, 4] <- img[,, 4] * alpha
    if (gray) {
      lum <- 0.299 * img[,, 1] + 0.587 * img[,, 2] + 0.114 * img[,, 3]
      for (k in 1:3) img[,, k] <- lum
    }
    if (xor(g %in% icon_flip, mirror)) {
      img <- img[, rev(seq_len(dim(img)[2])), , drop = FALSE]
    }
    asp <- dim(img)[1] / dim(img)[2]
    size <- icon_size * (if (is.null(icon_scale[[g]])) 1 else icon_scale[[g]])
    w <- if (asp < 1) size else size / asp
    h <- w * asp
    tip <- which(tr$tip.label == g)
    shift <- if (is.null(icon_shift[[g]])) c(0, 0) else icon_shift[[g]]
    pos <- y[tip] + shift[1]
    # centre far enough out that the closest corner of the image clears the tip
    th <- angle(pos)
    half <- abs(cos(th)) * w / 2 + abs(sin(th)) * h / 2
    c0 <- to_xy(x[tip] + icon_gap + half + shift[2], pos)
    icon_boxes[[g]] <<- c(xmin = c0$px - w / 2, xmax = c0$px + w / 2,
                          ymin = c0$py - h / 2, ymax = c0$py + h / 2)
    annotation_raster(
      img,
      xmin = c0$px - w / 2,
      xmax = c0$px + w / 2,
      ymin = c0$py - h / 2,
      ymax = c0$py + h / 2,
      interpolate = TRUE
    )
}
icon_layers <- setNames(lapply(names(icons), icon_layer), names(icons))

# dot at the end of the vocal-learning tips
learner_tips <- do.call(
  rbind,
  lapply(highlight, function(g) {
    tip <- which(tr$tip.label == g)
    to_xy(x[tip], y[tip])
  })
)

tyranni_tip <- to_xy(
  x[which(tr$tip.label == highlight2)],
  y[which(tr$tip.label == highlight2)]
)

lim <- h_root + inner + icon_gap + icon_size * max(1, unlist(icon_scale)) + 0.3

# gray_icons: groups whose illustration is drawn in black and white, with opacity gray_alpha
gray_alpha <- 0.6 # opacity of the black-and-white illustrations (1 = opaque)

plot_tree <- function(show_icons = TRUE, show_tyranni = FALSE, gray_icons = character(),
                      gray_alpha = 1, lw_scale = 1) {
  # lw_scale multiplies line widths and dot sizes (for zoomed-in versions)
  plain <- !paths$hl & !(show_tyranni & paths$hl2)
  g <- ggplot() +
    geom_path(
      data = paths[plain, ],
      aes(px, py, group = id),
      colour = line_col,
      linewidth = 1.1 * lw_scale,
      lineend = "round",
      linejoin = "round"
    ) +
    geom_path(
      data = paths[paths$hl, ],
      aes(px, py, group = id),
      colour = hl_col,
      linewidth = 1.8 * lw_scale,
      lineend = "round",
      linejoin = "round"
    ) +
    geom_point(data = learner_tips, aes(px, py), colour = hl_col, size = 4.2 * lw_scale)
  if (show_tyranni) {
    g <- g +
      geom_path(
        data = paths[paths$hl2, ],
        aes(px, py, group = id),
        colour = hl2_col,
        linewidth = 1.8 * lw_scale,
        lineend = "round",
        linejoin = "round"
      ) +
      geom_point(data = tyranni_tip, aes(px, py), colour = hl2_col, size = 4.2 * lw_scale)
  }
  if (show_icons) {
    shown <- if (show_tyranni) names(icons) else highlight
    g <- g + lapply(shown, function(i) if (i %in% gray_icons) icon_layer(i, gray = TRUE, alpha = gray_alpha) else icon_layers[[i]])
  }
  g +
    coord_fixed(xlim = c(-lim, lim), ylim = c(-lim, lim), expand = FALSE) +
    theme_void() +
    theme(plot.background = element_rect(fill = bg_col, colour = NA))
}

ggsave(
  "images/filogenia_ordenes.png",
  plot_tree(TRUE),
  width = 8,
  height = 8,
  dpi = 300,
  bg = bg_col
)
ggsave(
  "images/filogenia_ordenes_sin_iconos.png",
  plot_tree(FALSE),
  width = 8,
  height = 8,
  dpi = 300,
  bg = bg_col
)
ggsave(
  "images/filogenia_ordenes.svg",
  plot_tree(TRUE),
  width = 8,
  height = 8,
  bg = bg_col
)

# versions for the slides: transparent background, both cropped to the same box (the one of the
# version with Tyranni) so that the second slide adds to the first without moving anything
slide_png <- c(
  aprendices = "images/filogenia_ordenes_diapositiva.png",
  tyranni = "images/filogenia_ordenes_tyranni_diapositiva.png"
)
for (v in names(slide_png)) {
  ggsave(
    slide_png[[v]],
    plot_tree(
      TRUE,
      show_tyranni = v == "tyranni",
      # in the Tyranni version every illustration but the bellbird is in black and white
      gray_icons = if (v == "tyranni") setdiff(names(icons), "Tyranni") else character(),
      gray_alpha = gray_alpha
    ) +
      theme(plot.background = element_rect(fill = NA, colour = NA)),
    width = 8,
    height = 8,
    dpi = 300,
    bg = "transparent"
  )
}
alpha <- png::readPNG(slide_png[["tyranni"]])[,, 4] > 0 |
  png::readPNG(slide_png[["aprendices"]])[,, 4] > 0
rows <- range(which(rowSums(alpha) > 0))
cols <- range(which(colSums(alpha) > 0))
box <- sprintf(
  "%dx%d+%d+%d",
  diff(cols) + 1,
  diff(rows) + 1,
  cols[1] - 1,
  rows[1] - 1
)
for (f in slide_png) {
  magick::image_write(magick::image_crop(magick::image_read(f), box), f)
}

# close-up for the slide after the phylogenies: the part of the tree (with Tyranni highlighted)
# around the songbird, parrot and bellbird tips and their illustrations. Made from the same
# plot_tree(), so it follows the colours and settings above.
# zoom_depth: how far into the tree the close-up reaches (tree units, from the tips inwards);
# zoom_margin: extra space above and below the illustrations (tree units)
zoom_depth <- 6
zoom_margin <- 1.5
zoom_groups <- c("Passeri", "Psittaciformes", "Tyranni")
zb <- do.call(rbind, icon_boxes[zoom_groups])
zoom_x <- c(min(h_root + inner - zoom_depth, min(zb[, "xmin"])), max(zb[, "xmax"]) + 0.3)
zoom_y <- c(min(zb[, "ymin"]) - zoom_margin, max(zb[, "ymax"]) + zoom_margin)
zoom_gray <- c("Passeri", "Psittaciformes") # illustrations in black and white in the close-up
zoom_gray_alpha <- gray_alpha # their opacity (same as in the Tyranni phylogeny)
zoom_h <- 8 # height of the image (inches); the width follows the shape of the close-up
ggsave(
  "images/filogenia_ordenes_detalle.png",
  plot_tree(TRUE, show_tyranni = TRUE, gray_icons = zoom_gray, gray_alpha = zoom_gray_alpha,
            # thicker lines in proportion to the zoom, so branches keep their look
            lw_scale = 2 * lim / diff(zoom_y)) +
    coord_fixed(xlim = zoom_x, ylim = zoom_y, expand = FALSE) +
    theme(plot.background = element_rect(fill = NA, colour = NA)),
  width = zoom_h * diff(zoom_x) / diff(zoom_y),
  height = zoom_h,
  dpi = 300,
  bg = "transparent"
)
