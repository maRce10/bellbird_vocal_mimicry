# One short example sound per species (and for the other bellbirds) for the
# "Especies y datos de entrenamiento" slide: the reference clip with the highest
# signal-to-noise ratio, in a 0.8 s window centred on the vocalization. Saved as
# images/ejemplo_*.wav; presentation.qmd draws their spectrograms.
# Run from presentation/ (needs the local data/ folder):  Rscript example_spectrograms.R

suppressMessages({library(tuneR); library(seewave)})

clips_dir <- "../data/processed/birdnet_data"
species <- c("Ramphastos sulfuratus", "Ramphastos brevis", "Pteroglossus torquatus",
             "Pteroglossus erythropygius", "Psarocolius montezuma", "Psarocolius guatimozinus",
             "Procnias tricarunculatus")
win <- 0.8   # seconds shown

# SNR of a clip (0.1-2 s long): brightest 1 % of spectrogram cells against the median cell, 0.5-10 kHz
clip_snr <- function(f) {
  w <- readWave(f)
  if (w@stereo) w <- mono(w, "left")
  dur <- length(w@left) / w@samp.rate
  if (dur < 0.1 || dur > 2 || max(abs(w@left)) == 0) return(NA_real_)
  s <- spectro(w, wl = 1024, ovlp = 75, plot = FALSE, dB = NULL, norm = FALSE)
  a <- s$amp[s$freq >= 0.5 & s$freq <= 10, , drop = FALSE]
  as.numeric(20 * log10(quantile(a, 0.99) / median(a)))
}

best <- do.call(rbind, lapply(species, function(sp) {
  f <- unlist(lapply(c("train_data", "test_data"), function(split)
    list.files(file.path(clips_dir, split, sp), pattern = "\\.wav$", full.names = TRUE)))
  snr <- vapply(f, clip_snr, numeric(1))
  data.frame(species = sp, file = f[which.max(snr)], snr = round(max(snr, na.rm = TRUE), 1))
}))
write.csv(best, "data/espectrogramas_ejemplo.csv", row.names = FALSE)

# 0.8 s window centred on the clip (padded with silence when the clip is shorter)
centre <- function(w, win) {
  n <- round(win * w@samp.rate)
  x <- w@left
  if (length(x) >= n) {
    s <- floor((length(x) - n) / 2)
    x <- x[(s + 1):(s + n)]
  } else {
    a <- floor((n - length(x)) / 2)
    x <- c(rep(0, a), x, rep(0, n - length(x) - a))
  }
  Wave(left = x, samp.rate = w@samp.rate, bit = w@bit)
}

# the 0.8 s windows are saved as small audio files; the deck draws their spectrograms at
# render time, with the theme set at its start (spectro_theme in presentation.qmd)
for (i in seq_len(nrow(best))) {
  w <- readWave(best$file[i])
  if (w@stereo) w <- mono(w, "left")
  out <- file.path("images", paste0("ejemplo_", gsub(" ", "_", tolower(best$species[i])), ".wav"))
  writeWave(centre(w, win), out)
}
print(best)
