# Figure 8 of the manuscript: dialects of the focal bellbird's own-species vocalizations.
# Uses data/processed/focal_dialects.csv and the brms fits written by
# scripts/statistical_analysis_cv.qmd. Run from the project root:
#   Rscript presentation/paper_figure_dialects.R

library(ggplot2)
library(brms)

font_family <- "Source Sans Pro"
theme_set(theme_classic(base_size = 15, base_family = font_family))
cols <- c(Nicaragua = "#3B5A8C", Talamanca = "#3FA28A", `Other dialect` = "#D9B44A", Unassigned = "grey80")

fd <- read.csv("data/processed/focal_dialects.csv")
fd$date <- as.Date(fd$date)
fd$group <- ifelse(fd$dialect %in% c("Monteverde", "Panama"), "Other dialect", fd$dialect)
fd$group <- factor(fd$group, levels = names(cols))
days <- seq(min(fd$date), max(fd$date), length.out = 80)
jd <- as.numeric(format(days, "%j"))
months <- as.Date(sprintf("2020-%02d-01", c(4, 6, 8, 10)))
x_scale <- scale_x_date(breaks = months, labels = month.abb[c(4, 6, 8, 10)], limits = as.Date(c("2020-04-01", "2020-11-12")))

# A: composition of each recording day
comp <- as.data.frame(table(date = fd$date, group = fd$group))
comp$date <- as.Date(as.character(comp$date))
comp$prop <- comp$Freq / ave(comp$Freq, comp$date, FUN = sum)
pa <- ggplot(comp[comp$Freq > 0, ], aes(date, prop, fill = group)) +
    geom_col(width = 1.7) +
    scale_fill_manual(values = cols, name = NULL, guide = guide_legend(nrow = 2)) +
    scale_y_continuous(labels = scales::percent) +
    x_scale +
    labs(x = NULL, y = "Own-species vocalizations") +
    theme(legend.position = "top", legend.text = element_text(size = 12))

# B: proportion of Talamanca rather than Nicaragua vocalizations (Bernoulli model)
m10 <- readRDS("data/processed/cv_fits/focal_dialect_through_time.rds")
nt <- fd[fd$dialect %in% c("Nicaragua", "Talamanca"), ]
pts <- aggregate(cbind(tal = dialect == "Talamanca") ~ date, nt, function(x) c(p = mean(x), n = length(x)))
pts <- data.frame(date = pts$date, p = pts$tal[, "p"], n = pts$tal[, "n"])
ep <- posterior_epred(m10, newdata = data.frame(julian_day = jd), re_formula = NA)
fb <- data.frame(date = days, value = colMeans(ep), low = apply(ep, 2, quantile, 0.025), high = apply(ep, 2, quantile, 0.975))
pb <- ggplot(pts, aes(date, p)) +
    geom_ribbon(data = fb, aes(y = value, ymin = low, ymax = high), fill = cols[["Talamanca"]], alpha = 0.25) +
    geom_line(data = fb, aes(y = value), colour = cols[["Talamanca"]], linewidth = 1.4) +
    geom_point(aes(size = n), shape = 21, fill = cols[["Talamanca"]], alpha = 0.7) +
    scale_size_area(max_size = 7, name = "Vocalizations") +
    scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
    x_scale +
    labs(x = NULL, y = "Talamanca rather than\nNicaragua") +
    theme(legend.position = "top", legend.text = element_text(size = 12))

# C: neighbour similarity to the reference vocalizations of the assigned dialect, at average long-window SNR, averaged over equipment
m11 <- readRDS("data/processed/cv_fits/own_song_similarity_within_dialect_snrlong_equipment_through_time.rds")
d11 <- m11$data
grid <- expand.grid(julian_day = jd, dialect = c("Nicaragua", "Talamanca"), equipment = sort(unique(d11$equipment)),
                    stringsAsFactors = FALSE)
grid$snr_long <- mean(d11$snr_long)
w <- as.numeric(table(d11$equipment)[grid$equipment]) / nrow(d11)
ep <- posterior_epred(m11, newdata = grid, re_formula = NA) * sd(d11$knn_d) + mean(d11$knn_d)
key <- paste(grid$julian_day, grid$dialect)
ep <- t(rowsum(t(ep) * w, key, reorder = FALSE))
grid <- grid[!duplicated(key), ]
fc <- data.frame(date = rep(days, 2), dialect = grid$dialect, value = colMeans(ep),
                 low = apply(ep, 2, quantile, 0.025), high = apply(ep, 2, quantile, 0.975))
d11$date <- as.Date(d11$julian_day - 1, origin = "2020-01-01")
pc <- ggplot(d11, aes(date, knn_d, colour = dialect, fill = dialect)) +
    geom_jitter(width = 1.5, height = 0, alpha = 0.3, size = 1.2) +
    geom_ribbon(data = fc, aes(y = value, ymin = low, ymax = high), alpha = 0.25, colour = NA) +
    geom_line(data = fc, aes(y = value), linewidth = 1.4) +
    scale_colour_manual(values = cols, name = NULL) +
    scale_fill_manual(values = cols, name = NULL) +
    x_scale +
    labs(x = NULL, y = "Similarity to\nthe dialect") +
    theme(legend.position = "top", legend.text = element_text(size = 12))

p <- cowplot::plot_grid(pa, pb, pc, nrow = 1, labels = c("A", "B", "C"), label_fontfamily = font_family,
                        align = "h", axis = "b", rel_widths = c(1.15, 1, 1))
dir.create("output/manuscript", showWarnings = FALSE)
ragg::agg_png("output/manuscript/figure_8.png", width = 15, height = 5, units = "in", res = 300)
print(p)
invisible(dev.off())
cat("output/manuscript/figure_8.png\n")
