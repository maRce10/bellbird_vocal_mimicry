library(warbleR)

est <- extended_selection_table_sympatric_and_allopatric_species


table(est$Model.species)
table(est$source)

est_mimetic <- sig2noise(
  est[est$source == "mimic_bellbird", ],
  mar = 0.05,
  before = TRUE
)


table(est_mimetic$SNR > 10)

est_mimetic_hsnr <- est_mimetic[est_mimetic$SNR > 10, ]


set.seed(1234)

sub_est <- est_mimetic_hsnr[sample(1:nrow(est_mimetic_hsnr), 36), ]

pal <- colorRampPalette(colors = viridis::mako(n = 2, direction = -1))

catalog(
  sub_est,
  wl = 400,
  ncol = 6,
  nrow = 6,
  flim = c(1, 9),
  ovlp = 90,
  box = FALSE,
  spec.mar = 0,
  path = "./data/processed",
  pal = pal,
  width = 8.5,
  height = 8.5,
  lab.mar = 0.01,
  collevels = seq(-35, 0, 5)
)
