# Circular cladogram of the 45 bird orders (Clements/eBird taxonomy 2025) for the slides,
# without labels, with songbirds (Passeri), parrots (Psittaciformes) and hummingbirds
# (Trochilidae) highlighted and illustrated. Passeriformes is split into its three suborders and Apodiformes into
# swifts and hummingbirds, so that only the vocal learners are highlighted (bellbirds
# are Tyranni).
#
# Topology: Open Tree of Life synthetic avian tree v1.7 (McTavish et al. 2025), via the
# clootl package; all orders and subgroups are monophyletic in it, so one tip each is kept.
# Run from presentation/:  Rscript bird_orders_phylogeny.R

library(ape)
library(ggplot2)

tree_file <- "data/bird_orders.tre"

# build the tree once (needs clootl, phangorn and an internet connection)
if (!file.exists(tree_file)) {
  library(clootl)
  tax <- taxonomyGet(taxonomy_year = 2025)
  tax <- tax[tax$CATEGORY == "species", ]
  full <- extractTree(species = "all_species", label_type = "scientific", taxonomy_year = 2025)
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
  groups[["Trochilidae"]] <- apo[fam[match(apo, full$tip.label)] == "Trochilidae"]
  groups[["Apodi"]] <- setdiff(apo, groups$Trochilidae)
  stopifnot(all(sapply(groups, function(t) length(t) < 2 || is.monophyletic(full, t))),
            setequal(unlist(groups), full$tip.label))

  rep_tip <- sapply(groups, `[`, 1)
  tr <- keep.tip(full, rep_tip)
  tr$tip.label <- names(groups)[match(tr$tip.label, rep_tip)]
  tr$node.label <- NULL
  write.tree(tr, tree_file)
}

tr <- read.tree(tree_file)
n_tip <- Ntip(tr)
root <- n_tip + 1
kids <- split(tr$edge[, 2], factor(tr$edge[, 1], levels = seq_len(n_tip + tr$Nnode)))

highlight <- c("Passeri", "Psittaciformes", "Trochilidae")
highlight2 <- "Tyranni"   # suboscines, where bellbirds belong: second version of the figure

# number of descendant tips and height (edges to the farthest tip) of every node
n_desc <- function(v) if (v <= n_tip) 1 else sum(sapply(kids[[v]], n_desc))
height <- function(v) if (v <= n_tip) 0 else 1 + max(sapply(kids[[v]], height))

# tip order around the circle: the larger clade first
tip_order <- c()
visit <- function(v) {
  if (v <= n_tip) { tip_order <<- c(tip_order, v); return(invisible()) }
  ch <- kids[[v]]
  for (k in ch[order(-sapply(ch, n_desc))]) visit(k)
}
visit(root)

# x: radius (root at the centre, tips aligned on the outside); y: position around the circle
h_root <- height(root)
x <- y <- numeric(n_tip + tr$Nnode)
y[tip_order] <- seq_len(n_tip)
set_coords <- function(v) {
  x[v] <<- h_root - height(v)
  if (v > n_tip) {
    for (k in kids[[v]]) set_coords(k)
    y[v] <<- mean(range(y[kids[[v]]]))
  }
}
set_coords(root)

# style
line_col <- "#33475b"
hl_col <- "#d1603d"
hl2_col <- "#3a7ca5"
bg_col <- "#f7f5ee"
inner <- 2            # empty centre, so the deepest arcs are not squeezed
gap <- 2              # empty positions between the first and the last tip

# polar layout drawn in cartesian coordinates: radius from x, angle (clockwise from the top) from y
to_xy <- function(r, pos) {
  th <- pi / 2 - 2 * pi * (pos - 0.5) / (n_tip + gap)
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
paths <- do.call(rbind, lapply(seq_len(nrow(tr$edge)), function(i)
  branch_path(tr$edge[i, 1], tr$edge[i, 2], i)))

# illustrations of the vocal-learning groups, beyond their tips (transparent copies made from
# images/passeri.png, psitacidae.png and trochilidae.png)
icons <- c(Passeri = "images/icono_passeri.png", Psittaciformes = "images/icono_psitacidae.png",
           Trochilidae = "images/icono_trochilidae.png",
           Tyranni = "images/icono_procnias_tricarunculatus.png")
icon_size <- 5.5      # width or height of the largest side, in tree units
icon_gap <- 0.4       # distance between the tip and the illustration
# per-illustration shift around the circle (in tip positions) and outwards (tree units), so
# that the neighbouring songbird and bellbird illustrations do not overlap
icon_shift <- list(Passeri = c(-1.9, 0.6), Tyranni = c(0.2, 0.8), Psittaciformes = c(1.7, 0))
icon_layers <- setNames(lapply(names(icons), function(g) {
  img <- png::readPNG(icons[[g]])
  asp <- dim(img)[1] / dim(img)[2]
  w <- if (asp < 1) icon_size else icon_size / asp
  h <- w * asp
  tip <- which(tr$tip.label == g)
  shift <- if (is.null(icon_shift[[g]])) c(0, 0) else icon_shift[[g]]
  pos <- y[tip] + shift[1]
  # centre far enough out that the closest corner of the image clears the tip
  th <- pi / 2 - 2 * pi * (pos - 0.5) / (n_tip + gap)
  half <- abs(cos(th)) * w / 2 + abs(sin(th)) * h / 2
  c0 <- to_xy(x[tip] + icon_gap + half + shift[2], pos)
  annotation_raster(img, xmin = c0$px - w / 2, xmax = c0$px + w / 2,
                    ymin = c0$py - h / 2, ymax = c0$py + h / 2, interpolate = TRUE)
}), names(icons))

# dot at the end of the vocal-learning tips
learner_tips <- do.call(rbind, lapply(highlight, function(g) {
  tip <- which(tr$tip.label == g)
  to_xy(x[tip], y[tip])
}))

tyranni_tip <- to_xy(x[which(tr$tip.label == highlight2)], y[which(tr$tip.label == highlight2)])

lim <- h_root + inner + icon_gap + icon_size + 0.3

plot_tree <- function(show_icons = TRUE, show_tyranni = FALSE) {
  plain <- !paths$hl & !(show_tyranni & paths$hl2)
  g <- ggplot() +
    geom_path(data = paths[plain, ], aes(px, py, group = id), colour = line_col,
              linewidth = 1.1, lineend = "round", linejoin = "round") +
    geom_path(data = paths[paths$hl, ], aes(px, py, group = id), colour = hl_col,
              linewidth = 1.8, lineend = "round", linejoin = "round") +
    geom_point(data = learner_tips, aes(px, py), colour = hl_col, size = 4.2)
  if (show_tyranni) {
    g <- g +
      geom_path(data = paths[paths$hl2, ], aes(px, py, group = id), colour = hl2_col,
                linewidth = 1.8, lineend = "round", linejoin = "round") +
      geom_point(data = tyranni_tip, aes(px, py), colour = hl2_col, size = 4.2)
  }
  if (show_icons) g <- g + icon_layers[if (show_tyranni) names(icons) else highlight]
  g +
    coord_fixed(xlim = c(-lim, lim), ylim = c(-lim, lim), expand = FALSE) +
    theme_void() +
    theme(plot.background = element_rect(fill = bg_col, colour = NA))
}

ggsave("images/filogenia_ordenes.png", plot_tree(TRUE), width = 8, height = 8, dpi = 300, bg = bg_col)
ggsave("images/filogenia_ordenes_sin_iconos.png", plot_tree(FALSE), width = 8, height = 8, dpi = 300, bg = bg_col)
ggsave("images/filogenia_ordenes.svg", plot_tree(TRUE), width = 8, height = 8, bg = bg_col)

# versions for the slides: transparent background, both cropped to the same box (the one of the
# version with Tyranni) so that the second slide adds to the first without moving anything
slide_png <- c(aprendices = "images/filogenia_ordenes_diapositiva.png",
               tyranni = "images/filogenia_ordenes_tyranni_diapositiva.png")
for (v in names(slide_png)) {
  ggsave(slide_png[[v]], plot_tree(TRUE, show_tyranni = v == "tyranni") +
           theme(plot.background = element_rect(fill = NA, colour = NA)),
         width = 8, height = 8, dpi = 300, bg = "transparent")
}
alpha <- png::readPNG(slide_png[["tyranni"]])[, , 4] > 0 | png::readPNG(slide_png[["aprendices"]])[, , 4] > 0
rows <- range(which(rowSums(alpha) > 0))
cols <- range(which(colSums(alpha) > 0))
box <- sprintf("%dx%d+%d+%d", diff(cols) + 1, diff(rows) + 1, cols[1] - 1, rows[1] - 1)
for (f in slide_png) magick::image_write(magick::image_crop(magick::image_read(f), box), f)
