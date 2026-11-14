library(warbleR)

est <- readRDS(
  "~/Dropbox/Projects/bellbird_mimicry/data/processed/extended_selection_table_sympatric_and_allopatric_species.RDS"
)


# table(est$Model.species)
# table(est$source)
#
# est_mimetic <- sig2noise(
#   est[est$source == "mimic_bellbird", ],
#   mar = 0.05,
#   before = TRUE
# )
#
#
# table(est_mimetic$SNR > 10)
#
# est_mimetic_hsnr <- est_mimetic[est_mimetic$SNR > 10, ]
#
# spectrograms(X = est_mimetic_hsnr, dest.path = "./data/processed/example_spectrogram_annotations/single_spectros_mimetic", ovlp = 70, collevels = seq(-120, 0, 5))

selected <- list.files(
  "/home/marce/Dropbox/Projects/bellbird_mimicry/presentation/images/spectros_mimetic/"
)

selected <- gsub("-1.jpeg", "", selected)

sub_est <- est[est$sound.files %in% selected, ]


cols <- viridis::mako(10, direction = 1)

# spectro_pal <- function(n) viridis::mako(n, direction = 1)
spectro_pal <- colorRampPalette(colors = cols[c(rep(1, 10), 1:10)])


catalog(
  sub_est,
  wl = 512,
  ncol = 5,
  nrow = 5,
  flim = c(1, 9),
  ovlp = 90,
  box = FALSE,
  spec.mar = 0,
  path = "./presentation/images/",
  pal = spectro_pal,
  width = 8.5,
  height = 8.5,
  lab.mar = 0.01,
  rm.axes = TRUE,
  collevels = seq(-130, 0, 1)
)
