library(dynaSpec)

bellbird <- dynaspec("./images/adulto_monteverde.mp4", flim = c(0.7, 8.4)) +
  ds_spectrogram(wl = 1024, collevels = seq(-30, 0, 1), ovlp = 99) +
  ds_scrolling(t.display = 2, still.ends = FALSE) +
  ds_theme_dark(
    pal = function(n) viridis::mako(n, direction = 1),
    xlab = "Tiempo (s)",
    ylab = "Frec (kHz)",
    col.line = adjustcolor("orange", 0.7),
    lty.line = 1,
    cex.lab = 1.5,
    colbg = viridis::mako(10, direction = 1)[1],
    box = FALSE
  ) +
  ds_video(position = "above", height = 2.5) +
  ds_filter(bp = c(1, Inf))


bellbird


save_dynaspec(bellbird, "./images/adult_bellbird_spectrogram_short_black.mp4")


focal <- dynaspec("./images/mimic_aracari_toucan.mp4", flim = c(0.7, 9)) +
  ds_spectrogram(wl = 512, collevels = seq(-60, 0, 1), ovlp = 99) +
  ds_scrolling(t.display = 2, still.ends = FALSE) +
  ds_theme_dark(
    pal = function(n) viridis::mako(n, direction = 1),
    xlab = "Tiempo (s)",
    ylab = "Frec (kHz)",
    col.line = adjustcolor("orange", 0.7),
    lty.line = 1,
    cex.lab = 1.5,
    colbg = viridis::mako(10, direction = 1)[1], 
    box = FALSE
  ) +
  ds_video(position = "above", height = 2.5) +
  ds_filter(bp = c(1.2, Inf))


focal


save_dynaspec(focal, "./images/focal_spectrogram_black.mp4")
